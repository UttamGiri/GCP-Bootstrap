locals {
  name_prefix = "vertex-psc-${var.name_suffix}"

  host_apis = concat(
    [
      "compute.googleapis.com",
      "dns.googleapis.com",
      "aiplatform.googleapis.com",
    ],
    # Token exchange + impersonation for Kong IRSA → this SA (see aws_wif.tf).
    coalesce(var.aws_wif.enabled, false) ? [
      "iam.googleapis.com",
      "iamcredentials.googleapis.com",
      "sts.googleapis.com",
    ] : [],
  )

  # API enablement, quota, and billing are per project even though the network
  # path is shared, so every consumer needs these in its own project.
  service_project_apis = [
    "compute.googleapis.com",
    "aiplatform.googleapis.com",
  ]

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    component   = "vertex-psc"
  }

  # Regional Vertex hosts are siblings of the global one, not children, so each
  # needs its own record. Deriving them from the subnets means a caller can use
  # either the global or a regional endpoint without editing the allowlist.
  regional_api_hosts = [for s in var.subnets : "${s.region}-aiplatform.googleapis.com"]
  allowed_api_hosts  = toset(concat(var.allowed_api_hosts, local.regional_api_hosts))

  # The model policy is a per-project control, so it covers the host project and
  # every service project that can call the endpoint.
  model_policy_projects = var.enforce_model_allowlist ? toset(concat(
    [var.host_project_id],
    [for sp in var.service_projects : sp.project_id],
  )) : toset([])

  subnet_keys       = sort(keys(var.subnets))
  default_subnet    = local.subnet_keys[0]
  router_region     = coalesce(var.hybrid_router_region, var.subnets[local.default_subnet].region)
  client_sa_project = { for k, sp in var.service_projects : k => sp if sp.create_client_sa }

  allowed_subnets = {
    for spk, sp in var.service_projects :
    spk => length(sp.subnets) == 0 ? local.subnet_keys : sp.subnets
  }

  # roles/compute.networkUser is needed by whoever creates resources in the shared
  # subnet: the service project's Google APIs service agent, plus any Terraform
  # identity or group that provisions there. The workload's own service account
  # does not need it.
  network_users = {
    for spk, sp in var.service_projects :
    spk => concat(
      ["serviceAccount:${data.google_project.service[spk].number}@cloudservices.gserviceaccount.com"],
      sp.extra_network_users,
    )
  }

  # Keys stay static so for_each is resolvable at plan time; the member string is
  # looked up in the value.
  subnet_grants = flatten([
    for spk, sp in var.service_projects : [
      for sk in local.allowed_subnets[spk] : [
        for idx in range(length(local.network_users[spk])) : {
          key          = "${spk}/${sk}/${idx}"
          project_key  = spk
          subnet_key   = sk
          member_index = idx
        }
      ]
    ]
  ])

  service_project_api_grants = flatten([
    for spk, sp in var.service_projects : [
      for api in local.service_project_apis : {
        key        = "${spk}/${api}"
        project_id = sp.project_id
        api        = api
      }
    ]
  ])
}

resource "google_project_service" "host" {
  for_each = var.manage_apis ? toset(local.host_apis) : toset([])

  project            = var.host_project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_project_service" "service_projects" {
  for_each = var.manage_apis ? { for g in local.service_project_api_grants : g.key => g } : {}

  project            = each.value.project_id
  service            = each.value.api
  disable_on_destroy = false
}

# ---------------------------------------------------------------------------
# Shared VPC
# ---------------------------------------------------------------------------

# Needs roles/compute.xpnAdmin at the org or folder level. See the runbook: if the
# Terraform identity only has project-level roles, leave enable_shared_vpc_host
# false and enable the host project once out of band.
resource "google_compute_shared_vpc_host_project" "host" {
  count = var.enable_shared_vpc_host ? 1 : 0

  project    = var.host_project_id
  depends_on = [google_project_service.host]
}

resource "google_compute_shared_vpc_service_project" "attached" {
  for_each = var.service_projects

  host_project    = var.host_project_id
  service_project = each.value.project_id

  depends_on = [
    google_compute_shared_vpc_host_project.host,
    google_project_service.service_projects,
  ]
}

resource "google_compute_network" "vpc" {
  project                 = var.host_project_id
  name                    = "${local.name_prefix}-vpc"
  auto_create_subnetworks = false
  description             = "Shared VPC with a single Private Service Connect path to Vertex AI"

  depends_on = [google_project_service.host]
}

# private_ip_google_access stays off so a successful call proves the PSC path
# rather than falling back to the Private Google Access VIPs.
resource "google_compute_subnetwork" "clients" {
  for_each = var.subnets

  project                  = var.host_project_id
  name                     = "${local.name_prefix}-${each.key}"
  region                   = each.value.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = each.value.cidr
  private_ip_google_access = false

  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ranges
    content {
      range_name    = secondary_ip_range.key
      ip_cidr_range = secondary_ip_range.value
    }
  }
}

resource "google_compute_subnetwork_iam_member" "network_user" {
  for_each = { for g in local.subnet_grants : g.key => g }

  project    = var.host_project_id
  region     = var.subnets[each.value.subnet_key].region
  subnetwork = google_compute_subnetwork.clients[each.value.subnet_key].name
  role       = "roles/compute.networkUser"
  member     = local.network_users[each.value.project_key][each.value.member_index]
}

# ---------------------------------------------------------------------------
# The single Private Service Connect endpoint
# ---------------------------------------------------------------------------

# One global internal address plus one global forwarding rule serves every
# region and every attached service project. There is no per-project or
# per-region endpoint to duplicate.
resource "google_compute_global_address" "psc" {
  project      = var.host_project_id
  name         = "${local.name_prefix}-ip"
  address_type = "INTERNAL"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  network      = google_compute_network.vpc.id
  address      = var.psc_endpoint_ip
}

# load_balancing_scheme must be the empty string; this is a PSC forwarding rule,
# not a load balancer.
# PSC Google APIs forwarding-rule names are strict: 1-20 chars, lowercase
# letters and digits only, must start with a letter (no hyphens).
resource "google_compute_global_forwarding_rule" "psc" {
  project               = var.host_project_id
  name                  = "vpsc${var.name_suffix}ep"
  target                = var.psc_target
  network               = google_compute_network.vpc.id
  ip_address            = google_compute_global_address.psc.id
  load_balancing_scheme = ""
}

# ---------------------------------------------------------------------------
# DNS: one private zone, visible to every project in the Shared VPC
# ---------------------------------------------------------------------------

# Private zone visibility is scoped to the network, not the project, so this
# single zone resolves googleapis.com for workloads in every attached service
# project. The zone is authoritative for the whole domain, which is what makes the
# allowlist below a hard block rather than a preference: a name with no record here
# does not fall through to public DNS, it fails to resolve.
resource "google_dns_managed_zone" "googleapis" {
  project     = var.host_project_id
  name        = "${local.name_prefix}-googleapis"
  dns_name    = "googleapis.com."
  description = "Resolves the allowed Google APIs to the shared PSC endpoint"
  visibility  = "private"
  labels      = local.labels

  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc.id
    }
  }

  depends_on = [google_project_service.host]
}

# One A record per allowed hostname. All of them point at the same endpoint, so
# widening the allowlist never means adding another endpoint.
resource "google_dns_record_set" "allowed_api" {
  for_each = local.allowed_api_hosts

  project      = var.host_project_id
  managed_zone = google_dns_managed_zone.googleapis.name
  name         = "${each.value}."
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.psc.address]
}

# Only created when the allowlist is deliberately abandoned. The apex A record is
# needed as the CNAME target.
resource "google_dns_record_set" "googleapis_apex" {
  count = var.allow_all_google_apis ? 1 : 0

  project      = var.host_project_id
  managed_zone = google_dns_managed_zone.googleapis.name
  name         = "googleapis.com."
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.psc.address]
}

resource "google_dns_record_set" "googleapis_wildcard" {
  count = var.allow_all_google_apis ? 1 : 0

  project      = var.host_project_id
  managed_zone = google_dns_managed_zone.googleapis.name
  name         = "*.googleapis.com."
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["googleapis.com."]
}

# Lets on-prem resolvers query the private zone above by forwarding to an
# inbound forwarder entry point in the region of the VPN tunnel.
resource "google_dns_policy" "inbound" {
  project                   = var.host_project_id
  name                      = "${local.name_prefix}-inbound"
  description               = "Inbound forwarding so on-prem can resolve googleapis.com to the shared PSC endpoint"
  enable_inbound_forwarding = true

  networks {
    network_url = google_compute_network.vpc.id
  }

  depends_on = [google_project_service.host]
}

# ---------------------------------------------------------------------------
# Hybrid connectivity
# ---------------------------------------------------------------------------

# The PSC endpoint IP is outside every subnet range, so ALL_SUBNETS does not
# cover it and on-prem would have no route. Attach HA VPN tunnels or a VLAN
# attachment to this router to complete the path for all service projects at once.
resource "google_compute_router" "hybrid" {
  count = var.enable_hybrid_router ? 1 : 0

  project     = var.host_project_id
  name        = "${local.name_prefix}-router"
  region      = local.router_region
  network     = google_compute_network.vpc.id
  description = "Advertises the shared PSC endpoint IP to on-prem over BGP"

  bgp {
    asn               = var.cloud_router_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]

    advertised_ip_ranges {
      range       = "${var.psc_endpoint_ip}/32"
      description = "Private Service Connect endpoint for Google APIs"
    }
  }
}

# Optional hard allow for traffic that arrives from local/OpenShift networks over
# the hybrid connection and is destined for the shared PSC endpoint.
resource "google_compute_firewall" "allow_hybrid_psc" {
  count = length(var.hybrid_source_ranges) > 0 ? 1 : 0

  project     = var.host_project_id
  name        = "${local.name_prefix}-allow-hybrid-psc"
  network     = google_compute_network.vpc.name
  description = "HTTPS from local PC / OpenShift CIDRs to the shared PSC endpoint"
  direction   = "INGRESS"
  priority    = 1000

  source_ranges      = var.hybrid_source_ranges
  destination_ranges = ["${var.psc_endpoint_ip}/32"]

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
}

# Inbound DNS forwarder IPs that local/OpenShift resolvers must target. Created
# automatically in each subnet when the inbound DNS policy is enabled.
data "google_compute_addresses" "dns_inbound" {
  for_each = var.subnets

  project = var.host_project_id
  region  = each.value.region
  filter  = "purpose=\"DNS_RESOLVER\" AND status=\"RESERVED\""

  depends_on = [
    google_dns_policy.inbound,
    google_compute_subnetwork.clients,
  ]
}

# ---------------------------------------------------------------------------
# Model allowlist
# ---------------------------------------------------------------------------

# DNS narrows the endpoint to the Vertex AI service; this narrows Vertex AI to
# specific models. IAM cannot do it — roles/aiplatform.user is service-wide with no
# per-model scope — so the only real control is this org policy. Set per project
# because model access, quota, and Model Garden enablement are all per project.
#
# An allowedValues list is implicitly deny-all-others, which is why adding a model
# means adding it to var.allowed_models rather than removing a restriction.
resource "google_project_service" "orgpolicy" {
  for_each = var.manage_apis ? local.model_policy_projects : toset([])

  project            = each.value
  service            = "orgpolicy.googleapis.com"
  disable_on_destroy = false
}

resource "google_org_policy_policy" "allowed_models" {
  for_each = local.model_policy_projects

  name   = "projects/${each.value}/policies/vertexai.allowedModels"
  parent = "projects/${each.value}"

  spec {
    rules {
      values {
        allowed_values = var.allowed_models
      }
    }
  }

  depends_on = [google_project_service.orgpolicy]
}

# ---------------------------------------------------------------------------
# Per-project client identity
# ---------------------------------------------------------------------------

data "google_project" "service" {
  for_each = var.service_projects

  project_id = each.value.project_id
}

resource "google_service_account" "host_client" {
  project      = var.host_project_id
  account_id   = "vertex-psc-client-${var.name_suffix}"
  display_name = "Vertex AI PSC Client"
  description  = "Calls Gemini and Claude through the shared PSC endpoint"

  depends_on = [google_project_service.host]
}

resource "google_project_iam_member" "host_client_vertex_user" {
  project = var.host_project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.host_client.email}"
}

resource "google_service_account" "client" {
  for_each = local.client_sa_project

  project      = each.value.project_id
  account_id   = "vertex-psc-client-${var.name_suffix}"
  display_name = "Vertex AI PSC Client"
  description  = "Calls Gemini and Claude through the shared PSC endpoint"

  depends_on = [google_project_service.service_projects]
}

# Model calls are billed and quota-checked against the calling project, so each
# service project grants its own aiplatform.user.
resource "google_project_iam_member" "client_vertex_user" {
  for_each = local.client_sa_project

  project = each.value.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.client[each.key].email}"
}

# Long-lived credentials for callers that cannot use the metadata server or
# Workload Identity Federation, i.e. genuine on-prem hosts and laptops.
resource "google_service_account_key" "host_client" {
  count = var.create_sa_key ? 1 : 0

  service_account_id = google_service_account.host_client.name
}

resource "google_service_account_key" "client" {
  for_each = var.create_sa_key ? local.client_sa_project : {}

  service_account_id = google_service_account.client[each.key].name
}


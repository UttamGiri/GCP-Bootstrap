terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source = "hashicorp/google"
      # ~> 5.0 allows any 5.x (>= 5.0, < 6.0). "terraform init -upgrade" resolves
      # to the latest matching release; .terraform.lock.hcl pins that exact version
      # so TFE and local runs use the same provider until you upgrade the lock again.
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

data "terraform_remote_state" "bootstrap" {
  backend = "remote"

  config = {
    organization = "vaflt-org"

    workspaces = {
      name = "GCP-Vaflt-Bootstrap"
    }
  }
}

locals {
  project_id = data.terraform_remote_state.bootstrap.outputs.bootstrap_project_id
  # Bumped by bump-tfe-auth after failed apply/destroy cycle (was 8 → 9).
  resource_suffix = "17"
  # Fixed — never bumped; bucket names are reusable after destroy (soft delete disabled).
  bucket_suffix = "1"
  # Fixed — never bumped; VPC/subnet/DNS names are reusable immediately after destroy.
  network_suffix = "1"
}

data "google_client_config" "default" {}

# Kubernetes provider talks to the shared GKE cluster when it exists.
# Placeholder host is used while shared_gke is disabled (no k8s resources planned).
provider "kubernetes" {
  host                   = try("https://${module.workload.shared_gke_cluster_endpoint}", "https://127.0.0.1")
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = try(base64decode(module.workload.shared_gke_cluster_ca_certificate), "")
}

provider "google" {
  project = local.project_id
}

module "workload" {
  source = "../../modules/workload-stack"

  providers = {
    kubernetes = kubernetes
  }

  project_id      = local.project_id
  workspace_id    = "ws-4V97YqCc8p3GH3U9" # GCP-vaflt-tfe-workspace
  resource_suffix = local.resource_suffix
  bucket_suffix   = local.bucket_suffix
  network_suffix  = local.network_suffix
  environment     = "dev"

  # Shared VPC with one PSC endpoint for every project — see docs/VERTEX-AI-PSC-ONPREM.md.
  vertex_psc = {
    enabled = true

    # This project is its own host for now; point at a dedicated network project later.
    host_project_id = local.project_id

    # Needs roles/compute.xpnAdmin at the org level. Until an org admin grants it,
    # leave false and run: gcloud compute shared-vpc enable <host project>
    enable_shared_vpc_host = false

    # One global endpoint covers every region, so subnets exist only for DNS
    # inbound forwarders / future hybrid / GKE. Secondary ranges are for
    # VPC-native GKE pods/services (used when shared_gke.enabled = true).
    subnets = {
      primary = {
        region = "us-central1"
        cidr   = "10.10.0.0/24"
        secondary_ranges = {
          gke-pods     = "10.20.0.0/16"
          gke-services = "10.30.0.0/20"
        }
      }
    }
    psc_endpoint_ip = "10.10.100.5"

    # One endpoint fronts every Google API, so DNS is what keeps it scoped to
    # Vertex AI: only these names resolve to it, and anything else under
    # googleapis.com does not resolve at all from this VPC. The regional Vertex
    # host for us-central1 is added automatically from the subnet list.
    #
    # oauth2/sts are only needed for the JWT token exchange. Drop them and use
    # TOKEN_MODE=self-signed for an aiplatform-only allowlist.
    allowed_api_hosts = [
      "aiplatform.googleapis.com",
      "oauth2.googleapis.com",
      "sts.googleapis.com",
    ]

    # Approved models. Add entries as more are approved.
    allowed_models = [
      "publishers/google/models/gemini-2.5-pro:predict",
      "publishers/anthropic/models/claude-sonnet-4-5:predict",
      "publishers/anthropic/models/claude-sonnet-5:predict",
    ]

    # Off until roles/orgpolicy.policyAdmin is granted at folder/org (cannot be
    # granted at project scope). DNS allowlist still scopes the PSC path.
    enforce_model_allowlist = false

    # Attach consumer projects here; each shares the one endpoint.
    #   app = {
    #     project_id     = "app-prj-123456"
    #   }
    service_projects = {}

    # Keep false to avoid hybrid connectivity cost. Cloud Router alone is free,
    # but HA VPN tunnels (~$0.05/hr each) are intentionally not in this stack.
    # Local/OpenShift private PSC access needs VPN/Interconnect later; until then
    # test Vertex with a service-account JWT over the public API path.
    enable_hybrid_router = false
    hybrid_source_ranges = []

    # Downloadable SA keys for JWT auth from on-prem or a laptop. The private key
    # lands in TFE state — see the auth section of docs/VERTEX-AI-PSC-ONPREM.md
    # before turning this on.
    create_sa_key = false
  }

  # ---------------------------------------------------------------------------
  # workload-dev project + shared GKE (see docs/DESIGN-WORKLOAD-DEV-GKE.md)
  # Keep enabled=false until you are ready to pay for GKE + create a project.
  # Flip both to true together after org/billing permissions are in place.
  # ---------------------------------------------------------------------------
  workload_dev = {
    enabled           = false
    create_project    = true
    project_id        = "vaflt-workload-dev-1" # must be globally unique
    project_name      = "workload-dev"
    org_id            = "327947404107"
    billing_account   = "01BC6F-241F9A-8762DE"
    # Requires Shared VPC host enabled (org xpnAdmin). Leave false until then.
    attach_shared_vpc = false
    # Add your user so you can impersonate gke-deployer for helm:
    # impersonators = ["user:you@vaflt.com"]
    impersonators = []
  }

  shared_gke = {
    enabled = false
    name    = "shared-gke-dev"
    region  = "us-central1"
    # false = public control plane so laptop kubectl works without VPN.
    # true  = private API only (needs VPN or Connect Gateway).
    enable_private_endpoint = false
    enable_private_nodes    = true
    node_count              = 1
    machine_type            = "e2-medium"
    namespace               = "workload-dev"
  }
}

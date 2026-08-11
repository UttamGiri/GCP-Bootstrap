variable "host_project_id" {
  description = "Shared VPC host project. Owns the VPC, subnets, the single PSC endpoint, DNS, and firewall rules."
  type        = string
}

variable "name_suffix" {
  description = "Fixed suffix for network/DNS names; not bumped on destroy (these names are immediately reusable)"
  type        = string
}

variable "environment" {
  description = "Environment label applied to created resources"
  type        = string
  default     = "dev"
}

variable "subnets" {
  description = "Shared VPC subnets, keyed by a short name. Terraform creates these. They host Cloud DNS inbound forwarders and the Cloud Router; one global PSC endpoint still serves every region."
  type = map(object({
    region = string
    cidr   = string
  }))
  default = {
    primary = {
      region = "us-central1"
      cidr   = "10.10.0.0/24"
    }
  }

  validation {
    condition     = length(var.subnets) > 0
    error_message = "At least one subnet is required."
  }
}

variable "psc_endpoint_ip" {
  description = "Internal IP for the single PSC endpoint. Must be inside the VPC's RFC1918 space but NOT inside any subnet range."
  type        = string
  default     = "10.10.100.5"
}

variable "psc_target" {
  description = "Google APIs bundle the endpoint fronts. Use all-apis without VPC Service Controls, vpc-sc with a perimeter."
  type        = string
  default     = "all-apis"

  validation {
    condition     = contains(["all-apis", "vpc-sc"], var.psc_target)
    error_message = "psc_target must be either all-apis or vpc-sc."
  }
}

# The endpoint target is only ever all-apis or vpc-sc, so the endpoint itself
# cannot be made Vertex-only. DNS is what scopes it: only the hostnames listed
# here get an A record, and because the private zone is authoritative for
# googleapis.com, every other Google API fails to resolve from this VPC.
#
# oauth2 and sts are here because token minting needs them. Drop them for the
# tightest possible allowlist and use a self-signed JWT, which contacts no auth
# server at all — see the auth section of docs/VERTEX-AI-PSC-ONPREM.md.
variable "allowed_api_hosts" {
  description = "googleapis.com hostnames that resolve to the shared endpoint. Add entries to widen the allowlist; regional Vertex AI hosts for every configured subnet region are added automatically."
  type        = list(string)
  default = [
    "aiplatform.googleapis.com",
    "oauth2.googleapis.com",
    "sts.googleapis.com",
  ]

  validation {
    condition     = alltrue([for h in var.allowed_api_hosts : endswith(h, ".googleapis.com")])
    error_message = "Every entry must be a hostname under googleapis.com; the private zone only covers that domain."
  }
}

# Escape hatch that restores the old behaviour of one endpoint fronting every
# Google API. Widening allowed_api_hosts is almost always the better move.
variable "allow_all_google_apis" {
  description = "Publish a wildcard so every API in the psc_target bundle resolves to the endpoint, instead of only allowed_api_hosts"
  type        = bool
  default     = false
}

variable "allowed_models" {
  description = "Model Garden entries callers may use, as publishers/PUBLISHER/models/MODEL:ACTION. Only enforced when enforce_model_allowlist is true."
  type        = list(string)
  default = [
    "publishers/google/models/gemini-2.5-pro:predict",
    "publishers/anthropic/models/claude-sonnet-5:predict",
  ]

  validation {
    condition = alltrue([
      for m in var.allowed_models : can(regex("^publishers/[^/]+/models/[^/:]+:(predict|deploy|tune)$", m))
    ])
    error_message = "Entries must look like publishers/PUBLISHER/models/MODEL:ACTION where ACTION is predict, deploy, or tune."
  }
}

# Off by default because this is a project-wide governance control, not a network
# one: it applies to all Vertex AI callers in the project, needs the Org Policy API
# plus roles/orgpolicy.policyAdmin, and overrides any inherited policy. DNS
# scoping above needs none of that.
variable "enforce_model_allowlist" {
  description = "Set the vertexai.allowedModels org policy on the calling projects so only allowed_models can be used"
  type        = bool
  default     = false
}

# Requires roles/compute.xpnAdmin at the org or folder level, which project-level
# Terraform identities do not have. Leave false and have an org admin run
# `gcloud compute shared-vpc enable HOST_PROJECT` once.
variable "enable_shared_vpc_host" {
  description = "Let Terraform mark host_project_id as a Shared VPC host project"
  type        = bool
  default     = false
}

variable "service_projects" {
  description = "Projects that consume the shared endpoint. Each is attached to the Shared VPC, granted subnet access, and gets the Vertex AI API plus a client service account."
  type = map(object({
    project_id = string
    # Subnet keys this project may use. Empty means all of them.
    subnets = optional(list(string), [])
    # Extra principals granted roles/compute.networkUser on those subnets, e.g. a
    # service project's own Terraform identity or a team group.
    extra_network_users = optional(list(string), [])
    create_client_sa    = optional(bool, true)
  }))
  default = {}

}

# Off by default for two reasons: the private key is stored in Terraform state,
# and many organizations block key creation outright with the
# constraints/iam.disableServiceAccountKeyCreation org policy. Prefer minting keys
# out of band with `gcloud iam service-accounts keys create`, or use Workload
# Identity Federation and no key at all.
variable "create_sa_key" {
  description = "Create downloadable JSON keys for the client service accounts, for JWT auth from on-prem or a laptop"
  type        = bool
  default     = false
}

variable "manage_apis" {
  description = "Enable the APIs this module needs in the host and service projects. Disable if another stack already manages them."
  type        = bool
  default     = true
}

variable "enable_hybrid_router" {
  description = "Create a Cloud Router that advertises the PSC endpoint IP as a /32. Default false for low-cost deploys. Does not create HA VPN tunnels (those cost ~$0.05/hr each and are intentionally out of this module)."
  type        = bool
  default     = false
}

variable "hybrid_router_region" {
  description = "Region for the Cloud Router. Defaults to the first subnet's region."
  type        = string
  default     = null
}

variable "cloud_router_asn" {
  description = "BGP ASN for the Cloud Router when enable_hybrid_router is true"
  type        = number
  default     = 64514
}

# Empty means no dedicated hybrid firewall rule is created. Default VPC rules are
# often enough for PSC Google APIs, but locked-down networks need an explicit
# allow from the local/OpenShift CIDRs to the PSC IP on TCP 443.
variable "hybrid_source_ranges" {
  description = "CIDRs of local PC / OpenShift networks allowed to reach the PSC endpoint over VPN or Interconnect"
  type        = list(string)
  default     = []
}


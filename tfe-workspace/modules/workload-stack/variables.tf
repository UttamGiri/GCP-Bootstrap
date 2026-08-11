variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "workspace_id" {
  description = "TFE workspace ID for WIF impersonation"
  type        = string
}

variable "resource_suffix" {
  description = "Suffix for SA/WIF names; bumped after each identity destroy"
  type        = string
}

variable "bucket_suffix" {
  description = "Fixed suffix for bucket names; not bumped on destroy"
  type        = string
}

variable "environment" {
  description = "Environment label for workload resources"
  type        = string
  default     = "dev"
}

variable "network_suffix" {
  description = "Fixed suffix for VPC/subnet/DNS names; not bumped on destroy"
  type        = string
  default     = "1"
}

# Shared VPC with a single PSC endpoint for every attached project.
# See docs/VERTEX-AI-PSC-ONPREM.md. Unset fields fall through to module defaults.
variable "vertex_psc" {
  description = "Shared VPC and Private Service Connect path to Vertex AI"
  type = object({
    enabled                = optional(bool, false)
    host_project_id        = optional(string, null)
    enable_shared_vpc_host = optional(bool, false)
    subnets = optional(map(object({
      region = string
      cidr   = string
      })), {
      primary = {
        region = "us-central1"
        cidr   = "10.10.0.0/24"
      }
    })
    psc_endpoint_ip = optional(string, "10.10.100.5")
    psc_target      = optional(string, "all-apis")
    service_projects = optional(map(object({
      project_id          = string
      subnets             = optional(list(string), [])
      extra_network_users = optional(list(string), [])
      create_client_sa    = optional(bool, true)
    })), {})
    enable_hybrid_router = optional(bool, false)
    hybrid_source_ranges = optional(list(string), [])
    create_sa_key        = optional(bool, false)

    allowed_api_hosts = optional(list(string), [
      "aiplatform.googleapis.com",
      "oauth2.googleapis.com",
      "sts.googleapis.com",
    ])
    allow_all_google_apis = optional(bool, false)
    allowed_models = optional(list(string), [
      "publishers/google/models/gemini-2.5-pro:predict",
      "publishers/anthropic/models/claude-sonnet-5:predict",
    ])
    enforce_model_allowlist = optional(bool, false)
  })
  default = {}
}

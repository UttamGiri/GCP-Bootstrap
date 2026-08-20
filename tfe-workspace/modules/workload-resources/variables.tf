variable "project_id" {
  type = string
}

variable "resource_suffix" {
  type = string
}

variable "bucket_suffix" {
  type = string
}

variable "environment" {
  type = string
}

# Fixed like bucket_suffix, not bumped like resource_suffix: VPC, subnet, and DNS
# names are immediately reusable after a destroy.
variable "network_suffix" {
  type = string
}

variable "vertex_psc" {
  type = object({
    enabled                = optional(bool, false)
    host_project_id        = optional(string, null)
    enable_shared_vpc_host = optional(bool, false)
    subnets = optional(map(object({
      region           = string
      cidr             = string
      secondary_ranges = optional(map(string), {})
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
      "publishers/anthropic/models/claude-sonnet-4-5:predict",
      "publishers/anthropic/models/claude-sonnet-5:predict",
    ])
    enforce_model_allowlist = optional(bool, false)
    aws_wif = optional(object({
      enabled        = optional(bool, false)
      aws_account_id = optional(string, null)
      aws_role_name  = optional(string, null)
      pool_id        = optional(string, "aws-kong-vertex")
      provider_id    = optional(string, "aws-kong")
    }), {})
  })
}

# workload-dev GCP project + deployer SA (impersonation target for helm)
variable "workload_dev" {
  type = object({
    enabled             = optional(bool, false)
    create_project      = optional(bool, true)
    project_id          = optional(string, null)
    project_name        = optional(string, "workload-dev")
    org_id              = optional(string, null)
    folder_id           = optional(string, null)
    billing_account     = optional(string, null)
    attach_shared_vpc   = optional(bool, true)
    deployer_account_id = optional(string, "gke-deployer")
    impersonators       = optional(list(string), [])
  })
  default = {}
}

# Shared GKE on the Vertex Shared VPC + tenant namespace RBAC
variable "shared_gke" {
  type = object({
    enabled                 = optional(bool, false)
    name                    = optional(string, "shared-gke-dev")
    region                  = optional(string, "us-central1")
    subnet_key              = optional(string, "primary")
    pods_range_name         = optional(string, "gke-pods")
    services_range_name     = optional(string, "gke-services")
    enable_private_nodes    = optional(bool, true)
    enable_private_endpoint = optional(bool, false)
    master_ipv4_cidr_block  = optional(string, "172.16.0.0/28")
    node_count              = optional(number, 1)
    machine_type            = optional(string, "e2-medium")
    namespace               = optional(string, "workload-dev")
  })
  default = {}
}

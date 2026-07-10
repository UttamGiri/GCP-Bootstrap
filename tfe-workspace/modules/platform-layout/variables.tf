variable "org_id" {
  description = "GCP organization ID where platform folders are created"
  type        = string
}

variable "billing_account" {
  description = "Billing account ID for platform-created projects"
  type        = string
}

variable "folders" {
  description = "Top-level org folders to create"
  type        = map(string)
  default = {
    platform = "Platform"
    dev      = "Dev"
    prod     = "Prod"
  }
}

variable "folder_policy_configs" {
  description = "OU policies per folder key (dev, prod). Platform defines what workload teams may create."
  type = map(object({
    allowed_regions                      = optional(list(string), ["in:us-locations"])
    disable_service_account_key_creation = optional(bool, true)
    require_uniform_bucket_level_access  = optional(bool, true)
  }))
  default = {
    dev = {}
    prod = {
      allowed_regions = ["in:us-locations"]
    }
  }
}

variable "shared_networks" {
  description = "One shared VPC host project per environment (dev, preprod, prod). Lower env subnets are derived from workload_projects."
  type = map(object({
    folder_key   = string
    project_id   = string
    project_name = string
    network_name = string
    subnets = optional(map(object({
      region        = string
      ip_cidr_range = string
    })), {})
    project_labels = optional(map(string), {})
  }))
  default = {
    dev = {
      folder_key   = "dev"
      project_id   = "vaflt-shared-net-dev"
      project_name = "Vaflt Shared Network Dev"
      network_name = "shared-vpc-dev"
      # Subnets created per team from workload_projects (subnet_cidr + map key).
    }
    preprod = {
      folder_key   = "dev"
      project_id   = "vaflt-shared-net-preprod"
      project_name = "Vaflt Shared Network Preprod"
      network_name = "shared-vpc-preprod"
    }
    prod = {
      folder_key   = "prod"
      project_id   = "vaflt-shared-net-prod"
      project_name = "Vaflt Shared Network Prod"
      network_name = "shared-vpc-prod"
      subnets = {
        workload = {
          region        = "us-central1"
          ip_cidr_range = "10.20.0.0/20"
        }
      }
    }
  }
}

variable "default_service_account_roles" {
  description = "Default project IAM roles for each team service account (app deploy roles live in team repos; keep minimal here)"
  type        = list(string)
  default = [
    "roles/viewer",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ]
}

variable "workload_projects" {
  description = "Platform-provisioned workload projects — project + SA + WIF + shared VPC attach"
  type = map(object({
    folder_key                              = string
    shared_network_key                      = string
    project_id                              = string
    project_name                            = string
    tfe_workspace_id                        = string
    service_account_id                      = string
    service_account_display_name            = optional(string)
    service_account_roles                   = optional(list(string))
    subnet_cidr                             = optional(string)
    subnet_region                           = optional(string)
    shared_subnet_names                     = optional(list(string))
    project_labels                          = optional(map(string), {})
    workload_identity_pool_id               = optional(string)
    workload_identity_pool_display_name     = optional(string)
    workload_identity_provider_id           = optional(string)
    workload_identity_provider_display_name = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, t in var.workload_projects :
      !contains(["dev", "preprod"], t.shared_network_key) || try(t.subnet_cidr, null) != null
    ])
    error_message = "Each dev/preprod team must set subnet_cidr — one dedicated subnet is created per team map key."
  }
}

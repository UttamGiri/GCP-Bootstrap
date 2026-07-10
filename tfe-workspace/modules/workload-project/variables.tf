variable "folder_id" {
  description = "Full folder resource name (folders/NUMERIC_ID) where the project is created"
  type        = string
}

variable "billing_account" {
  description = "Billing account ID attached to the new project"
  type        = string
}

variable "project_id" {
  description = "GCP project ID for this workload team"
  type        = string
}

variable "project_name" {
  description = "Display name for the GCP project"
  type        = string
}

variable "project_labels" {
  description = "Labels applied to the GCP project"
  type        = map(string)
  default     = {}
}

variable "tfe_workspace_id" {
  description = "TFE workspace ID allowed to impersonate this project's service account (required when enable_identity is true)"
  type        = string
  default     = ""
}

variable "enable_identity" {
  description = "Create team SA + WIF scoped to tfe_workspace_id"
  type        = bool
  default     = false
}

variable "human_users" {
  description = "Human GCP users and project roles — only on this team project"
  type        = map(list(string))
  default     = {}
}

variable "storage_buckets" {
  description = "GCS object storage buckets in this team project (globally unique bucket names)"
  type = map(object({
    location                    = string
    storage_class               = optional(string)
    force_destroy               = optional(bool)
    uniform_bucket_level_access = optional(bool)
  }))
  default = {}
}

variable "service_account_id" {
  description = "Service account ID (short name) for the team's TFE runs (required when enable_identity is true)"
  type        = string
  default     = ""
}

variable "service_account_display_name" {
  description = "Display name for the team service account"
  type        = string
  default     = null
}

variable "service_account_roles" {
  description = "Project IAM roles granted to the team service account"
  type        = list(string)
}

variable "workload_identity_pool_id" {
  description = "Workload Identity Pool ID for this team project"
  type        = string
}

variable "workload_identity_pool_display_name" {
  description = "Display name for the team WIF pool"
  type        = string
}

variable "workload_identity_provider_id" {
  description = "Workload Identity Provider ID for this team project"
  type        = string
}

variable "workload_identity_provider_display_name" {
  description = "Display name for the team WIF provider"
  type        = string
}

variable "shared_vpc_host_project_id" {
  description = "Shared VPC host project ID; when set, attaches this workload project as a service project"
  type        = string
  default     = null
}

variable "shared_subnet_names" {
  description = "Subnet names in the host project where this service project gets compute.networkUser"
  type        = list(string)
  default     = []
}

variable "shared_subnet_region" {
  description = "Region of shared_subnet_names in the host VPC (all names must be in this region for now)"
  type        = string
  default     = "us-central1"
}

# Disabled: SA + WIF per team (see module.identity in workload-project/main.tf).
variable "required_services" {
  description = "APIs enabled on the workload project"
  type        = list(string)
  default = [
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
  ]
}

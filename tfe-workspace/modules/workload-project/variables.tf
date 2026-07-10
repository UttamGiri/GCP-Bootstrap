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
  description = "TFE workspace ID allowed to impersonate this project's service account"
  type        = string
}

variable "service_account_id" {
  description = "Service account ID (short name) for the team's TFE runs"
  type        = string
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

variable "shared_subnet_self_links" {
  description = "Subnet self links in the host project where the team SA gets compute.networkUser"
  type        = list(string)
  default     = []
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

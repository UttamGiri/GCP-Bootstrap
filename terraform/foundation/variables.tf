variable "project_id" {
  description = "GCP project ID used by foundation resources (and created when create_project=true)"
  type        = string
}

variable "create_project" {
  description = "Create the bootstrap GCP project as part of foundation"
  type        = bool
  default     = true
}

variable "project_name" {
  description = "Display name for bootstrap project (defaults to project_id)"
  type        = string
  default     = null
}

variable "org_id" {
  description = "GCP organization ID used when create_project=true and folder_id is not set"
  type        = string
  default     = null

  validation {
    condition     = !var.create_project || ((var.org_id != null) != (var.folder_id != null))
    error_message = "When create_project=true, set exactly one of org_id or folder_id."
  }
}

variable "folder_id" {
  description = "GCP folder ID used when create_project=true (alternative to org_id)"
  type        = string
  default     = null
}

variable "billing_account" {
  description = "Billing account ID to attach when create_project=true"
  type        = string
  default     = null

  validation {
    condition     = !var.create_project || var.billing_account != null
    error_message = "billing_account is required when create_project=true."
  }
}

variable "project_labels" {
  description = "Labels to apply to bootstrap project when create_project=true"
  type        = map(string)
  default     = {}
}

variable "required_services" {
  description = "Project APIs enabled by foundation before creating resources"
  type        = list(string)
  default = [
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "storage.googleapis.com"
  ]
}

variable "create_state_bucket" {
  description = "Create a GCS bucket for foundation remote state in the bootstrap project"
  type        = bool
  default     = true
}

variable "foundation_state_bucket_name" {
  description = "Name of GCS bucket for foundation state (must be globally unique)"
  type        = string
  default     = null
}

variable "foundation_state_bucket_location" {
  description = "Location/region for foundation state bucket"
  type        = string
  default     = "US"
}

variable "foundation_state_bucket_storage_class" {
  description = "Storage class for foundation state bucket"
  type        = string
  default     = "STANDARD"
}

variable "foundation_state_bucket_force_destroy" {
  description = "Allow deleting non-empty foundation state bucket"
  type        = bool
  default     = false
}

variable "bootstrap_service_account_name" {
  description = "Account ID for the bootstrap service account"
  type        = string
  default     = "bs-tfe-sa"
}

variable "bootstrap_service_account_display_name" {
  description = "Display name for the bootstrap service account"
  type        = string
  default     = "Bootstrap Terraform Enterprise Service Account"
}

variable "bootstrap_roles" {
  description = "Initial project-level roles required by the bootstrap service account"
  type        = list(string)
  default = [
    "roles/viewer",
    "roles/storage.admin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountTokenCreator"
  ]
}

variable "oidc_issuer_uri" {
  description = "OIDC issuer for Terraform workspace identity"
  type        = string
  default     = "https://app.terraform.io"
}

variable "tfe_workspace_id" {
  description = "Terraform workspace ID allowed to impersonate bootstrap service account"
  type        = string
}

variable "workload_identity_pool_id" {
  description = "Workload Identity Pool ID used for Terraform workspace OIDC"
  type        = string
  default     = "tfe-pool"
}

variable "workload_identity_pool_display_name" {
  description = "Display name of Workload Identity Pool"
  type        = string
  default     = "Terraform Workspace Pool"
}

variable "workload_identity_provider_id" {
  description = "Workload Identity Provider ID used for Terraform workspace OIDC"
  type        = string
  default     = "tfe-provider"
}

variable "workload_identity_provider_display_name" {
  description = "Display name of Workload Identity Provider"
  type        = string
  default     = "Terraform Workspace OIDC Provider"
}

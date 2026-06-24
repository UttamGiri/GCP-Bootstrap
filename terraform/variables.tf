variable "project_id" {
  description = "GCP project ID used by bootstrap resources (and created when create_project=true)"
  type        = string
}

variable "create_project" {
  description = "Create the bootstrap GCP project as part of this run"
  type        = bool
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
  description = "Labels to apply to bootstrap project"
  type        = map(string)
}

variable "required_services" {
  description = "Project APIs enabled before creating resources"
  type        = list(string)
}

variable "bootstrap_service_account_name" {
  description = "Account ID for bootstrap service account"
  type        = string
}

variable "bootstrap_service_account_display_name" {
  description = "Display name for bootstrap service account"
  type        = string
}

variable "bootstrap_roles" {
  description = "Project roles assigned to bootstrap service account"
  type        = list(string)
}

variable "oidc_issuer_uri" {
  description = "OIDC issuer for Terraform workspace identity"
  type        = string
}

variable "tfe_workspace_id" {
  description = "Terraform workspace ID allowed to impersonate bootstrap service account"
  type        = string
}

variable "workload_identity_pool_id" {
  description = "Workload Identity Pool ID for Terraform workspace OIDC"
  type        = string
}

variable "workload_identity_pool_display_name" {
  description = "Display name of Workload Identity Pool"
  type        = string

  validation {
    condition     = length(var.workload_identity_pool_display_name) <= 32
    error_message = "workload_identity_pool_display_name must be 32 characters or fewer."
  }
}

variable "workload_identity_provider_id" {
  description = "Workload Identity Provider ID for Terraform workspace OIDC"
  type        = string
}

variable "workload_identity_provider_display_name" {
  description = "Display name of Workload Identity Provider"
  type        = string

  validation {
    condition     = length(var.workload_identity_provider_display_name) <= 32
    error_message = "workload_identity_provider_display_name must be 32 characters or fewer."
  }
}

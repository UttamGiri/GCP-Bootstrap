variable "project_id" {
  description = "GCP project ID where bootstrap resources are created"
  type        = string
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
  description = "Project-level roles required by the bootstrap service account"
  type        = list(string)
  default = [
    "roles/viewer",
    "roles/storage.admin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountTokenCreator"
  ]
}

variable "github_repository" {
  description = "GitHub repository in the format org/repo allowed to use OIDC"
  type        = string
}

variable "github_branch" {
  description = "Git branch allowed to use OIDC (without refs/heads/ prefix)"
  type        = string
  default     = "main"
}

variable "workload_identity_pool_id" {
  description = "Workload Identity Pool ID used for GitHub OIDC"
  type        = string
  default     = "github-pool"
}

variable "workload_identity_pool_display_name" {
  description = "Display name of Workload Identity Pool"
  type        = string
  default     = "GitHub Actions Pool"
}

variable "workload_identity_provider_id" {
  description = "Workload Identity Provider ID used for GitHub OIDC"
  type        = string
  default     = "github-provider"
}

variable "workload_identity_provider_display_name" {
  description = "Display name of Workload Identity Provider"
  type        = string
  default     = "GitHub OIDC Provider"
}

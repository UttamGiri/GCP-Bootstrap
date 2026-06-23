variable "project_id" {
  description = "GCP project ID where bootstrap roles are managed"
  type        = string
}

variable "bootstrap_service_account_name" {
  description = "Account ID for the existing bootstrap service account"
  type        = string
  default     = "bs-tfe-sa"
}

variable "bootstrap_roles" {
  description = "Project-level roles to keep assigned to the bootstrap service account"
  type        = list(string)
  default = [
    "roles/viewer",
    "roles/storage.admin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountTokenCreator"
  ]
}

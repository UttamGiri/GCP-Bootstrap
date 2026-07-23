terraform {
  required_providers {
    google = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

variable "project_id" {
  description = "GCP project ID where workspace identity resources are created"
  type        = string
}

variable "workspace_id" {
  description = "TFE workspace ID allowed to impersonate this service account"
  type        = string
}

variable "service_account_id" {
  description = "Service account ID for this workspace"
  type        = string
}

variable "service_account_display_name" {
  description = "Display name for this workspace service account"
  type        = string
}

variable "service_account_roles" {
  description = "Project roles granted to this workspace service account"
  type        = list(string)
}

variable "workload_identity_pool_id" {
  description = "Workload Identity Pool ID for this workspace"
  type        = string
}

variable "workload_identity_pool_display_name" {
  description = "Display name for this workspace Workload Identity Pool"
  type        = string
}

variable "workload_identity_provider_id" {
  description = "Workload Identity Provider ID for this workspace"
  type        = string
}

variable "workload_identity_provider_display_name" {
  description = "Display name for this workspace Workload Identity Provider"
  type        = string
}

variable "oidc_issuer_uri" {
  description = "OIDC issuer for TFE/TFC workspace identity"
  type        = string
  default     = "https://app.terraform.io"
}

data "google_project" "current" {
  project_id = var.project_id
}

# Created first. Destroyed last so this SA can tear down WIF/bucket/other workload
# resources while credentials are still valid.
resource "google_service_account" "workspace" {
  project      = var.project_id
  account_id   = var.service_account_id
  display_name = var.service_account_display_name
}

resource "google_project_iam_member" "workspace_roles" {
  for_each = toset(var.service_account_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.workspace.email}"
}

resource "google_iam_workload_identity_pool" "workspace" {
  project                   = var.project_id
  workload_identity_pool_id = var.workload_identity_pool_id
  display_name              = var.workload_identity_pool_display_name
  description               = "OIDC pool for this TFE workspace"

  depends_on = [
    google_service_account.workspace,
    google_project_iam_member.workspace_roles,
  ]

  timeouts {
    delete = "30m"
  }
}

resource "google_iam_workload_identity_pool_provider" "workspace" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.workspace.workload_identity_pool_id
  workload_identity_pool_provider_id = var.workload_identity_provider_id
  display_name                       = var.workload_identity_provider_display_name
  description                        = "OIDC provider for this TFE workspace"

  attribute_mapping = {
    "google.subject"                      = "assertion.sub"
    "attribute.terraform_workspace"       = "assertion.terraform_workspace_name"
    "attribute.terraform_workspace_id"    = "assertion.terraform_workspace_id"
    "attribute.terraform_organization_id" = "assertion.terraform_organization_id"
  }

  oidc {
    issuer_uri = var.oidc_issuer_uri
  }

  attribute_condition = "assertion.terraform_workspace_id == '${var.workspace_id}'"

  depends_on = [google_iam_workload_identity_pool.workspace]
}

resource "google_service_account_iam_member" "workspace_impersonation" {
  service_account_id = google_service_account.workspace.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.workspace.workload_identity_pool_id}/attribute.terraform_workspace_id/${var.workspace_id}"

  depends_on = [google_iam_workload_identity_pool_provider.workspace]
}

output "service_account_email" {
  description = "Workspace service account email"
  value       = google_service_account.workspace.email
}

output "workload_identity_provider" {
  description = "Workspace Workload Identity Provider name"
  value       = google_iam_workload_identity_pool_provider.workspace.name
}

terraform {
  required_version = ">= 1.5.0"
  # Backend intentionally not configured here.
  # First run uses local state, then state is imported to TFE/TFC workspace.

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
}

locals {
  target_project_id = var.project_id
}

resource "google_project" "bootstrap" {
  count = var.create_project ? 1 : 0

  project_id      = local.target_project_id
  name            = coalesce(var.project_name, local.target_project_id)
  org_id          = var.folder_id == null ? var.org_id : null
  folder_id       = var.folder_id
  billing_account = var.billing_account
  labels          = var.project_labels
}

resource "google_project_service" "required" {
  for_each = toset(var.required_services)

  project            = local.target_project_id
  service            = each.value
  disable_on_destroy = false

  depends_on = [google_project.bootstrap]
}

data "google_project" "current" {
  project_id = local.target_project_id

  depends_on = [google_project_service.required]
}

resource "google_service_account" "bootstrap" {
  project      = local.target_project_id
  account_id   = var.bootstrap_service_account_name
  display_name = var.bootstrap_service_account_display_name

  depends_on = [google_project_service.required]
}

resource "google_project_iam_member" "bootstrap_roles" {
  for_each = toset(var.bootstrap_roles)

  project = local.target_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.bootstrap.email}"
}

resource "google_iam_workload_identity_pool" "tfe_pool" {
  project                   = local.target_project_id
  workload_identity_pool_id = var.workload_identity_pool_id
  display_name              = var.workload_identity_pool_display_name
  description               = "OIDC pool for Terraform workspace runs"

  depends_on = [google_project_service.required]
}

resource "google_iam_workload_identity_pool_provider" "tfe_provider" {
  project                            = local.target_project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.tfe_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = var.workload_identity_provider_id
  display_name                       = var.workload_identity_provider_display_name
  description                        = "Terraform workspace OIDC provider"

  attribute_mapping = {
    "google.subject"                      = "assertion.sub"
    "attribute.terraform_workspace"       = "assertion.terraform_workspace_name"
    "attribute.terraform_workspace_id"    = "assertion.terraform_workspace_id"
    "attribute.terraform_organization_id" = "assertion.terraform_organization_id"
  }

  oidc {
    issuer_uri = var.oidc_issuer_uri
  }

  attribute_condition = "assertion.terraform_workspace_id == '${var.tfe_workspace_id}'"
}

resource "google_service_account_iam_member" "tfe_oidc_impersonation" {
  service_account_id = google_service_account.bootstrap.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.tfe_pool.workload_identity_pool_id}/attribute.terraform_workspace_id/${var.tfe_workspace_id}"
}

output "bootstrap_project_id" {
  value       = local.target_project_id
  description = "Bootstrap project ID where resources are created"
}

output "bootstrap_service_account_email" {
  value       = google_service_account.bootstrap.email
  description = "Email of the bootstrap service account"
}

output "tfe_workload_identity_provider" {
  value       = google_iam_workload_identity_pool_provider.tfe_provider.name
  description = "Full Workload Identity Provider name for Terraform workspace OIDC"
}

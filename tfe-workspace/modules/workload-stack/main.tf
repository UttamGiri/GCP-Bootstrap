# Do not add sibling modules here — add ephemeral resources inside workload-resources/.
# This depends_on is the only destroy-order guard needed.

module "workspace_identity" {
  source = "../workspace-identity"

  project_id   = var.project_id
  workspace_id = var.workspace_id

  service_account_id           = "gcp-tfe-workspace-sa-${var.resource_suffix}"
  service_account_display_name = "GCP TFE Workspace Service Account"

  service_account_roles = [
    "roles/viewer",
    "roles/storage.admin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountTokenCreator",
    "roles/iam.workloadIdentityPoolAdmin",
  ]

  workload_identity_pool_id               = "tfe-workspace-pool-${var.resource_suffix}"
  workload_identity_pool_display_name     = "GCP TFE Workspace"
  workload_identity_provider_id           = "tfe-workspace-provider-${var.resource_suffix}"
  workload_identity_provider_display_name = "GCP TFE Provider"
}

module "workload_resources" {
  source = "../workload-resources"

  project_id      = var.project_id
  resource_suffix = var.resource_suffix
  bucket_suffix   = var.bucket_suffix
  environment     = var.environment

  depends_on = [module.workspace_identity]
}

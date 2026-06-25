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
  project = "bootstrap-prj-500323"
}

module "bootstrap" {
  source = "../../modules/bootstrap"

  project_id     = "bootstrap-prj-500323"
  create_project = false
  project_name   = "Bootstrap Dev Project"

  bootstrap_service_account_name         = "bs-tfe-sa"
  bootstrap_service_account_display_name = "Bootstrap Terraform Enterprise Service Account"

  oidc_issuer_uri = "https://app.terraform.io"

  tfe_workspace_id = "ws-D2eEpkBSCE55LBq9"
  additional_tfe_workspace_ids = [
    "ws-2UNjJ7BXhV5ZnrAG"
  ]

  workload_identity_pool_id               = "tfe-pool-dev-3"
  workload_identity_pool_display_name     = "TFE Pool Dev"
  workload_identity_provider_id           = "tfe-provider-dev-3"
  workload_identity_provider_display_name = "TFE OIDC Provider Dev"

  project_labels = {
    environment = "dev"
    owner       = "platform"
  }

  required_services = [
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
  ]

  bootstrap_roles = [
    "roles/viewer",
    "roles/storage.admin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountTokenCreator",
  ]
}

moved {
  from = google_project.bootstrap
  to   = module.bootstrap.google_project.bootstrap
}

moved {
  from = google_project_service.required
  to   = module.bootstrap.google_project_service.required
}

moved {
  from = google_service_account.bootstrap
  to   = module.bootstrap.google_service_account.bootstrap
}

moved {
  from = google_project_iam_member.bootstrap_roles
  to   = module.bootstrap.google_project_iam_member.bootstrap_roles
}

moved {
  from = google_iam_workload_identity_pool.tfe_pool
  to   = module.bootstrap.google_iam_workload_identity_pool.tfe_pool
}

moved {
  from = google_iam_workload_identity_pool_provider.tfe_provider
  to   = module.bootstrap.google_iam_workload_identity_pool_provider.tfe_provider
}

moved {
  from = google_service_account_iam_member.tfe_oidc_impersonation
  to   = module.bootstrap.google_service_account_iam_member.tfe_oidc_impersonation["ws-D2eEpkBSCE55LBq9"]
}

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = "bootstrap-prod-prj"
}

module "bootstrap" {
  source = "../../modules/bootstrap"

  project_id     = "bootstrap-prod-prj"
  create_project = false
  project_name   = "Bootstrap Prod Project"

  bootstrap_service_account_name         = "bs-tfe-sa"
  bootstrap_service_account_display_name = "Bootstrap Terraform Enterprise Service Account"

  oidc_issuer_uri = "https://app.terraform.io"

  tfe_workspace_id             = "ws-D2eEpkBSCE55LBq9"
  additional_tfe_workspace_ids = []

  workload_identity_pool_id               = "tfe-pool-prod-2"
  workload_identity_pool_display_name     = "TFE Pool Prod"
  workload_identity_provider_id           = "tfe-provider-prod-2"
  workload_identity_provider_display_name = "TFE OIDC Provider Prod"

  project_labels = {
    environment = "prod"
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

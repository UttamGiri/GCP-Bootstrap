terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

data "terraform_remote_state" "bootstrap" {
  backend = "remote"

  config = {
    organization = "vaflt-org"

    workspaces = {
      name = "bootstrap-prod"
    }
  }
}

locals {
  project_id = data.terraform_remote_state.bootstrap.outputs.bootstrap_project_id
}

provider "google" {
  project = local.project_id
}

module "workspace_identity" {
  source = "../../modules/workspace-identity"

  project_id   = local.project_id
  workspace_id = "replace-with-tfe-prod-workspace-id"

  service_account_id           = "gcp-tfe-prod-sa"
  service_account_display_name = "GCP TFE Prod Service Account"

  service_account_roles = [
    "roles/viewer",
    "roles/storage.admin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountTokenCreator",
    "roles/iam.workloadIdentityPoolAdmin",
  ]

  workload_identity_pool_id               = "tfe-prod-pool"
  workload_identity_pool_display_name     = "GCP TFE Prod"
  workload_identity_provider_id           = "tfe-prod-provider"
  workload_identity_provider_display_name = "GCP TFE Prod"
}

module "storage_buckets" {
  source = "../../modules/gcs-buckets"

  project_id = local.project_id

  common_labels = {
    environment = "prod"
    managed_by  = "terraform"
    workspace   = "tfe-prod"
  }

  buckets = {
    workload = {
      name               = "bootstrap-prj-501802-tfe-prod-workload"
      location           = "US"
      force_destroy      = false
      versioning_enabled = true
    }
  }
}

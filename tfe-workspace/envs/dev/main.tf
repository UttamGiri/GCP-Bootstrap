terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

data "terraform_remote_state" "bootstrap" {
  backend = "remote"

  config = {
    organization = "vaflt-org"

    workspaces = {
      name = "GCP-Bootstrap"
    }
  }
}

locals {
  project_id                      = data.terraform_remote_state.bootstrap.outputs.bootstrap_project_id
  bootstrap_service_account_email = data.terraform_remote_state.bootstrap.outputs.bootstrap_service_account_email
  tfe_workload_identity_provider  = data.terraform_remote_state.bootstrap.outputs.tfe_workload_identity_provider
}

provider "google" {
  project = local.project_id
}

module "workspace_identity" {
  source = "../../modules/workspace-identity"

  project_id   = local.project_id
  workspace_id = "ws-2UNjJ7BXhV5ZnrAG"

  service_account_id           = "gcp-tfe-workspace-sa"
  service_account_display_name = "GCP TFE Workspace Service Account"

  service_account_roles = [
    "roles/viewer",
    "roles/storage.admin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountTokenCreator",
    "roles/iam.workloadIdentityPoolAdmin",
  ]

  workload_identity_pool_id              = "tfe-workspace-pool"
  workload_identity_pool_display_name    = "GCP TFE Workspace"
  workload_identity_provider_id          = "tfe-workspace-provider"
  workload_identity_provider_display_name = "GCP TFE Provider"
}

module "storage_buckets" {
  source = "../../modules/gcs-buckets"

  project_id = local.project_id

  common_labels = {
    environment = "dev"
    managed_by  = "terraform"
    workspace   = "tfe-dev"
  }

  buckets = {
    workload = {
      name               = "bootstrap-prj-500323-tfe-dev-workload-2"
      location           = "US"
      force_destroy      = true
      versioning_enabled = true
    }
  }
}

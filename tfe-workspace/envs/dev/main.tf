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

module "storage_buckets" {
  source = "../../modules/gcs-buckets"

  project_id = local.project_id

  common_labels = {
    environment = "dev"
    managed_by  = "terraform"
    workspace   = "tfe-dev"
  }

  buckets = {
    state = {
      name               = "bootstrap-prj-500323-tfe-dev-state"
      location           = "US"
      force_destroy      = false
      versioning_enabled = true
    }
  }
}

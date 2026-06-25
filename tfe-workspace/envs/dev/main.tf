terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

locals {
  project_id = "bootstrap-prj-500323"
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

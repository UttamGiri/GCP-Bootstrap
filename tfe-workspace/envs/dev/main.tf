terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source = "hashicorp/google"
      # ~> 5.0 allows any 5.x (>= 5.0, < 6.0). "terraform init -upgrade" resolves
      # to the latest matching release; .terraform.lock.hcl pins that exact version
      # so TFE and local runs use the same provider until you upgrade the lock again.
      version = "~> 5.0"
    }
  }
}

data "terraform_remote_state" "bootstrap" {
  backend = "remote"

  config = {
    organization = "vaflt-org"

    workspaces = {
      name = "GCP-Vaflt-Bootstrap"
    }
  }
}

locals {
  project_id = data.terraform_remote_state.bootstrap.outputs.bootstrap_project_id
  # Bumped by bump-tfe-auth after failed apply/destroy cycle (was 8 → 9).
  resource_suffix = "17"
  # Fixed — never bumped; bucket names are reusable after destroy (soft delete disabled).
  bucket_suffix = "1"
}

provider "google" {
  project = local.project_id
}

module "workload" {
  source = "../../modules/workload-stack"

  project_id      = local.project_id
  workspace_id    = "ws-4V97YqCc8p3GH3U9" # GCP-vaflt-tfe-workspace
  resource_suffix = local.resource_suffix
  bucket_suffix   = local.bucket_suffix
  environment     = "dev"
}

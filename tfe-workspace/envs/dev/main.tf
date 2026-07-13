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
  project_id = data.terraform_remote_state.bootstrap.outputs.bootstrap_project_id
  # Incremented +1 by .github/workflows/bump-tfe-auth.yml after each destroy (SA/WIF only).
  resource_suffix = "9"
  # Fixed — never bumped; bucket names are reusable after destroy (soft delete disabled).
  bucket_suffix = "6"
}

provider "google" {
  project = local.project_id
}

module "workload" {
  source = "../../modules/workload-stack"

  project_id      = local.project_id
  workspace_id    = "ws-2UNjJ7BXhV5ZnrAG"
  resource_suffix = local.resource_suffix
  bucket_suffix   = local.bucket_suffix
  environment     = "dev"
}

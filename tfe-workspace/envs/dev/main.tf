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
  # Incremented +1 by .github/workflows/tfe-copy-bootstrap-auth.yml after each destroy.
  resource_suffix = "5"
}

provider "google" {
  project = local.project_id
}

module "workload" {
  source = "../../modules/workload-stack"

  project_id      = local.project_id
  workspace_id    = "ws-2UNjJ7BXhV5ZnrAG"
  resource_suffix = local.resource_suffix
  environment     = "dev"
}

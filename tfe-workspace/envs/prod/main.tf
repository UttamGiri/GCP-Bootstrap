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
      name = "bootstrap-prod"
    }
  }
}

locals {
  org_id              = "327947404107"
  billing_account     = "01BC6F-241F9A-8762DE"
  provider_project_id = data.terraform_remote_state.bootstrap.outputs.bootstrap_project_id
  workload_projects   = {}
}

provider "google" {
  project = local.provider_project_id
}

module "platform" {
  source = "../../modules/platform-layout"

  org_id            = local.org_id
  billing_account   = local.billing_account
  workload_projects = local.workload_projects
}

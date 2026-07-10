terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Bootstrap remote state: read-only. Platform never writes to bootstrap project.
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
  org_id          = "327947404107"
  billing_account = "01BC6F-241F9A-8762DE"

  # Provider default project — auth context only (bootstrap SA). Platform resources
  # are created in folders / team projects / shared-network host projects below.
  provider_project_id = data.terraform_remote_state.bootstrap.outputs.bootstrap_project_id

  # Lower envs: one subnet per team (map key = subnet name). Each service project gets
  # networkUser only on its subnet — shared VPC, but teams cannot use each other's subnets.
  workload_projects = {
    workload-a-dev = {
      folder_key         = "dev"
      shared_network_key = "dev"
      project_id         = "workload-a-dev-prj"
      project_name       = "Workload A Dev"
      tfe_workspace_id   = "ws-REPLACE-WORKLOAD-A-DEV" # set when team A TFE workspace exists
      service_account_id = "tfe-workload-a-dev-sa"
      subnet_cidr        = "10.10.0.0/24" # subnet name: workload-a-dev
    }
    workload-b-dev = {
      folder_key         = "dev"
      shared_network_key = "dev"
      project_id         = "workload-b-dev-prj"
      project_name       = "Workload B Dev"
      tfe_workspace_id   = "ws-REPLACE-WORKLOAD-B-DEV" # set when team B TFE workspace exists
      service_account_id = "tfe-workload-b-dev-sa"
      subnet_cidr        = "10.10.1.0/24" # subnet name: workload-b-dev
    }
  }
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

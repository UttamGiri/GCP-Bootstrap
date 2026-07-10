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
      subnet_cidr        = "10.10.0.0/24"

      # uttam.giri@vaflt.com — workload A only (no access on workload-b-dev)
      human_users = {
        "uttam.giri@vaflt.com" = [
          "roles/storage.admin",
          "roles/viewer",
        ]
      }

      # GCS object storage — team A project only
      storage_buckets = {
        workload-a-dev-prj-object-storage = {
          location = "US"
        }
      }
    }
    workload-b-dev = {
      folder_key         = "dev"
      shared_network_key = "dev"
      project_id         = "workload-b-dev-prj"
      project_name       = "Workload B Dev"
      subnet_cidr        = "10.10.1.0/24"
      # no human_users, no storage_buckets — isolated from team A
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

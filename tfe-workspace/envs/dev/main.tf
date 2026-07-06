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
      force_destroy      = false
      versioning_enabled = true
    }
  }
}

# Runs last on a successful destroy apply (depends_on → destroyed after all workload resources).
# If destroy errors partway, this resource is not destroyed and the hook does not run.
# Set TF_VAR_github_dispatch_token in GCP-tfe-workspace (sensitive env var).
resource "terraform_data" "notify_github_after_successful_destroy" {
  count = var.github_dispatch_token != "" ? 1 : 0

  depends_on = [
    module.workspace_identity,
    module.storage_buckets,
  ]

  input = {
    token = var.github_dispatch_token
    repo  = var.github_repo
  }

  provisioner "local-exec" {
    when = destroy

    environment = {
      GITHUB_DISPATCH_TOKEN = self.input.token
      GITHUB_REPO           = self.input.repo
    }

    command = <<-EOT
      set -e
      if curl -fsS -X POST \
        -H "Authorization: Bearer $GITHUB_DISPATCH_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/$GITHUB_REPO/dispatches" \
        -d '{"event_type":"tfe-workload-destroyed","client_payload":{"run_id":"destroy-complete"}}'; then
        echo "Triggered GitHub Action to copy GCP-Bootstrap auth to GCP-tfe-workspace."
      else
        echo "WARNING: destroy succeeded but repository_dispatch failed — reset auth manually or re-run the GitHub Action."
      fi
    EOT
  }
}

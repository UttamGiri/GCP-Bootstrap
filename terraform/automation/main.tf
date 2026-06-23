terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
}

locals {
  bootstrap_service_account_email = "${var.bootstrap_service_account_name}@${var.project_id}.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "bootstrap_roles" {
  for_each = toset(var.bootstrap_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${local.bootstrap_service_account_email}"
}

output "bootstrap_service_account_email" {
  value       = local.bootstrap_service_account_email
  description = "Bootstrap service account email whose roles are managed by automation"
}

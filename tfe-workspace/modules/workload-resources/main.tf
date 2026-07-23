terraform {
  required_providers {
    google = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

module "storage_buckets" {
  source = "../gcs-buckets"

  project_id = var.project_id

  common_labels = {
    environment = var.environment
    managed_by  = "terraform"
    workspace   = "tfe-${var.environment}"
  }

  buckets = {
    workload = {
      name               = "bucket-test8-${var.project_id}-tfe-${var.environment}-workload-${var.bucket_suffix}"
      location           = "US"
      force_destroy      = true
      versioning_enabled = true
    }
  }
}

# Add buckets, VPC, compute, etc. here — no depends_on on identity needed.

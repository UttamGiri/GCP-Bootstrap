variable "project_id" {
  type = string
}

variable "resource_suffix" {
  type = string
}

variable "environment" {
  type = string
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
      name               = "${var.project_id}-tfe-${var.environment}-workload-${var.resource_suffix}"
      location           = "US"
      force_destroy      = true
      versioning_enabled = true
    }
  }
}

# Add buckets, VPC, compute, etc. here — no depends_on on identity needed.

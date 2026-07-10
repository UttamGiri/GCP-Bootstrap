variable "folder_id" {
  description = "Full folder resource name (folders/NUMERIC_ID)"
  type        = string
}

variable "allowed_regions" {
  description = "Allowed GCP resource locations for projects under this folder (org policy gcp.resourceLocations)"
  type        = list(string)
  default     = ["in:us-locations"]
}

variable "disable_service_account_key_creation" {
  description = "Enforce iam.disableServiceAccountKeyCreation on this folder"
  type        = bool
  default     = true
}

variable "require_uniform_bucket_level_access" {
  description = "Enforce storage.uniformBucketLevelAccess on this folder"
  type        = bool
  default     = true
}

resource "google_org_policy_policy" "resource_locations" {
  name   = "${var.folder_id}/policies/gcp.resourceLocations"
  parent = var.folder_id

  spec {
    rules {
      values {
        allowed_values = var.allowed_regions
      }
    }
  }
}

resource "google_org_policy_policy" "disable_sa_keys" {
  count = var.disable_service_account_key_creation ? 1 : 0

  name   = "${var.folder_id}/policies/iam.disableServiceAccountKeyCreation"
  parent = var.folder_id

  spec {
    rules {
      enforce = true
    }
  }
}

resource "google_org_policy_policy" "uniform_bucket_access" {
  count = var.require_uniform_bucket_level_access ? 1 : 0

  name   = "${var.folder_id}/policies/storage.uniformBucketLevelAccess"
  parent = var.folder_id

  spec {
    rules {
      enforce = true
    }
  }
}

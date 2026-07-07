variable "project_id" {
  description = "GCP project ID where buckets are created"
  type        = string
}

variable "common_labels" {
  description = "Common labels applied to all buckets"
  type        = map(string)
}

variable "buckets" {
  description = "GCS buckets managed by this environment"
  type = map(object({
    name               = string
    location           = string
    force_destroy      = bool
    versioning_enabled = bool
    labels             = optional(map(string), {})
  }))
}

resource "google_storage_bucket" "buckets" {
  for_each = var.buckets

  project                     = var.project_id
  name                        = each.value.name
  location                    = each.value.location
  uniform_bucket_level_access = true
  force_destroy               = each.value.force_destroy
  labels                      = merge(var.common_labels, each.value.labels)

  soft_delete_policy {
    retention_duration_seconds = 0
  }

  versioning {
    enabled = each.value.versioning_enabled
  }
}

output "bucket_names" {
  description = "Created GCS bucket names"
  value       = { for key, bucket in google_storage_bucket.buckets : key => bucket.name }
}

output "bucket_urls" {
  description = "Created GCS bucket URLs"
  value       = { for key, bucket in google_storage_bucket.buckets : key => bucket.url }
}

variable "org_id" {
  description = "GCP organization ID (numeric), e.g. 327947404107 for vaflt.com"
  type        = string
}

variable "folders" {
  description = "Top-level folders under the org. Key = logical name for outputs; value = display name in GCP console."
  type        = map(string)
  default = {
    platform = "Platform"
    dev      = "Dev"
    prod     = "Prod"
  }
}

resource "google_folder" "folders" {
  for_each = var.folders

  display_name = each.value
  parent       = "organizations/${var.org_id}"
}

output "folder_names" {
  description = "Full folder resource names (folders/NUMERIC_ID) keyed by logical name"
  value       = { for key, folder in google_folder.folders : key => folder.name }
}

output "folder_ids" {
  description = "Numeric folder IDs keyed by logical name"
  value       = { for key, folder in google_folder.folders : key => folder.folder_id }
}

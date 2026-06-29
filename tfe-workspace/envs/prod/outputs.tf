output "bucket_names" {
  description = "Created GCS bucket names"
  value       = module.storage_buckets.bucket_names
}

output "bucket_urls" {
  description = "Created GCS bucket URLs"
  value       = module.storage_buckets.bucket_urls
}

output "workspace_service_account_email" {
  description = "Service account for consecutive tfe-prod runs"
  value       = module.workspace_identity.service_account_email
}

output "workspace_workload_identity_provider" {
  description = "WIF provider for consecutive tfe-prod runs"
  value       = module.workspace_identity.workload_identity_provider
}

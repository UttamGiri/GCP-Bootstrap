output "bucket_names" {
  description = "Created GCS bucket names"
  value       = module.storage_buckets.bucket_names
}

output "bucket_urls" {
  description = "Created GCS bucket URLs"
  value       = module.storage_buckets.bucket_urls
}

output "bootstrap_project_id" {
  description = "Bootstrap project ID read from bootstrap workspace state"
  value       = local.bootstrap_project_id
}

output "bootstrap_service_account_email" {
  description = "Bootstrap service account email read from bootstrap workspace state"
  value       = local.bootstrap_service_account_email
}

output "tfe_workload_identity_provider" {
  description = "WIF provider read from bootstrap workspace state"
  value       = local.tfe_workload_identity_provider
}

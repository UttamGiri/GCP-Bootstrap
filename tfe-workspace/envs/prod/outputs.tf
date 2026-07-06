output "TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL" {
  description = "Workload SA email — copy to workspace env TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL after apply"
  value       = module.workspace_identity.service_account_email
}

output "TFC_GCP_WORKLOAD_PROVIDER_NAME" {
  description = "Workload WIF provider — copy to workspace env TFC_GCP_WORKLOAD_PROVIDER_NAME after apply"
  value       = module.workspace_identity.workload_identity_provider
}

output "bucket_names" {
  description = "Created GCS bucket names"
  value       = module.storage_buckets.bucket_names
}

output "bucket_urls" {
  description = "Created GCS bucket URLs"
  value       = module.storage_buckets.bucket_urls
}

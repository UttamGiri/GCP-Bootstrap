output "TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL" {
  description = "Workload SA email — set as workspace env TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL for self-run auth"
  value       = module.workspace_identity.service_account_email
}

output "TFC_GCP_WORKLOAD_PROVIDER_NAME" {
  description = "Workload WIF provider — set as workspace env TFC_GCP_WORKLOAD_PROVIDER_NAME for self-run auth"
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

output "workspace_service_account_email" {
  description = "Alias of TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL"
  value       = module.workspace_identity.service_account_email
}

output "workspace_workload_identity_provider" {
  description = "Alias of TFC_GCP_WORKLOAD_PROVIDER_NAME"
  value       = module.workspace_identity.workload_identity_provider
}

output "TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL" {
  value = module.workspace_identity.service_account_email
}

output "TFC_GCP_WORKLOAD_PROVIDER_NAME" {
  value = module.workspace_identity.workload_identity_provider
}

output "bucket_names" {
  value = module.workload_resources.bucket_names
}

output "bucket_urls" {
  value = module.workload_resources.bucket_urls
}

# First run uses bootstrap env vars (bs-tfe-sa). After apply, run GitHub Action
# "TFE Sync Workload Auth" (manually or via TFE notification webhook) to copy
# these outputs into workspace env vars for self-run auth.
#
#   TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL
#     e.g. gcp-tfe-workspace-sa@bootstrap-prj-500323.iam.gserviceaccount.com
#   TFC_GCP_WORKLOAD_PROVIDER_NAME
#     e.g. projects/1071237146360/locations/global/workloadIdentityPools/tfe-workspace-pool/providers/tfe-workspace-provider

output "TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL" {
  description = "Default provider instance"
  value       = module.workspace_identity.service_account_email
}

output "TFC_GCP_WORKLOAD_PROVIDER_NAME" {
  description = "Default provider instance"
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

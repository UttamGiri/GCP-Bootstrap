# First run uses bootstrap env vars (bs-tfe-sa). After apply, run GitHub Action
# "TFE Sync Workload Auth" to copy these outputs into workspace env vars.

output "TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL" {
  description = "Workload service account for TFE GCP auth"
  value       = module.workload.TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL
}

output "TFC_GCP_WORKLOAD_PROVIDER_NAME" {
  description = "Workload WIF provider for TFE GCP auth"
  value       = module.workload.TFC_GCP_WORKLOAD_PROVIDER_NAME
}

output "bucket_names" {
  description = "Created GCS bucket names"
  value       = module.workload.bucket_names
}

output "bucket_urls" {
  description = "Created GCS bucket URLs"
  value       = module.workload.bucket_urls
}

output "vertex_psc" {
  description = "Private Service Connect path to Vertex AI; null when enable_vertex_psc is false"
  value       = module.workload.vertex_psc
}

# terraform output -raw / -json to write a key file, e.g.
#   terraform output -json vertex_psc_client_key_json | jq -r '.host' > sa.json
output "vertex_psc_client_key_json" {
  description = "Service account key JSON per project for JWT auth; empty unless create_sa_key is true"
  sensitive   = true
  value       = module.workload.vertex_psc_client_key_json
}

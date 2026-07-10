output "project_id" {
  description = "GCP project ID for this workload team"
  value       = google_project.workload.project_id
}

output "TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL" {
  description = "Team service account email — null until workspace-identity is enabled"
  value       = null
  # value = module.identity.service_account_email
}

output "TFC_GCP_WORKLOAD_PROVIDER_NAME" {
  description = "Team WIF provider — null until workspace-identity is enabled"
  value       = null
  # value = module.identity.workload_identity_provider
}

output "tfe_workspace_id" {
  description = "TFE workspace ID for WIF binding when identity module is enabled"
  value       = var.tfe_workspace_id
}

output "shared_subnet_self_links" {
  description = "Subnets this service project may use (networkUser granted per subnet only)"
  value       = var.shared_subnet_self_links
}

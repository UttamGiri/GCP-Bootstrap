output "project_id" {
  description = "GCP project ID for this workload team"
  value       = google_project.workload.project_id
}

output "TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL" {
  description = "Team service account email — null until workspace-identity is enabled"
  value       = var.enable_identity ? module.identity[0].service_account_email : null
}

output "TFC_GCP_WORKLOAD_PROVIDER_NAME" {
  description = "Team WIF provider — null until workspace-identity is enabled"
  value       = var.enable_identity ? module.identity[0].workload_identity_provider : null
}

output "tfe_workspace_id" {
  description = "TFE workspace ID for WIF binding when identity module is enabled"
  value       = var.tfe_workspace_id
}

output "shared_subnet_self_links" {
  description = "Subnets this service project may use (networkUser granted per subnet only)"
  value       = var.shared_subnet_self_links
}

output "storage_bucket_names" {
  description = "GCS bucket names created in this team project"
  value       = [for bucket in google_storage_bucket.team : bucket.name]
}

output "human_users" {
  description = "Human users granted access on this team project only"
  value       = keys(var.human_users)
}

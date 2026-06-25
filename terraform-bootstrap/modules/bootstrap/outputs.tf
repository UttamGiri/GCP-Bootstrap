output "bootstrap_project_id" {
  value       = local.target_project_id
  description = "Bootstrap project ID where resources are created"
}

output "bootstrap_service_account_email" {
  value       = google_service_account.bootstrap.email
  description = "Email of the bootstrap service account"
}

output "tfe_workload_identity_provider" {
  value       = google_iam_workload_identity_pool_provider.tfe_provider.name
  description = "Full Workload Identity Provider name for Terraform workspace OIDC"
}

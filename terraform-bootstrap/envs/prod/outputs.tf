output "bootstrap_project_id" {
  value       = module.bootstrap.bootstrap_project_id
  description = "Bootstrap project ID where resources are created"
}

output "TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL" {
  description = "Default provider instance"
  value       = module.bootstrap.bootstrap_service_account_email
}

output "TFC_GCP_WORKLOAD_PROVIDER_NAME" {
  description = "Default provider instance"
  value       = module.bootstrap.tfe_workload_identity_provider
}

# Output-only marker used to trigger a harmless bootstrap workspace apply.
output "bootstrap_layout" {
  value       = "terraform-bootstrap/envs/prod"
  description = "Bootstrap environment root used by this workspace"
}

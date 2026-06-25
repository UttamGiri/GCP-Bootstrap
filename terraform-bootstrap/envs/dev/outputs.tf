output "bootstrap_project_id" {
  value       = module.bootstrap.bootstrap_project_id
  description = "Bootstrap project ID where resources are created"
}

output "bootstrap_service_account_email" {
  value       = module.bootstrap.bootstrap_service_account_email
  description = "Email of the bootstrap service account"
}

output "tfe_workload_identity_provider" {
  value       = module.bootstrap.tfe_workload_identity_provider
  description = "Full Workload Identity Provider name for Terraform workspace OIDC"
}

# Output-only marker used to trigger a harmless bootstrap workspace apply.
output "bootstrap_layout" {
  value       = "terraform-bootstrap/envs/dev"
  description = "Bootstrap environment root used by this workspace"
}

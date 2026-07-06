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

output "tfe_github_bridge_webhook_url" {
  value       = try(module.tfe_github_bridge[0].webhook_url, null)
  description = "TFE notification Webhook URL for GCP-tfe-workspace (Settings -> Notifications)"
}

# Output-only marker used to trigger a harmless bootstrap workspace apply.
# output "bootstrap_layout" {
#   value       = "terraform-bootstrap/envs/dev"
#   description = "Bootstrap environment root used by this workspace"
# }

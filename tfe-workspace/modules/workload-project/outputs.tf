output "project_id" {
  value = data.google_project.this.project_id
}

output "project_number" {
  value = data.google_project.this.number
}

output "deployer_service_account_email" {
  description = "Impersonate this SA to helm into the tenant namespace"
  value       = google_service_account.deployer.email
}

output "deployer_service_account_name" {
  value = google_service_account.deployer.name
}

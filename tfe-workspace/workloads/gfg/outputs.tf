output "workload_id" {
  value = module.project.workload_id
}

output "description" {
  value = module.project.description
}

output "project_id" {
  value = module.project.project_id
}

output "deployer_service_account_email" {
  value = module.project.deployer_service_account_email
}

output "gemini_ops_service_account_email" {
  value = google_service_account.gemini_ops.email
}

output "rag_staging_bucket" {
  value = {
    name = module.rag_staging_bucket.bucket_names["rag_staging"]
    url  = module.rag_staging_bucket.bucket_urls["rag_staging"]
  }
}

output "shared_networks" {
  description = "Shared VPC host project and subnets per environment (dev, prod)"
  value       = module.platform.shared_networks
}

output "org_folder_names" {
  description = "GCP folder resource names (platform, dev, prod)"
  value       = module.platform.folder_names
}

output "org_folder_ids" {
  description = "Numeric GCP folder IDs (platform, dev, prod)"
  value       = module.platform.folder_ids
}

output "workload_projects" {
  description = "Per-team handoff: project_id, SA email, WIF provider"
  value       = module.platform.workload_projects
}

output "bucket_names" {
  value = module.storage_buckets.bucket_names
}

output "bucket_urls" {
  value = module.storage_buckets.bucket_urls
}

output "vertex_psc" {
  value = try({
    host_project_id           = module.vertex_psc[0].host_project_id
    endpoint_ip               = module.vertex_psc[0].psc_endpoint_ip
    endpoint_name             = module.vertex_psc[0].psc_endpoint_name
    auto_dns_name             = module.vertex_psc[0].psc_auto_dns_name
    network_name              = module.vertex_psc[0].network_name
    subnets                   = module.vertex_psc[0].subnets
    dns_zone_name             = module.vertex_psc[0].dns_zone_name
    dns_inbound_forwarder_ips = module.vertex_psc[0].dns_inbound_forwarder_ips
    service_projects          = module.vertex_psc[0].service_projects
    host_client_sa            = module.vertex_psc[0].host_client_service_account_email
    cloud_router_name         = module.vertex_psc[0].cloud_router_name
    cloud_router_region       = module.vertex_psc[0].cloud_router_region
    allowed_api_hosts         = module.vertex_psc[0].allowed_api_hosts
    allowed_models            = module.vertex_psc[0].allowed_models
    aws_wif                   = module.vertex_psc[0].aws_wif
  }, null)
}

# Kept out of the object above so that output stays non-sensitive and readable.
output "vertex_psc_client_key_json" {
  sensitive = true
  value     = try(module.vertex_psc[0].client_key_json, {})
}

output "gfg" {
  value = try({
    workload_id                      = module.gfg[0].workload_id
    description                      = module.gfg[0].description
    project_id                       = module.gfg[0].project_id
    deployer_service_account_email   = module.gfg[0].deployer_service_account_email
    gemini_ops_service_account_email = module.gfg[0].gemini_ops_service_account_email
    rag_staging_bucket               = module.gfg[0].rag_staging_bucket
  }, null)
}

output "workload_dev" {
  value = try({
    workload_id                    = module.workload_dev[0].workload_id
    description                    = module.workload_dev[0].description
    project_id                     = module.workload_dev[0].project_id
    deployer_service_account_email = module.workload_dev[0].deployer_service_account_email
  }, null)
}

# Separate from the summary object so the root kubernetes provider can read these
# without creating a cycle through namespace/RBAC resources.
output "shared_gke_cluster_endpoint" {
  value     = try(module.shared_gke[0].cluster_endpoint, null)
  sensitive = true
}

output "shared_gke_cluster_ca_certificate" {
  value     = try(module.shared_gke[0].cluster_ca_certificate, null)
  sensitive = true
}

output "shared_gke" {
  value = try({
    cluster_name            = module.shared_gke[0].cluster_name
    location                = module.shared_gke[0].location
    namespace               = module.shared_gke[0].namespace
    get_credentials_command = module.shared_gke[0].get_credentials_command
  }, null)
}

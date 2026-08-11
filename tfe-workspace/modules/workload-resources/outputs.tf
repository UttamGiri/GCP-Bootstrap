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
  }, null)
}

# Kept out of the object above so that output stays non-sensitive and readable.
output "vertex_psc_client_key_json" {
  sensitive = true
  value     = try(module.vertex_psc[0].client_key_json, {})
}

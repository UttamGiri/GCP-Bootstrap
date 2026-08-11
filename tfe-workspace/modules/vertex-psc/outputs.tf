output "host_project_id" {
  description = "Shared VPC host project owning the endpoint, DNS, and hybrid router"
  value       = var.host_project_id
}

output "psc_endpoint_ip" {
  description = "The one internal IP that googleapis.com resolves to across the whole Shared VPC"
  value       = google_compute_global_address.psc.address
}

output "psc_endpoint_name" {
  description = "Name of the PSC forwarding rule"
  value       = google_compute_global_forwarding_rule.psc.name
}

output "psc_auto_dns_name" {
  description = "Service Directory hostname created alongside the endpoint, usable by clients that accept a custom API host"
  value       = "${google_compute_global_forwarding_rule.psc.name}-${var.psc_target}.p.googleapis.com"
}

output "network_name" {
  description = "Shared VPC holding the PSC endpoint"
  value       = google_compute_network.vpc.name
}

output "network_self_link" {
  description = "Self link service projects reference when creating resources on the Shared VPC"
  value       = google_compute_network.vpc.self_link
}

output "subnets" {
  description = "Shared subnets keyed by name, with the self links service projects attach to"
  value = {
    for key, subnet in google_compute_subnetwork.clients : key => {
      name      = subnet.name
      region    = subnet.region
      cidr      = subnet.ip_cidr_range
      self_link = subnet.self_link
    }
  }
}

output "dns_zone_name" {
  description = "Private zone overriding googleapis.com for every project in the Shared VPC"
  value       = google_dns_managed_zone.googleapis.name
}

output "service_projects" {
  description = "Attached service projects with their client service account"
  value = {
    for key, sp in var.service_projects : key => {
      project_id             = sp.project_id
      project_number         = data.google_project.service[key].number
      client_service_account = try(google_service_account.client[key].email, "")
    }
  }
}

output "host_client_service_account_email" {
  description = "Host-project service account with roles/aiplatform.user"
  value       = google_service_account.host_client.email
}

output "allowed_api_hosts" {
  description = "googleapis.com hostnames that resolve to the endpoint. Anything else under googleapis.com does not resolve from this VPC."
  value       = var.allow_all_google_apis ? ["*.googleapis.com"] : sort(tolist(local.allowed_api_hosts))
}

output "allowed_models" {
  description = "Models callers may use, and whether that list is actually enforced by org policy"
  value = {
    models   = var.allowed_models
    enforced = var.enforce_model_allowlist
  }
}

# Feed these to scripts/vertex-sa-token.sh. Empty unless create_sa_key is true.
output "client_key_json" {
  description = "Service account key JSON per project, keyed by 'host' and each service project key"
  sensitive   = true
  value = merge(
    { for k in google_service_account_key.host_client : "host" => base64decode(k.private_key) },
    { for k, v in google_service_account_key.client : k => base64decode(v.private_key) },
  )
}

output "cloud_router_name" {
  description = "Cloud Router advertising the endpoint /32, or empty when enable_hybrid_router is false"
  value       = try(google_compute_router.hybrid[0].name, "")
}

output "cloud_router_region" {
  description = "Region of the hybrid Cloud Router"
  value       = var.enable_hybrid_router ? local.router_region : ""
}

# Point the local/OpenShift conditional forwarder for googleapis.com at these IPs.
output "dns_inbound_forwarder_ips" {
  description = "Cloud DNS inbound forwarder IPs in the Shared VPC, keyed by address name"
  value = merge([
    for region_key, addr_data in data.google_compute_addresses.dns_inbound : {
      for addr in addr_data.addresses : addr.name => addr.address
    }
  ]...)
}

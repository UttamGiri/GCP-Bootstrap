terraform {
  required_providers {
    kubernetes = {
      source                = "hashicorp/kubernetes"
      configuration_aliases = [kubernetes]
    }
  }
}

module "storage_buckets" {
  source = "../gcs-buckets"

  project_id = var.project_id

  common_labels = {
    environment = var.environment
    managed_by  = "terraform"
    workspace   = "tfe-${var.environment}"
  }

  buckets = {
    workload = {
      name               = "bucket-test8-${var.project_id}-tfe-${var.environment}-workload-${var.bucket_suffix}"
      location           = "US"
      force_destroy      = true
      versioning_enabled = true
    }
  }
}

module "vertex_psc" {
  source = "../vertex-psc"

  count = var.vertex_psc.enabled ? 1 : 0

  # Defaults to this project as its own Shared VPC host; point it at a dedicated
  # network project once you have one. Explicit nulls would override child-module
  # defaults, so every optional field is coalesced here.
  host_project_id = coalesce(var.vertex_psc.host_project_id, var.project_id)
  name_suffix     = var.network_suffix
  environment     = var.environment

  subnets = coalesce(var.vertex_psc.subnets, {
    primary = { region = "us-central1", cidr = "10.10.0.0/24" }
  })
  psc_endpoint_ip = coalesce(var.vertex_psc.psc_endpoint_ip, "10.10.100.5")
  psc_target      = coalesce(var.vertex_psc.psc_target, "all-apis")

  enable_shared_vpc_host = coalesce(var.vertex_psc.enable_shared_vpc_host, false)
  service_projects       = coalesce(var.vertex_psc.service_projects, {})

  allowed_api_hosts = coalesce(var.vertex_psc.allowed_api_hosts, [
    "aiplatform.googleapis.com",
    "oauth2.googleapis.com",
    "sts.googleapis.com",
  ])
  allow_all_google_apis = coalesce(var.vertex_psc.allow_all_google_apis, false)
  allowed_models = coalesce(var.vertex_psc.allowed_models, [
    "publishers/google/models/gemini-2.5-pro:predict",
    "publishers/anthropic/models/claude-sonnet-4-5:predict",
    "publishers/anthropic/models/claude-sonnet-5:predict",
  ])
  enforce_model_allowlist = coalesce(var.vertex_psc.enforce_model_allowlist, false)

  enable_hybrid_router = coalesce(var.vertex_psc.enable_hybrid_router, false)
  hybrid_source_ranges = coalesce(var.vertex_psc.hybrid_source_ranges, [])
  create_sa_key        = coalesce(var.vertex_psc.create_sa_key, false)
}

module "workload_dev" {
  source = "../workload-project"

  count = coalesce(var.workload_dev.enabled, false) ? 1 : 0

  create_project  = coalesce(var.workload_dev.create_project, true)
  project_id      = var.workload_dev.project_id
  project_name    = coalesce(var.workload_dev.project_name, "workload-dev")
  org_id          = try(var.workload_dev.org_id, null)
  folder_id       = try(var.workload_dev.folder_id, null)
  billing_account = try(var.workload_dev.billing_account, null)

  host_project_id   = coalesce(var.vertex_psc.host_project_id, var.project_id)
  attach_shared_vpc = coalesce(var.workload_dev.attach_shared_vpc, true)

  deployer_account_id = coalesce(var.workload_dev.deployer_account_id, "gke-deployer")
  impersonators       = coalesce(var.workload_dev.impersonators, [])

  subnet_network_users = var.vertex_psc.enabled ? [
    for k, s in module.vertex_psc[0].subnets : {
      region = s.region
      name   = s.name
    }
  ] : []

  labels = {
    environment = var.environment
  }

  depends_on = [module.vertex_psc]
}

module "shared_gke" {
  source = "../shared-gke"

  count = coalesce(var.shared_gke.enabled, false) && var.vertex_psc.enabled && coalesce(var.workload_dev.enabled, false) ? 1 : 0

  providers = {
    kubernetes = kubernetes
  }

  project_id = coalesce(var.vertex_psc.host_project_id, var.project_id)
  name       = coalesce(var.shared_gke.name, "shared-gke-dev")
  region     = coalesce(var.shared_gke.region, "us-central1")

  network    = module.vertex_psc[0].network_self_link
  subnetwork = module.vertex_psc[0].subnets[coalesce(var.shared_gke.subnet_key, "primary")].self_link

  pods_range_name     = coalesce(var.shared_gke.pods_range_name, "gke-pods")
  services_range_name = coalesce(var.shared_gke.services_range_name, "gke-services")

  enable_private_nodes    = coalesce(var.shared_gke.enable_private_nodes, true)
  enable_private_endpoint = coalesce(var.shared_gke.enable_private_endpoint, false)
  master_ipv4_cidr_block  = coalesce(var.shared_gke.master_ipv4_cidr_block, "172.16.0.0/28")

  node_count   = coalesce(var.shared_gke.node_count, 1)
  machine_type = coalesce(var.shared_gke.machine_type, "e2-medium")
  namespace    = coalesce(var.shared_gke.namespace, "workload-dev")

  deployer_service_account_email = module.workload_dev[0].deployer_service_account_email

  labels = {
    environment = var.environment
  }

  depends_on = [module.workload_dev, module.vertex_psc]
}

# Add buckets, VPC, compute, etc. here — no depends_on on identity needed.

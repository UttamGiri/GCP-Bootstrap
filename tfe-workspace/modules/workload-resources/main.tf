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

# Add buckets, VPC, compute, etc. here — no depends_on on identity needed.

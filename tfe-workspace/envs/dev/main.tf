terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source = "hashicorp/google"
      # ~> 5.0 allows any 5.x (>= 5.0, < 6.0). "terraform init -upgrade" resolves
      # to the latest matching release; .terraform.lock.hcl pins that exact version
      # so TFE and local runs use the same provider until you upgrade the lock again.
      version = "~> 5.0"
    }
  }
}

data "terraform_remote_state" "bootstrap" {
  backend = "remote"

  config = {
    organization = "vaflt-org"

    workspaces = {
      name = "GCP-Vaflt-Bootstrap"
    }
  }
}

locals {
  project_id = data.terraform_remote_state.bootstrap.outputs.bootstrap_project_id
  # Bumped by bump-tfe-auth after failed apply/destroy cycle (was 8 → 9).
  resource_suffix = "17"
  # Fixed — never bumped; bucket names are reusable after destroy (soft delete disabled).
  bucket_suffix = "1"
  # Fixed — never bumped; VPC/subnet/DNS names are reusable immediately after destroy.
  network_suffix = "1"
}

provider "google" {
  project = local.project_id
}

module "workload" {
  source = "../../modules/workload-stack"

  project_id      = local.project_id
  workspace_id    = "ws-4V97YqCc8p3GH3U9" # GCP-vaflt-tfe-workspace
  resource_suffix = local.resource_suffix
  bucket_suffix   = local.bucket_suffix
  network_suffix  = local.network_suffix
  environment     = "dev"

  # Shared VPC with one PSC endpoint for every project — see docs/VERTEX-AI-PSC-ONPREM.md.
  vertex_psc = {
    enabled = true

    # This project is its own host for now; point at a dedicated network project later.
    host_project_id = local.project_id

    # Needs roles/compute.xpnAdmin at the org level. Until an org admin grants it,
    # leave false and run: gcloud compute shared-vpc enable <host project>
    enable_shared_vpc_host = false

    # One global endpoint covers every region, so subnets exist only to give
    # workloads somewhere to run. The endpoint IP sits outside all of them.
    subnets = {
      primary   = { region = "us-central1", cidr = "10.10.0.0/24" }
      secondary = { region = "europe-west1", cidr = "10.10.1.0/24" }
    }
    psc_endpoint_ip = "10.10.100.5"

    # One endpoint fronts every Google API, so DNS is what keeps it scoped to
    # Vertex AI: only these names resolve to it, and anything else under
    # googleapis.com does not resolve at all from this VPC. Regional Vertex hosts
    # for us-central1 and europe-west1 are added automatically.
    #
    # oauth2/sts are only needed for the JWT token exchange. Drop them and use
    # TOKEN_MODE=self-signed for an aiplatform-only allowlist.
    allowed_api_hosts = [
      "aiplatform.googleapis.com",
      "oauth2.googleapis.com",
      "sts.googleapis.com",
    ]

    # The two approved models. Add entries as more are approved.
    allowed_models = [
      "publishers/google/models/gemini-2.5-pro:predict",
      "publishers/anthropic/models/claude-sonnet-5:predict",
    ]

    # Turning this on sets the vertexai.allowedModels org policy on the host and
    # every service project, which restricts ALL Vertex AI use in them, not just
    # calls through this endpoint. Needs roles/orgpolicy.policyAdmin.
    enforce_model_allowlist = true

    # Attach consumer projects here; each shares the one endpoint.
    #   app = {
    #     project_id     = "app-prj-123456"
    #   }
    service_projects = {}

    # Keep false to avoid hybrid connectivity cost. Cloud Router alone is free,
    # but HA VPN tunnels (~$0.05/hr each) are intentionally not in this stack.
    # Local/OpenShift private PSC access needs VPN/Interconnect later; until then
    # test Vertex with a service-account JWT over the public API path.
    enable_hybrid_router = false
    hybrid_source_ranges = []

    # Downloadable SA keys for JWT auth from on-prem or a laptop. The private key
    # lands in TFE state — see the auth section of docs/VERTEX-AI-PSC-ONPREM.md
    # before turning this on.
    create_sa_key = false
  }
}

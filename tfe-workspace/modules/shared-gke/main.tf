terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
    kubernetes = {
      source                = "hashicorp/kubernetes"
      configuration_aliases = [kubernetes]
    }
  }
}

locals {
  labels = merge(var.labels, {
    managed_by = "terraform"
    component  = "shared-gke"
  })
}

resource "google_project_service" "container" {
  project            = var.project_id
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_container_cluster" "this" {
  project  = var.project_id
  name     = var.name
  location = var.region

  networking_mode = "VPC_NATIVE"
  network         = var.network
  subnetwork      = var.subnetwork

  # Remove default node pool; use the explicit pool below.
  remove_default_node_pool = true
  initial_node_count       = 1

  release_channel {
    channel = var.release_channel
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  private_cluster_config {
    enable_private_nodes    = var.enable_private_nodes
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.enable_private_nodes ? var.master_ipv4_cidr_block : null
  }

  # Public control plane (enable_private_endpoint=false) lets laptop kubectl
  # work without VPN. Set true later for private-only API + VPN/Gateway.
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "temp-open-for-dev"
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  resource_labels = local.labels

  deletion_protection = false

  depends_on = [google_project_service.container]
}

resource "google_container_node_pool" "default" {
  project  = var.project_id
  name     = "${var.name}-default"
  location = var.region
  cluster  = google_container_cluster.this.name

  node_count = var.node_count

  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
    labels = local.labels
    tags   = ["shared-gke"]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# Private nodes need NAT to pull images / reach the internet.
resource "google_compute_router" "nat" {
  count = var.enable_private_nodes ? 1 : 0

  project = var.project_id
  name    = "${var.name}-nat-router"
  region  = var.region
  network = var.network
}

resource "google_compute_router_nat" "nat" {
  count = var.enable_private_nodes ? 1 : 0

  project                            = var.project_id
  name                               = "${var.name}-nat"
  router                             = google_compute_router.nat[0].name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# GCP IAM: deployer may authenticate to this cluster.
resource "google_project_iam_member" "deployer_container_developer" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${var.deployer_service_account_email}"
}

# ---------------------------------------------------------------------------
# Tenant namespace + RBAC (only this deployer can manage this namespace)
# ---------------------------------------------------------------------------

resource "kubernetes_namespace_v1" "tenant" {
  metadata {
    name = var.namespace
    labels = merge(local.labels, {
      "tenant" = var.namespace
    })
  }

  depends_on = [google_container_node_pool.default]
}

resource "kubernetes_role_v1" "tenant_edit" {
  metadata {
    name      = "${var.namespace}-edit"
    namespace = kubernetes_namespace_v1.tenant.metadata[0].name
  }

  rule {
    api_groups = ["", "apps", "batch", "extensions", "networking.k8s.io"]
    resources  = ["*"]
    verbs      = ["*"]
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["roles", "rolebindings"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding_v1" "tenant_deployer" {
  metadata {
    name      = "${var.namespace}-deployer"
    namespace = kubernetes_namespace_v1.tenant.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.tenant_edit.metadata[0].name
  }

  subject {
    kind      = "User"
    name      = var.deployer_service_account_email
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_resource_quota_v1" "tenant" {
  metadata {
    name      = "${var.namespace}-quota"
    namespace = kubernetes_namespace_v1.tenant.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = "4"
      "requests.memory" = "8Gi"
      "limits.cpu"      = "8"
      "limits.memory"   = "16Gi"
      pods              = "20"
    }
  }
}

resource "kubernetes_limit_range_v1" "tenant" {
  metadata {
    name      = "${var.namespace}-limits"
    namespace = kubernetes_namespace_v1.tenant.metadata[0].name
  }

  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "500m"
        memory = "512Mi"
      }
      default_request = {
        cpu    = "100m"
        memory = "128Mi"
      }
    }
  }
}

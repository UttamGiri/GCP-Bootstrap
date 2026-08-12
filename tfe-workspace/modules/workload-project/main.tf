locals {
  labels = merge(var.labels, {
    managed_by = "terraform"
    component  = "workload-project"
  })
}

resource "google_project" "this" {
  count = var.create_project ? 1 : 0

  name            = var.project_name
  project_id      = var.project_id
  org_id          = var.folder_id == null ? var.org_id : null
  folder_id       = var.folder_id
  billing_account = var.billing_account
  labels          = local.labels
}

data "google_project" "this" {
  project_id = var.create_project ? google_project.this[0].project_id : var.project_id
}

resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ])

  project            = data.google_project.this.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_shared_vpc_service_project" "attach" {
  count = var.attach_shared_vpc && var.host_project_id != null ? 1 : 0

  host_project    = var.host_project_id
  service_project = data.google_project.this.project_id

  depends_on = [google_project_service.apis]
}

resource "google_service_account" "deployer" {
  project      = data.google_project.this.project_id
  account_id   = var.deployer_account_id
  display_name = "GKE namespace deployer for ${var.project_name}"

  depends_on = [google_project_service.apis]
}

resource "google_service_account_iam_member" "token_creator" {
  for_each = toset(var.impersonators)

  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = each.value
}

# Allow the deployer SA to use Shared VPC subnets in the host project.
resource "google_compute_subnetwork_iam_member" "deployer_network_user" {
  for_each = var.host_project_id != null ? {
    for s in var.subnet_network_users : "${s.region}/${s.name}" => s
  } : {}

  project    = var.host_project_id
  region     = each.value.region
  subnetwork = each.value.name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${google_service_account.deployer.email}"
}

# Google APIs service agent also needs networkUser when creating resources on shared subnets.
resource "google_compute_subnetwork_iam_member" "cloudservices_network_user" {
  for_each = var.attach_shared_vpc && var.host_project_id != null ? {
    for s in var.subnet_network_users : "${s.region}/${s.name}" => s
  } : {}

  project    = var.host_project_id
  region     = each.value.region
  subnetwork = each.value.name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${data.google_project.this.number}@cloudservices.gserviceaccount.com"
}

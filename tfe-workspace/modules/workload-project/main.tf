locals {
  sa_display_name = coalesce(var.service_account_display_name, "TFE SA for ${var.project_id}")

  required_services = distinct(concat(
    var.required_services,
    length(var.storage_buckets) > 0 ? ["storage.googleapis.com"] : [],
    var.enable_identity ? ["iam.googleapis.com", "iamcredentials.googleapis.com"] : [],
  ))

  human_user_bindings = {
    for binding in flatten([
      for email, roles in var.human_users : [
        for role in roles : {
          key   = "${email}:${role}"
          email = email
          role  = role
        }
      ]
    ]) : binding.key => binding
  }
}

resource "google_project" "workload" {
  project_id      = var.project_id
  name            = var.project_name
  folder_id       = var.folder_id
  billing_account = var.billing_account
  labels          = var.project_labels
}

resource "google_project_service" "required" {
  for_each = toset(local.required_services)

  project            = google_project.workload.project_id
  service            = each.value
  disable_on_destroy = false

  depends_on = [google_project.workload]
}

resource "google_compute_shared_vpc_service_project" "service" {
  count = var.shared_vpc_host_project_id != null ? 1 : 0

  host_project    = var.shared_vpc_host_project_id
  service_project = google_project.workload.project_id

  depends_on = [google_project_service.required]
}

# Human user access — scoped to this team project only (not granted on other teams).
resource "google_project_iam_member" "human_users" {
  for_each = local.human_user_bindings

  project = google_project.workload.project_id
  role    = each.value.role
  member  = "user:${each.value.email}"
}

module "identity" {
  count  = var.enable_identity ? 1 : 0
  source = "../workspace-identity"

  project_id   = google_project.workload.project_id
  workspace_id = var.tfe_workspace_id

  service_account_id           = var.service_account_id
  service_account_display_name = local.sa_display_name
  service_account_roles        = var.service_account_roles

  workload_identity_pool_id               = var.workload_identity_pool_id
  workload_identity_pool_display_name     = var.workload_identity_pool_display_name
  workload_identity_provider_id           = var.workload_identity_provider_id
  workload_identity_provider_display_name = var.workload_identity_provider_display_name

  depends_on = [google_project_service.required]
}

resource "google_storage_bucket" "team" {
  for_each = var.storage_buckets

  project  = google_project.workload.project_id
  name     = each.key
  location = each.value.location

  storage_class               = coalesce(each.value.storage_class, "STANDARD")
  force_destroy               = coalesce(each.value.force_destroy, false)
  uniform_bucket_level_access = coalesce(each.value.uniform_bucket_level_access, true)

  depends_on = [google_project_service.required]
}

# Subnet-scoped access: service project can use only its assigned subnet(s), not other teams' subnets.
# Keys are subnet names (known at plan time); avoid self_link in for_each (unknown until subnet exists).
resource "google_compute_subnetwork_iam_member" "shared_network_user" {
  for_each = var.shared_vpc_host_project_id != null ? toset(var.shared_subnet_names) : toset([])

  project    = var.shared_vpc_host_project_id
  region     = var.shared_subnet_region
  subnetwork = each.value
  role       = "roles/compute.networkUser"
  member     = "serviceProject:${google_project.workload.project_id}"

  depends_on = [google_compute_shared_vpc_service_project.service]
}

resource "google_compute_subnetwork_iam_member" "team_sa_network_user" {
  for_each = var.enable_identity && var.shared_vpc_host_project_id != null ? toset(var.shared_subnet_names) : toset([])

  project    = var.shared_vpc_host_project_id
  region     = var.shared_subnet_region
  subnetwork = each.value
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${module.identity[0].service_account_email}"

  depends_on = [
    module.identity,
    google_compute_shared_vpc_service_project.service,
  ]
}

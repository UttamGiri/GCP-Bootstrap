locals {
  sa_display_name = coalesce(var.service_account_display_name, "TFE SA for ${var.project_id}")
}

resource "google_project" "workload" {
  project_id      = var.project_id
  name            = var.project_name
  folder_id       = var.folder_id
  billing_account = var.billing_account
  labels          = var.project_labels
}

resource "google_project_service" "required" {
  for_each = toset(var.required_services)

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

# Disabled for now — platform creates project + shared VPC attach only.
# Uncomment when ready to provision per-team SA + WIF (workspace-identity).
#
# module "identity" {
#   source = "../workspace-identity"
#
#   project_id   = google_project.workload.project_id
#   workspace_id = var.tfe_workspace_id
#
#   service_account_id           = var.service_account_id
#   service_account_display_name = local.sa_display_name
#   service_account_roles        = var.service_account_roles
#
#   workload_identity_pool_id               = var.workload_identity_pool_id
#   workload_identity_pool_display_name     = var.workload_identity_pool_display_name
#   workload_identity_provider_id           = var.workload_identity_provider_id
#   workload_identity_provider_display_name = var.workload_identity_provider_display_name
#
#   depends_on = [google_project_service.required]
# }

# Subnet-scoped access: service project can use only its assigned subnet(s), not other teams' subnets.
resource "google_compute_subnetwork_iam_member" "shared_network_user" {
  for_each = var.shared_vpc_host_project_id != null ? toset(var.shared_subnet_self_links) : toset([])

  subnetwork = each.value
  role       = "roles/compute.networkUser"
  member     = "serviceProject:${google_project.workload.project_id}"

  depends_on = [google_compute_shared_vpc_service_project.service]
}

# When module.identity is enabled, optionally also grant networkUser to the team SA:
#
# resource "google_compute_subnetwork_iam_member" "team_sa_network_user" {
#   for_each = var.shared_vpc_host_project_id != null ? toset(var.shared_subnet_self_links) : toset([])
#
#   subnetwork = each.value
#   role       = "roles/compute.networkUser"
#   member     = "serviceAccount:${module.identity.service_account_email}"
#
#   depends_on = [
#     module.identity,
#     google_compute_shared_vpc_service_project.service,
#   ]
# }

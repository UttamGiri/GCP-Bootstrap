variable "folder_id" {
  description = "Folder where the shared VPC host project is created"
  type        = string
}

variable "billing_account" {
  description = "Billing account for the host project"
  type        = string
}

variable "project_id" {
  description = "GCP project ID for the shared VPC host project"
  type        = string
}

variable "project_name" {
  description = "Display name for the host project"
  type        = string
}

variable "network_name" {
  description = "Name of the shared VPC network"
  type        = string
}

variable "project_labels" {
  description = "Labels on the host project"
  type        = map(string)
  default     = {}
}

variable "subnets" {
  description = "Subnets created in the shared VPC for workload teams to use"
  type = map(object({
    region        = string
    ip_cidr_range = string
  }))
  default = {}
}

resource "google_project" "host" {
  project_id      = var.project_id
  name            = var.project_name
  folder_id       = var.folder_id
  billing_account = var.billing_account
  labels          = var.project_labels
}

resource "google_project_service" "required" {
  for_each = toset([
    "compute.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ])

  project            = google_project.host.project_id
  service            = each.value
  disable_on_destroy = false

  depends_on = [google_project.host]
}

resource "google_compute_shared_vpc_host_project" "host" {
  project    = google_project.host.project_id
  depends_on = [google_project_service.required]
}

resource "google_compute_network" "shared" {
  project                 = google_project.host.project_id
  name                    = var.network_name
  auto_create_subnetworks = false

  depends_on = [google_compute_shared_vpc_host_project.host]
}

resource "google_compute_subnetwork" "shared" {
  for_each = var.subnets

  project       = google_project.host.project_id
  name          = each.key
  region        = each.value.region
  network       = google_compute_network.shared.id
  ip_cidr_range = each.value.ip_cidr_range
}

output "host_project_id" {
  description = "Shared VPC host project ID — attach workload projects to this"
  value       = google_project.host.project_id
}

output "network_name" {
  description = "Shared VPC network name"
  value       = google_compute_network.shared.name
}

output "network_self_link" {
  description = "Shared VPC network self link"
  value       = google_compute_network.shared.self_link
}

output "subnet_self_links" {
  description = "Shared subnet self links keyed by subnet name"
  value       = { for k, s in google_compute_subnetwork.shared : k => s.self_link }
}

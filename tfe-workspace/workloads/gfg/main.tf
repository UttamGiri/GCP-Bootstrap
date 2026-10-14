locals {
  workload_id = "gfg"
  project_id  = module.project.project_id
  common_labels = merge(var.labels, {
    environment = var.environment
    managed_by  = "terraform"
    workload    = local.workload_id
  })

  gemini_apis = [
    "discoveryengine.googleapis.com",
    "aiplatform.googleapis.com",
    "modelarmor.googleapis.com",
    "storage.googleapis.com",
    "secretmanager.googleapis.com",
  ]

  gemini_ops_roles = [
    "roles/discoveryengine.editor",
    "roles/aiplatform.user",
    "roles/storage.objectAdmin",
    "roles/secretmanager.secretAccessor",
  ]
}

module "project" {
  source = "../../modules/workload-project"

  create_project  = var.create_project
  project_id      = var.project_id
  project_name    = var.project_name
  workload_id     = local.workload_id
  description     = var.description
  org_id          = var.org_id
  folder_id       = var.folder_id
  billing_account = var.billing_account

  host_project_id      = var.host_project_id
  attach_shared_vpc    = var.attach_shared_vpc
  subnet_network_users = var.subnet_network_users

  deployer_account_id = var.deployer_account_id
  impersonators       = var.impersonators

  extra_project_services = local.gemini_apis

  labels = local.common_labels
}

module "rag_staging_bucket" {
  source = "../../modules/gcs-buckets"

  project_id    = local.project_id
  common_labels = local.common_labels

  buckets = {
    rag_staging = {
      name               = "gfg-rag-${local.project_id}-${var.bucket_suffix}"
      location           = var.rag_bucket_location
      force_destroy      = var.rag_bucket_force_destroy
      versioning_enabled = true
      labels = {
        purpose = "gemini-enterprise-rag-staging"
      }
    }
  }

  depends_on = [module.project]
}

resource "google_service_account" "gemini_ops" {
  project      = local.project_id
  account_id   = var.gemini_ops_account_id
  display_name = "Gemini Enterprise ops (Discovery Engine, GCS import, Model Armor setup)"

  depends_on = [module.project]
}

resource "google_project_iam_member" "gemini_ops" {
  for_each = toset(local.gemini_ops_roles)

  project = local.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gemini_ops.email}"
}

resource "google_storage_bucket_iam_member" "gemini_ops_rag_writer" {
  bucket = module.rag_staging_bucket.bucket_names["rag_staging"]
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.gemini_ops.email}"
}

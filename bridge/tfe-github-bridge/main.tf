terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

resource "google_project_service" "required" {
  for_each = toset([
    "cloudfunctions.googleapis.com",
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "storage.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_secret_manager_secret" "github_pat" {
  project   = var.project_id
  secret_id = "${var.function_name}-github-pat"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required]
}

resource "google_secret_manager_secret_version" "github_pat" {
  secret      = google_secret_manager_secret.github_pat.id
  secret_data = var.github_pat
}

resource "google_secret_manager_secret" "tfe_token" {
  project   = var.project_id
  secret_id = "${var.function_name}-tfe-token"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required]
}

resource "google_secret_manager_secret_version" "tfe_token" {
  secret      = google_secret_manager_secret.tfe_token.id
  secret_data = var.tfe_token
}

resource "google_secret_manager_secret" "tfe_webhook_secret" {
  project   = var.project_id
  secret_id = "${var.function_name}-webhook-secret"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required]
}

resource "google_secret_manager_secret_version" "tfe_webhook_secret" {
  secret      = google_secret_manager_secret.tfe_webhook_secret.id
  secret_data = var.tfe_webhook_secret
}

resource "google_storage_bucket" "source" {
  project                     = var.project_id
  name                        = "${var.project_id}-${var.function_name}-src"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true

  depends_on = [google_project_service.required]
}

data "archive_file" "function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/function"
  output_path = "${path.module}/.build/function.zip"
}

resource "google_storage_bucket_object" "function_zip" {
  name   = "function-${data.archive_file.function_zip.output_md5}.zip"
  bucket = google_storage_bucket.source.name
  source = data.archive_file.function_zip.output_path
}

resource "google_service_account" "bridge" {
  project      = var.project_id
  account_id   = var.function_name
  display_name = "TFE to GitHub webhook bridge"
}

resource "google_secret_manager_secret_iam_member" "github_pat" {
  secret_id = google_secret_manager_secret.github_pat.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.bridge.email}"
}

resource "google_secret_manager_secret_iam_member" "tfe_token" {
  secret_id = google_secret_manager_secret.tfe_token.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.bridge.email}"
}

resource "google_secret_manager_secret_iam_member" "tfe_webhook_secret" {
  secret_id = google_secret_manager_secret.tfe_webhook_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.bridge.email}"
}

resource "google_cloudfunctions2_function" "bridge" {
  project  = var.project_id
  name     = var.function_name
  location = var.region

  build_config {
    runtime     = "python312"
    entry_point = "handle"

    source {
      storage_source {
        bucket = google_storage_bucket.source.name
        object = google_storage_bucket_object.function_zip.name
      }
    }
  }

  service_config {
    max_instance_count = 5
    available_memory   = "256Mi"
    timeout_seconds    = 60
    service_account_email = google_service_account.bridge.email

    environment_variables = {
      GITHUB_REPO  = var.github_repo
      TFE_HOSTNAME = var.tfe_hostname
    }

    secret_environment_variables {
      key        = "GITHUB_PAT"
      project_id = var.project_id
      secret     = google_secret_manager_secret.github_pat.secret_id
      version    = "latest"
    }

    secret_environment_variables {
      key        = "TFE_TOKEN"
      project_id = var.project_id
      secret     = google_secret_manager_secret.tfe_token.secret_id
      version    = "latest"
    }

    secret_environment_variables {
      key        = "TFE_WEBHOOK_SECRET"
      project_id = var.project_id
      secret     = google_secret_manager_secret.tfe_webhook_secret.secret_id
      version    = "latest"
    }
  }

  depends_on = [
    google_project_service.required,
    google_secret_manager_secret_version.github_pat,
    google_secret_manager_secret_version.tfe_token,
    google_secret_manager_secret_version.tfe_webhook_secret,
  ]
}

resource "google_cloud_run_service_iam_member" "public_invoker" {
  project  = var.project_id
  location = var.region
  service  = google_cloudfunctions2_function.bridge.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

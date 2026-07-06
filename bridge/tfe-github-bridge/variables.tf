variable "project_id" {
  description = "GCP project ID where the bridge is deployed"
  type        = string
}

variable "region" {
  description = "GCP region for Cloud Functions"
  type        = string
  default     = "us-central1"
}

variable "function_name" {
  description = "Cloud Function name"
  type        = string
  default     = "tfe-github-bridge"
}

variable "github_repo" {
  description = "GitHub repository in owner/repo form"
  type        = string
  default     = "UttamGiri/GCP-Bootstrap"
}

variable "tfe_hostname" {
  description = "Terraform Enterprise / Cloud hostname"
  type        = string
  default     = "app.terraform.io"
}

variable "github_pat" {
  description = "GitHub PAT with Actions + Contents on github_repo"
  type        = string
  sensitive   = true
}

variable "tfe_token" {
  description = "TFE API token used to read run status"
  type        = string
  sensitive   = true
}

variable "tfe_webhook_secret" {
  description = "Shared secret for TFE notification HMAC — paste same value in TFE notification Token field"
  type        = string
  sensitive   = true
}

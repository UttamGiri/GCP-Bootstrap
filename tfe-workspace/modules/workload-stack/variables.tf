variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "workspace_id" {
  description = "TFE workspace ID for WIF impersonation"
  type        = string
}

variable "resource_suffix" {
  description = "Suffix for SA/WIF names; bumped after each identity destroy"
  type        = string
}

variable "bucket_suffix" {
  description = "Fixed suffix for bucket names; not bumped on destroy"
  type        = string
}

variable "environment" {
  description = "Environment label for workload resources"
  type        = string
  default     = "dev"
}

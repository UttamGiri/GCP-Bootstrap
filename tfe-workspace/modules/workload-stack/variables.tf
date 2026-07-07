variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "workspace_id" {
  description = "TFE workspace ID for WIF impersonation"
  type        = string
}

variable "resource_suffix" {
  description = "Suffix for SA/WIF/bucket names; bumped after each destroy"
  type        = string
}

variable "environment" {
  description = "Environment label for workload resources"
  type        = string
  default     = "dev"
}

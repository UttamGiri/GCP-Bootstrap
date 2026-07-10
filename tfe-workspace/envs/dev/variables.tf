# -----------------------------------------------------------------------------
# TFC GCP OIDC — must be ENVIRONMENT variables in the workspace, not Terraform
# variables. If TFC_GCP_* appear in terraform.tfvars, TFC misconfigured them as
# "Terraform variable" type. Move them to Environment variable (sensitive) or
# these optional declarations silence the undeclared-variable warning only.
# -----------------------------------------------------------------------------

variable "TFC_GCP_PROVIDER_AUTH" {
  type        = string
  default     = null
  description = "Unused in HCL — set as TFC Environment variable, not Terraform variable."
  nullable    = true
}

variable "TFC_GCP_PRINCIPAL_TYPE" {
  type        = string
  default     = null
  description = "Unused in HCL — set as TFC Environment variable, not Terraform variable."
  nullable    = true
}

variable "TFC_GCP_AUTH_IDENTITY" {
  type        = string
  default     = null
  description = "Unused in HCL — set as TFC Environment variable, not Terraform variable."
  nullable    = true
}

variable "TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL" {
  type        = string
  default     = null
  description = "Unused in HCL — set as TFC Environment variable, not Terraform variable."
  nullable    = true
}

variable "TFC_GCP_WORKLOAD_PROVIDER_NAME" {
  type        = string
  default     = null
  description = "Unused in HCL — set as TFC Environment variable, not Terraform variable."
  nullable    = true
}

variable "TFC_GCP_PLAN_SERVICE_ACCOUNT_EMAIL" {
  type        = string
  default     = null
  description = "Unused in HCL — set as TFC Environment variable, not Terraform variable."
  nullable    = true
}

variable "TFC_GCP_APPLY_SERVICE_ACCOUNT_EMAIL" {
  type        = string
  default     = null
  description = "Unused in HCL — set as TFC Environment variable, not Terraform variable."
  nullable    = true
}

# Optional override when bootstrap remote state is not yet shared with this workspace.
variable "bootstrap_project_id" {
  type        = string
  default     = null
  description = "Bootstrap GCP project ID for provider auth context. Normally read from GCP-Vaflt-Bootstrap remote state; set this only until remote state sharing is configured."
  nullable    = true
}

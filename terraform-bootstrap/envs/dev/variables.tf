variable "enable_tfe_github_bridge" {
  description = "Deploy Cloud Function bridge for TFE run:completed -> GitHub auth sync"
  type        = bool
  default     = false
}

variable "bridge_github_pat" {
  description = "GitHub PAT (Actions + Contents) for repository_dispatch"
  type        = string
  sensitive   = true
  default     = ""
}

variable "bridge_tfe_token" {
  description = "TFE API token — same value as GitHub secret TFE_TOKEN"
  type        = string
  sensitive   = true
  default     = ""
}

variable "bridge_tfe_webhook_secret" {
  description = "Shared secret — same value as TFE notification Token field"
  type        = string
  sensitive   = true
  default     = ""
}

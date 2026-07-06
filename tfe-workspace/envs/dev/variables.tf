variable "github_dispatch_token" {
  description = "GitHub PAT with repo scope. Set in TFE as sensitive env var TF_VAR_github_dispatch_token. Triggers copy-bootstrap-auth workflow after successful destroy only."
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_repo" {
  description = "GitHub owner/repo hosting .github/workflows/tfe-copy-bootstrap-auth.yml"
  type        = string
  default     = "UttamGiri/GCP-Bootstrap"
}

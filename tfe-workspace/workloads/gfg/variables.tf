variable "environment" {
  type = string
}

variable "project_id" {
  type = string
}

variable "project_name" {
  type    = string
  default = "gfg"
}

variable "description" {
  type    = string
  default = "Gemini Enterprise app: Discovery Engine data stores, GCS document RAG, Model Armor, custom MCP via Kong AI Gateway (Jira and third-party tools), central OIDC."
}

variable "create_project" {
  type    = bool
  default = true
}

variable "org_id" {
  type    = string
  default = null
}

variable "folder_id" {
  type    = string
  default = null
}

variable "billing_account" {
  type    = string
  default = null
}

variable "host_project_id" {
  type    = string
  default = null
}

variable "attach_shared_vpc" {
  type    = bool
  default = false
}

variable "subnet_network_users" {
  type = list(object({
    region = string
    name   = string
  }))
  default = []
}

variable "deployer_account_id" {
  type    = string
  default = "gfg-deployer"
}

variable "gemini_ops_account_id" {
  type    = string
  default = "gemini-ops"
}

variable "impersonators" {
  type    = list(string)
  default = []
}

variable "bucket_suffix" {
  type    = string
  default = "1"
}

variable "rag_bucket_location" {
  type    = string
  default = "US"
}

variable "rag_bucket_force_destroy" {
  type    = bool
  default = true
}

variable "labels" {
  type    = map(string)
  default = {}
}

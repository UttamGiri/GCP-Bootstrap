variable "project_id" {
  description = "Desired GCP project ID for the workload (globally unique)"
  type        = string
}

variable "project_name" {
  description = "Display name for the workload project"
  type        = string
  default     = "workload-dev"
}

variable "org_id" {
  description = "Organization ID when create_project is true and folder_id is unset"
  type        = string
  default     = null
}

variable "folder_id" {
  description = "Folder ID when create_project is true (preferred over org root)"
  type        = string
  default     = null
}

variable "billing_account" {
  description = "Billing account ID when create_project is true"
  type        = string
  default     = null
}

variable "create_project" {
  description = "Create the GCP project. If false, project_id must already exist."
  type        = bool
  default     = true
}

variable "host_project_id" {
  description = "Shared VPC host project to attach this project to (optional)"
  type        = string
  default     = null
}

variable "attach_shared_vpc" {
  description = "Attach as Shared VPC service project to host_project_id"
  type        = bool
  default     = false
}

variable "subnet_network_users" {
  description = "Host subnets to grant roles/compute.networkUser on"
  type = list(object({
    region = string
    name   = string
  }))
  default = []
}

variable "deployer_account_id" {
  description = "Account id for the namespace deployer service account"
  type        = string
  default     = "gke-deployer"
}

variable "impersonators" {
  description = "IAM members allowed to impersonate the deployer SA (e.g. user:you@company.com)"
  type        = list(string)
  default     = []
}

variable "labels" {
  type    = map(string)
  default = {}
}

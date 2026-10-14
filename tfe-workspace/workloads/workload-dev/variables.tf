variable "environment" {
  type = string
}

variable "project_id" {
  type = string
}

variable "project_name" {
  type    = string
  default = "workload-dev"
}

variable "description" {
  type    = string
  default = "Shared GKE tenant project: namespace workload-dev, Helm deployer SA, Shared VPC consumer."
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
  default = "gke-deployer"
}

variable "impersonators" {
  type    = list(string)
  default = []
}

variable "labels" {
  type    = map(string)
  default = {}
}

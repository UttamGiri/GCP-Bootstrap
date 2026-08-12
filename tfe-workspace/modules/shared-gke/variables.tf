variable "project_id" {
  description = "Host project where the shared GKE cluster lives"
  type        = string
}

variable "name" {
  description = "GKE cluster name"
  type        = string
}

variable "region" {
  description = "Regional cluster location"
  type        = string
  default     = "us-central1"
}

variable "network" {
  description = "VPC self_link or name"
  type        = string
}

variable "subnetwork" {
  description = "Subnet self_link or name"
  type        = string
}

variable "pods_range_name" {
  description = "Secondary range name on the subnet for pods"
  type        = string
  default     = "gke-pods"
}

variable "services_range_name" {
  description = "Secondary range name on the subnet for services"
  type        = string
  default     = "gke-services"
}

variable "enable_private_nodes" {
  description = "Nodes without public IPs"
  type        = bool
  default     = true
}

variable "enable_private_endpoint" {
  description = "If true, control plane is private-only (needs VPN/Connect Gateway for kubectl)"
  type        = bool
  default     = false
}

variable "master_ipv4_cidr_block" {
  description = "Private master CIDR (/28). Required when private nodes are enabled."
  type        = string
  default     = "172.16.0.0/28"
}

variable "release_channel" {
  type    = string
  default = "REGULAR"
}

variable "node_count" {
  description = "Initial / fixed node count for the default pool (keep small for cost)"
  type        = number
  default     = 1
}

variable "machine_type" {
  type    = string
  default = "e2-medium"
}

variable "disk_size_gb" {
  type    = number
  default = 50
}

variable "deployer_service_account_email" {
  description = "Workload-dev deployer SA that receives cluster access + namespace RBAC"
  type        = string
}

variable "namespace" {
  description = "Tenant namespace name"
  type        = string
  default     = "workload-dev"
}

variable "labels" {
  type    = map(string)
  default = {}
}

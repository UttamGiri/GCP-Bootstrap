module "project" {
  source = "../../modules/workload-project"

  create_project  = var.create_project
  project_id      = var.project_id
  project_name    = var.project_name
  workload_id     = "workload-dev"
  description     = var.description
  org_id          = var.org_id
  folder_id       = var.folder_id
  billing_account = var.billing_account

  host_project_id      = var.host_project_id
  attach_shared_vpc    = var.attach_shared_vpc
  subnet_network_users = var.subnet_network_users

  deployer_account_id = var.deployer_account_id
  impersonators       = var.impersonators

  labels = merge(var.labels, {
    environment = var.environment
    workload    = "workload-dev"
  })
}

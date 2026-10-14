locals {
  workload_dev_config = {
    enabled         = false
    create_project  = true
    project_id      = "vaflt-workload-dev-1"
    project_name    = "workload-dev"
    description     = "Shared GKE tenant project: namespace workload-dev, Helm deployer SA, Shared VPC consumer."
    org_id          = "327947404107"
    billing_account = "01BC6F-241F9A-8762DE"
    attach_shared_vpc = false
    impersonators   = []
  }
}

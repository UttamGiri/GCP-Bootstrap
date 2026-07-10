# Platform team only: folders, OU policies, shared VPC per env, team projects + SA + WIF.
# Workload teams use handoff outputs in their own repos. No app infra here.

locals {
  # Lower envs get one dedicated subnet per team (subnet name = team map key).
  lower_env_network_keys = toset(["dev", "preprod"])

  team_subnets_by_network = {
    for net_key in local.lower_env_network_keys : net_key => {
      for team_key, team in var.workload_projects :
      team_key => {
        region        = coalesce(try(team.subnet_region, null), "us-central1")
        ip_cidr_range = team.subnet_cidr
      }
      if team.shared_network_key == net_key && try(team.subnet_cidr, null) != null
    }
  }

  shared_network_subnets = {
    for net_key, net in var.shared_networks : net_key =>
    contains(local.lower_env_network_keys, net_key)
    ? local.team_subnets_by_network[net_key]
    : coalesce(net.subnets, {})
  }

  workload_projects_resolved = {
    for team_key, team in var.workload_projects : team_key => merge(team, {
      shared_subnet_names = coalesce(
        try(team.shared_subnet_names, null),
        contains(local.lower_env_network_keys, team.shared_network_key) ? [team_key] : ["workload"],
      )
    })
  }
}

module "org_folders" {
  source = "../org-folders"

  org_id  = var.org_id
  folders = var.folders
}

module "folder_policies" {
  source   = "../folder-policies"
  for_each = var.folder_policy_configs

  folder_id = module.org_folders.folder_names[each.key]

  allowed_regions                      = each.value.allowed_regions
  disable_service_account_key_creation = each.value.disable_service_account_key_creation
  require_uniform_bucket_level_access  = each.value.require_uniform_bucket_level_access

  depends_on = [module.org_folders]
}

module "shared_networks" {
  source   = "../shared-network"
  for_each = var.shared_networks

  folder_id       = module.org_folders.folder_names[each.value.folder_key]
  billing_account = var.billing_account

  project_id   = each.value.project_id
  project_name = each.value.project_name
  network_name = each.value.network_name
  subnets      = local.shared_network_subnets[each.key]
  project_labels = merge(
    { managed_by = "platform", environment = each.key },
    coalesce(each.value.project_labels, {}),
  )

  depends_on = [module.org_folders]
}

module "workload_projects" {
  source   = "../workload-project"
  for_each = local.workload_projects_resolved

  folder_id       = module.org_folders.folder_names[each.value.folder_key]
  billing_account = var.billing_account

  project_id   = each.value.project_id
  project_name = each.value.project_name
  project_labels = merge(
    { managed_by = "platform", team = each.key },
    coalesce(each.value.project_labels, {}),
  )

  # Identity inputs kept for when workload-project module.identity is uncommented.
  tfe_workspace_id             = each.value.tfe_workspace_id
  service_account_id           = each.value.service_account_id
  service_account_display_name = each.value.service_account_display_name
  service_account_roles = coalesce(
    each.value.service_account_roles,
    var.default_service_account_roles,
  )

  workload_identity_pool_id               = coalesce(each.value.workload_identity_pool_id, "tfe-${each.key}-pool")
  workload_identity_pool_display_name     = coalesce(each.value.workload_identity_pool_display_name, "TFE ${each.key}")
  workload_identity_provider_id           = coalesce(each.value.workload_identity_provider_id, "tfe-${each.key}-provider")
  workload_identity_provider_display_name = coalesce(each.value.workload_identity_provider_display_name, "TFE ${each.key}")

  shared_vpc_host_project_id = module.shared_networks[each.value.shared_network_key].host_project_id
  shared_subnet_self_links = [
    for name in coalesce(each.value.shared_subnet_names, ["workload"]) :
    module.shared_networks[each.value.shared_network_key].subnet_self_links[name]
  ]

  depends_on = [
    module.org_folders,
    module.folder_policies,
    module.shared_networks,
  ]
}

output "folder_names" {
  description = "GCP folder resource names (platform, dev, prod)"
  value       = module.org_folders.folder_names
}

output "folder_ids" {
  description = "Numeric GCP folder IDs"
  value       = module.org_folders.folder_ids
}

output "shared_networks" {
  description = "Shared VPC host project and network per environment"
  value = {
    for key, mod in module.shared_networks : key => {
      host_project_id   = mod.host_project_id
      network_name      = mod.network_name
      network_self_link = mod.network_self_link
      subnet_self_links = mod.subnet_self_links
    }
  }
}

output "workload_projects" {
  description = "Handoff to workload teams — project, SA, WIF (teams deploy app infra in their repos)"
  value = {
    for key, mod in module.workload_projects : key => {
      project_id                        = mod.project_id
      shared_subnet_self_links          = mod.shared_subnet_self_links
      tfe_workspace_id                  = mod.tfe_workspace_id
      TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL = mod.TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL
      TFC_GCP_WORKLOAD_PROVIDER_NAME    = mod.TFC_GCP_WORKLOAD_PROVIDER_NAME
    }
  }
}

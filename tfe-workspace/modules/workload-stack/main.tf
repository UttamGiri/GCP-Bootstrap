# Do not add sibling modules here — add ephemeral resources inside workload-resources/.
# This depends_on is the only destroy-order guard needed.

locals {
  # The compute/dns/serviceusage roles are required by the vertex-psc module. They
  # are granted by the same run that needs them, so the first apply after adding
  # them must use the bootstrap identity.
  workspace_sa_roles = concat([
    "roles/viewer",
    "roles/storage.admin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountTokenCreator",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin",
    "roles/dns.admin",
    # Project-scoped xpnAdmin is enough to attach service projects to this host.
    # Marking the project a host at all needs xpnAdmin at the org or folder level,
    # which is why enable_shared_vpc_host defaults to false.
    "roles/compute.xpnAdmin",
    ],
    # serviceAccountAdmin does not cover key creation, so only ask for this role
    # when keys are actually wanted.
    var.vertex_psc.create_sa_key ? ["roles/iam.serviceAccountKeyAdmin"] : [],
    # Setting vertexai.allowedModels at project level needs orgpolicy.policy.set.
    var.vertex_psc.enforce_model_allowlist ? ["roles/orgpolicy.policyAdmin"] : [],
  )
}

module "workspace_identity" {
  source = "../workspace-identity"

  project_id   = var.project_id
  workspace_id = var.workspace_id

  service_account_id           = "gcp-tfe-workspace-sa-${var.resource_suffix}"
  service_account_display_name = "GCP TFE Workspace Service Account"

  service_account_roles = local.workspace_sa_roles

  workload_identity_pool_id               = "tfe-workspace-pool-${var.resource_suffix}"
  workload_identity_pool_display_name     = "GCP TFE Workspace"
  workload_identity_provider_id           = "tfe-workspace-provider-${var.resource_suffix}"
  workload_identity_provider_display_name = "GCP TFE Provider"
}

module "workload_resources" {
  source = "../workload-resources"

  project_id      = var.project_id
  resource_suffix = var.resource_suffix
  bucket_suffix   = var.bucket_suffix
  network_suffix  = var.network_suffix
  environment     = var.environment

  vertex_psc = var.vertex_psc

  depends_on = [module.workspace_identity]
}

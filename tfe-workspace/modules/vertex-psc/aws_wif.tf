# AWS IRSA → GCP WIF → existing Vertex client SA (no JSON key, no second SA).
# Analogous to terraform-bootstrap TFE OIDC, but the IdP is AWS not HCP.

data "google_project" "host" {
  project_id = var.host_project_id
}

locals {
  aws_role_arn = (
    coalesce(var.aws_wif.enabled, false) && var.aws_wif.aws_account_id != null && var.aws_wif.aws_role_name != null
    ? "arn:aws:iam::${var.aws_wif.aws_account_id}:role/${var.aws_wif.aws_role_name}"
    : ""
  )

  # Maps GetCallerIdentity assumed-role STS ARNs to the IAM role ARN used in
  # principalSet / attribute_condition. Session suffix is dropped.
  aws_role_cel = "assertion.arn.contains('assumed-role') ? assertion.arn.extract('{account_arn}assumed-role/{role_name}/') + 'role/' + assertion.arn.extract('assumed-role/{role_name}/') : assertion.arn"
}

resource "google_iam_workload_identity_pool" "aws_kong" {
  count = coalesce(var.aws_wif.enabled, false) ? 1 : 0

  project                   = var.host_project_id
  workload_identity_pool_id = var.aws_wif.pool_id
  display_name              = "AWS Kong Vertex"
  description               = "Federates EKS IRSA into the Vertex client SA"

  depends_on = [google_project_service.host]

  timeouts {
    delete = "30m"
  }
}

resource "google_iam_workload_identity_pool_provider" "aws_kong" {
  count = coalesce(var.aws_wif.enabled, false) ? 1 : 0

  project                            = var.host_project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.aws_kong[0].workload_identity_pool_id
  workload_identity_pool_provider_id = var.aws_wif.provider_id
  display_name                       = "AWS Kong"
  description                        = "Trusts one IAM role in AWS account ${var.aws_wif.aws_account_id}"

  aws {
    account_id = var.aws_wif.aws_account_id
  }

  attribute_mapping = {
    "google.subject"        = local.aws_role_cel
    "attribute.aws_role"    = local.aws_role_cel
    "attribute.aws_account" = "assertion.account"
  }

  # Only this role — not every role in the AWS account.
  attribute_condition = "attribute.aws_role == '${local.aws_role_arn}'"

  depends_on = [google_iam_workload_identity_pool.aws_kong]
}

# Same role as TFE bootstrap impersonation, different principal (AWS role vs workspace ID).
resource "google_service_account_iam_member" "aws_kong_wif" {
  count = coalesce(var.aws_wif.enabled, false) ? 1 : 0

  service_account_id = google_service_account.host_client.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.host.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.aws_kong[0].workload_identity_pool_id}/attribute.aws_role/${local.aws_role_arn}"

  depends_on = [google_iam_workload_identity_pool_provider.aws_kong]
}

# GCP Bootstrap (Terraform Only)

This repo solves the GCP chicken-egg bootstrap problem using Terraform only.
It creates:

- `bs-tfe-sa` service account
- initial project IAM roles for that service account
- Workload Identity Pool + Provider for GitHub OIDC
- IAM binding so GitHub repo can impersonate `bs-tfe-sa`

## Why this design

You can:

- zip this repo, extract on any machine, and run `terraform apply`
- push to GitHub and run bootstrap from GitHub Actions with OIDC
- call this repo from another Terraform workspace (for example `gcp-tf-bootstrap`) using Git source
- let the same bootstrap identity update its own project roles when needed

## Prerequisites

- Terraform `>= 1.5.0`
- Google Cloud authentication on first run (local user credentials)
- Permissions in target project to create:
  - service accounts
  - project IAM bindings
  - workload identity pools/providers

## 1) Run from zip/extract + CLI

Create zip:

```bash
cd GCP-Booptstrap
zip -r gcp-bootstrap.zip . -x "*.git*"
```

Extract and apply:

```bash
unzip gcp-bootstrap.zip -d gcp-bootstrap
cd gcp-bootstrap/terraform
cp terraform.tfvars.example terraform.tfvars
```

Update `terraform.tfvars`:

```hcl
project_id        = "your-gcp-project-id"
github_repository = "UttamGiri/GCP-Bootstrap"
github_branch     = "main"
```

Then run:

```bash
terraform init
terraform workspace new bootstrap || terraform workspace select bootstrap
terraform apply
```

## 2) Push to GitHub and run with OIDC

This repo includes workflow: `.github/workflows/bootstrap.yml`.

After first local bootstrap apply, set these GitHub repository variables:

- `GCP_PROJECT_ID` = your project id
- `GCP_WORKLOAD_IDENTITY_PROVIDER` = output `github_workload_identity_provider`
- `GCP_BOOTSTRAP_SERVICE_ACCOUNT` = output `bootstrap_service_account_email`

Then trigger GitHub Actions workflow `Terraform Bootstrap` (manual or push to `main`).

## 3) Use from `gcp-tf-bootstrap` workspace via GitHub repo

In another workspace, call this repo as a module:

```hcl
module "gcp_bootstrap" {
  source = "git::https://github.com/UttamGiri/GCP-Bootstrap.git//terraform?ref=main"

  project_id        = var.project_id
  github_repository = "UttamGiri/GCP-Bootstrap"
  github_branch     = "main"
}
```

This lets `gcp-tf-bootstrap` consume the same bootstrap logic directly from GitHub.

## Default bootstrap roles

- `roles/viewer`
- `roles/storage.admin`
- `roles/resourcemanager.projectIamAdmin`
- `roles/iam.serviceAccountAdmin`
- `roles/iam.serviceAccountTokenCreator`

Tune `bootstrap_roles` in `terraform/variables.tf` for least privilege.

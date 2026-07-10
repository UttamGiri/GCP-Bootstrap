# Platform team Terraform

**Platform team only.** Workload teams use separate repos — not managed here.

## What this repo creates

| Resource | Module |
|----------|--------|
| Org folders (Platform, Dev, Prod) | `org-folders` |
| OU policies (allowed regions, no SA keys, bucket rules) | `folder-policies` |
| Shared VPC per environment (dev, prod) | `shared-network` |
| Team GCP projects + SA + WIF | `workload-project` |

## What platform does NOT create

- Application buckets, GKE, Cloud Run (workload team repos)
- Per-team VPCs (teams use shared VPC subnets)

## Modules

```text
envs/dev/main.tf
└── platform-layout
      ├── org-folders
      ├── folder-policies (dev, prod OUs)
      ├── shared-networks (dev, prod — one shared VPC each)
      └── workload-project (for_each team in map)
            └── workspace-identity (SA + WIF)
```

## Onboard a team

Add to `workload_projects` in `envs/dev/main.tf` with `shared_network_key = "dev"`.

Apply → hand off outputs to team for TFE env vars and `project_id` for their repo.

## TFE setup (required before first apply)

### 1. Remote state sharing (fixes `Error retrieving state: forbidden`)

Platform deploy workspace: **`GCP-VAFLT-TFE-WORK`** (working directory `tfe-workspace/envs/dev`).

In **GCP-Vaflt-Bootstrap** workspace:

1. **Settings → General → Remote state sharing**
2. Enable sharing and add **`GCP-VAFLT-TFE-WORK`** (exact name)

Until that is done, set Terraform variable on **`GCP-VAFLT-TFE-WORK`**:

| Variable | Value |
|----------|--------|
| `bootstrap_project_id` | `bootstrap-prj-501802` (or your bootstrap project ID) |

Remove `bootstrap_project_id` after remote state sharing works.

### 2. GCP OIDC env vars (fixes undeclared `TFC_GCP_*` warnings)

In **GCP-VAFLT-TFE-WORK** → **Variables**, set these as **Environment variable** (sensitive), **not** Terraform variable:

| Name | Value |
|------|--------|
| `TFC_GCP_PROVIDER_AUTH` | `true` |
| `TFC_GCP_PRINCIPAL_TYPE` | `service_account` |
| `TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL` | from bootstrap output `bootstrap_service_account_email` |
| `TFC_GCP_WORKLOAD_PROVIDER_NAME` | from bootstrap output `tfe_workload_identity_provider` |

If `TFC_GCP_*` were created as **Terraform variables**, delete them and re-add as **Environment variables**. Values copied into `terraform.tfvars` cause undeclared-variable warnings.

Bootstrap workspace must also trust this platform workspace ID in `additional_tfe_workspace_ids` (`terraform-bootstrap/envs/dev/main.tf`).

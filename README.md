# GCP Bootstrap (Foundation + Automation)

This repo keeps one codebase but splits execution into two Terraform stacks:

- `terraform/foundation`: one-time bootstrap of `bootstrap-prj`, `bs-tfe-sa`, and WIF pool/provider for Terraform workspace OIDC
- `terraform/automation`: ongoing updates to IAM roles of the same `bs-tfe-sa`

This matches your model where state and apply happen inside TFE/TFC workspace, not on GitHub runner.

## Stack 1: Foundation (Path 1)

Use this first to bootstrap trust and identity.

Creates:

- bootstrap project (optional, enabled by default with `create_project=true`)
- bootstrap service account `bs-tfe-sa`
- initial bootstrap project roles
- Workload Identity Pool + Provider for Terraform workspace OIDC
- IAM impersonation binding for the exact Terraform workspace ID

Required foundation inputs:

- `tfe_workspace_id` (example `ws-xxxxxxxxxxxxxxxx`)
- `project_id`
- if `create_project=true`:
  - one of `org_id` or `folder_id`
  - `billing_account`

### Foundation state backend (object storage)

Foundation uses object storage state in Google Cloud Storage (GCS), not TFE workspace state.

If you meant "S3 bucket", in GCP the equivalent is a GCS bucket.

### Create state bucket manually (recommended first run)

#### Option A: Google Cloud Console

1. Open Cloud Storage in an existing project you can use for Terraform state.
2. Create bucket (globally unique name), for example `bootstrap-prj-tfstate`.
3. Choose region/location per your policy.
4. Enable bucket versioning.
5. Keep access private (uniform bucket-level access recommended).

#### Option B: gcloud / gsutil CLI

```bash
gcloud storage buckets create gs://bootstrap-prj-tfstate --project=<STATE_HOST_PROJECT_ID> --location=us-central1
gcloud storage buckets update gs://bootstrap-prj-tfstate --versioning
```

### How foundation code uses this bucket

- Backend block is in `terraform/foundation/backend.tf`
- Backend settings are passed from `terraform/foundation/backend.hcl`

Create local backend config:

```bash
cd terraform/foundation
cp backend.hcl.example backend.hcl
# edit backend.hcl bucket/prefix values
```

Then initialize with backend config:

```bash
terraform init -backend-config=backend.hcl
```

Example foundation local run:

```bash
cd terraform/foundation
cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl
# update terraform.tfvars and backend.hcl
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

Best practice:

- Keep foundation state in remote object storage (GCS).
- Enable versioning on the state bucket.
- Never commit state files to Git.
- Use least-privilege access for bucket and state operations.
- Host state bucket in an existing central/state-host project.

### No TFE Auth Local Flow (project not pre-created)

If you cannot authenticate to TFE from local and do not want to pre-create the project:

1. Run foundation once with local state (`create_project=true`, `create_state_bucket=true`).
2. Let foundation create the bootstrap project and state bucket.
3. Configure `backend.hcl` with that bucket.
4. Run `terraform init -migrate-state -backend-config=backend.hcl`.

This gives a safe bootstrap path with no state in Git and no manual project pre-creation.

## Stack 2: Automation (Path 2)

Use this after foundation for day-2 role updates to the same service account.

Manages:

- role membership for `bs-tfe-sa@<project>.iam.gserviceaccount.com`

Example local run:

```bash
cd terraform/automation
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

## GitHub Action -> Terraform Workspace Run

Workflow file: `.github/workflows/bootstrap.yml`

This workflow:

- uploads selected stack configuration
- creates run in TFE/TFC workspace
- applies run via TFE/TFC API

It does not execute Terraform on GitHub runner.  
State and apply happen in the Terraform workspace backend.

GitHub repo configuration:

- Variables:
  - `TF_CLOUD_ORGANIZATION`
  - `TF_WORKSPACE_FOUNDATION`
  - `TF_WORKSPACE_AUTOMATION`
  - `TF_HOSTNAME` (optional, only for Terraform Enterprise)
- Secret:
  - `TF_API_TOKEN`

How to run:

- trigger workflow `Terraform Bootstrap`
- choose input `stack = foundation` or `stack = automation`

## Recommended controls

- Keep manual apply approvals in both workspaces
- Restrict approvers for foundation workspace
- Keep at least one break-glass admin principal outside `bs-tfe-sa`

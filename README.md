# GCP Bootstrap (Unified Stack)

This repository uses one Terraform stack in `terraform-bootstrap/` that handles:

- bootstrap project usage (existing project mode by default)
- bootstrap service account `bs-tfe-sa`
- required project API enablement
- Workload Identity Pool + Provider for Terraform workspace OIDC
- IAM roles for the bootstrap service account
- impersonation binding for a specific Terraform workspace ID

It also includes separate TFE workspace configurations under `tfe-workspace/envs/` for environments such as dev and prod. Those configurations currently create GCP storage buckets.

## Intended operating model

1. Run Terraform first from Google Cloud Shell with local state.
2. Download the generated local state file.
3. Import that state into a Terraform Cloud/Enterprise workspace.
4. Configure workspace variables (including GCP OIDC env vars).
5. Run future updates from Terraform workspace UI.

## Two-workspace model

Use two separate TFE/TFC workspaces:

- `bootstrap-dev`: runs `terraform-bootstrap/`
- `tfe-dev`: runs `tfe-workspace/envs/dev`
- `tfe-prod`: runs `tfe-workspace/envs/prod`

The bootstrap workspace creates and owns:

- bootstrap service account
- WIF pool/provider
- IAM roles
- WIF impersonation bindings for trusted TFE workspace IDs

The `tfe-dev` and `tfe-prod` workspaces use the bootstrap service account and WIF provider to run separate Terraform configurations. In this repo, the environment folders under `tfe-workspace/envs/` create GCP storage buckets.

Important concept:

- GCP authentication is not determined by the `tfe-dev` Terraform state.
- GCP authentication is determined by `TFC_GCP_*` environment variables in the `tfe-dev` workspace.
- Resource existence is determined by the `tfe-dev` workspace state plus refresh against GCP.
- Bootstrap outputs are read with `terraform_remote_state` for reference, but the TFE workspace environment variables must still be set before the run starts.

Before running `tfe-dev`, the bootstrap WIF provider must trust the `tfe-dev` workspace ID. The bootstrap stack in `terraform-bootstrap/` is intentionally kept separate and should only be changed when you are ready to update bootstrap trust.

## Prerequisites

- Access to Google Cloud Shell (or any environment with working gcloud auth)
- Terraform installed in the execution environment
- Permissions to create projects under your org/folder and attach billing
- Terraform Cloud/Enterprise access to create projects/workspaces

## Install Terraform in Cloud Shell (if missing)

Check first:

```bash
terraform version
```

If command is missing, install Terraform:

```bash
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
terraform version
```

If install succeeds but `terraform` is still not found, use the full path:

```bash
/usr/bin/terraform version
/usr/bin/terraform init
```

Why this happens:

- package install placed Terraform at `/usr/bin/terraform`
- current shell PATH/hash cache may not have refreshed yet
- using full path bypasses PATH lookup issues

Optional persistence for future Cloud Shell sessions:

- Add the install commands above to `$HOME/.customize_environment`.

Also verify Google auth in Cloud Shell:

```bash
gcloud auth list
gcloud auth application-default print-access-token
```

Cloud Shell cleanup (delete cloned/unzipped repo folder):

```bash
ls ~/GCP-Booptstrap
rm -rf ~/GCP-Booptstrap
```

## Terraform workspace creation (recommended)

1. In TFE/TFC, create a **Project** named `platform-bootstrap`.
2. Inside that project, create a new workspace.
3. Choose **Version Control Workflow**.
4. Connect this GitHub repository.
5. Set workspace **Working Directory** to `terraform-bootstrap/`.
6. Save workspace and copy the workspace ID (`ws-xxxxxxxxxxxxxxxx`) from workspace settings/details.

Notes:

- Use Version Control Workflow for traceability and UI approvals.
- CLI-Driven and API-Driven workflows are not the primary mode for this setup.

## Cloud Shell first run (local state)

Backend note:

- There is no explicit backend block in `terraform-bootstrap/main.tf`.
- Terraform therefore uses the default local backend (`terraform.tfstate` in working directory).
- Local backend is used by omission until you move/import state to TFE workspace.

If you need to create the zip package first (from repo root):

```bash
zip -r gcp-bootstrap.zip . -x ".git/*" -x ".DS_Store"
```

```bash
unzip gcp-bootstrap.zip -d gcp-bootstrap
cd gcp-bootstrap/terraform-bootstrap
# create terraform.tfvars manually (see required values below)
```

Edit `terraform.tfvars` with your values:

- `project_id`
- `create_project=false` (default; use existing project)
- `create_project=true` only when you want Terraform to create project
- if `create_project=true`: prefer `folder_id`; use `org_id` only as fallback, and set `billing_account`
- `tfe_workspace_id`

Note: this repo expects key runtime settings to come from `terraform.tfvars` / workspace variables (not hidden defaults).

Personal account note:

- If you do not have a Google Organization, create a project manually in Console and keep `create_project=false`.
- If you have an Organization and later switch to `create_project=true`, you can set `org_id = "2336890507"` (or use `folder_id`).

Then run:

```bash
/usr/bin/terraform init
/usr/bin/terraform plan
/usr/bin/terraform apply
```

After this first run completes, continue with state import into the workspace created above.

## Reuse same code for dev/prod

Use separate var files per environment:

- `terraform-bootstrap/environments/dev.tfvars.example`
- `terraform-bootstrap/environments/prod.tfvars.example`

Create real files from examples (do not commit real tfvars):

```bash
cd terraform-bootstrap
cp environments/dev.tfvars.example environments/dev.tfvars
cp environments/prod.tfvars.example environments/prod.tfvars
```

Run with explicit env var file:

```bash
/usr/bin/terraform init
/usr/bin/terraform plan -var-file="environments/dev.tfvars"
/usr/bin/terraform apply -var-file="environments/dev.tfvars"
```

For prod:

```bash
/usr/bin/terraform plan -var-file="environments/prod.tfvars"
/usr/bin/terraform apply -var-file="environments/prod.tfvars"
```

## Download local state and import to Terraform workspace

From Cloud Shell (inside `terraform-bootstrap/`):

```bash
/usr/bin/terraform state pull > terraform-state-export.tfstate
ls -lah terraform-state-export.tfstate
```

Download `terraform-state-export.tfstate` to your PC (Cloud Shell file browser download is fine).

Important:

- Do **not** run `/usr/bin/terraform state pull > terraform.tfstate` when using local backend.
- That can truncate/overwrite the active local state file before Terraform reads it.
- Always export to a different filename, such as `terraform-state-export.tfstate`.

Then in Terraform Cloud/Enterprise workspace:

- Settings -> State Versions -> Upload
- upload `terraform-state-export.tfstate`

After upload, set workspace working directory to `terraform-bootstrap/` (if using VCS repo integration).

## After import: switch to TFE-managed runs only

1. Confirm the uploaded state is visible in workspace state versions.
2. Set all required Terraform + OIDC workspace variables.
3. Run plan/apply from TFE workspace UI.
4. Treat TFE workspace as the source of truth for state.
5. Do not run local `terraform apply` anymore unless intentionally performing another state migration.

Optional hardening:

- Restrict local write access to avoid accidental local applies.
- Keep workspace auto-apply disabled and require manual approval.

## Workspace variables for ongoing runs

### Terraform variables (workspace)

- `project_id`
- `create_project` (typically `false` after first run)
- `project_name` (optional)
- `org_id` or `folder_id` (if still needed)
- `billing_account` (if still needed)
- `tfe_workspace_id`
- optional overrides (`bootstrap_roles`, pool/provider IDs, labels)

### Environment variables for GCP OIDC (workspace)

- `TFC_GCP_PROVIDER_AUTH=true`
- `TFC_GCP_PRINCIPAL_TYPE=service_account`
- `TFC_GCP_WORKLOAD_PROVIDER_NAME=<output tfe_workload_identity_provider>`
- `TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL=<output bootstrap_service_account_email>`

## Detailed OIDC variable mapping (copy/paste checklist)

1. After first Cloud Shell apply, capture outputs:

```bash
cd terraform-bootstrap
/usr/bin/terraform output -raw tfe_workload_identity_provider
/usr/bin/terraform output -raw bootstrap_service_account_email
/usr/bin/terraform output -raw bootstrap_project_id
```

2. In TFE/TFC workspace, set the following **Environment Variables**:

- `TFC_GCP_PROVIDER_AUTH` = `true`
- `TFC_GCP_PRINCIPAL_TYPE` = `service_account`
- `TFC_GCP_WORKLOAD_PROVIDER_NAME` = value of `tfe_workload_identity_provider`
- `TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL` = value of `bootstrap_service_account_email`

3. Optional split identities (only if required by policy):

- `TFC_GCP_PLAN_SERVICE_ACCOUNT_EMAIL` = SA email for plan
- `TFC_GCP_APPLY_SERVICE_ACCOUNT_EMAIL` = SA email for apply

4. Ensure Terraform variable `tfe_workspace_id` matches the exact workspace ID (`ws-...`) running this code.

5. Keep workspace working directory set to `terraform-bootstrap/`.

6. Trigger a plan from workspace UI and confirm OIDC auth works before apply.

## Workspace settings (recommended)

Configure these in TFE/TFC workspace settings:

- Terraform working directory: `terraform-bootstrap/`
- Auto-apply: `OFF` (manual approval recommended for bootstrap/IAM changes)
- VCS trigger type: `Branch-based`
- VCS branch: your active deployment branch (`main` or `develop`, based on your process)
- Automatic run triggering: `Only trigger runs when files in specified paths change`
- Trigger paths: `terraform-bootstrap/**`
- Pull requests -> Automatic speculative plans: `ON`
- Include submodules on clone: `OFF` (enable only if your repo actually uses git submodules)

Why:

- limits accidental applies
- keeps runs focused on Terraform changes
- provides PR plan visibility before merges

## Workspace ownership and state source of truth

- Use one TFE/TFC workspace for this unified stack.
- After state upload/import, treat TFE workspace state as source of truth.
- Do not continue local applies unless you intentionally migrate state again.

## Ongoing updates from TFE/TFC UI

Use regular UI-triggered runs (plan/apply) in the workspace to update:

- project APIs in `required_services`
- IAM roles in `bootstrap_roles`
- WIF configuration and trust conditions

## WIF pool/provider ID guidance

- Do **not** change `workload_identity_pool_id` or `workload_identity_provider_id` on every run.
- Keep these IDs stable for an environment (for example dev/prod) so Terraform can manage the same objects.
- If Terraform says "already exists", it usually means resource exists in GCP but is missing in current state.
  - Preferred fix: import existing resource into state.
  - Use new ID only when you intentionally want a new pool/provider.

Why you might intentionally create a new ID (for example `tfe-pool-dev-2` / `tfe-provider-dev-2`):

- previous ID is stuck in deleted/tombstoned state and cannot be imported
- previous object exists outside Terraform state and recovery/import is blocked
- you need a fast recovery path to continue bootstrap without waiting on ID reuse lifecycle

## Destroy guidance

If state is now in Terraform workspace, perform destroy from workspace UI.
If state is still local, destroy from the same local directory/context used for apply.

## Check state and destroy runbook

From `terraform-bootstrap/`:

```bash
/usr/bin/terraform state list
/usr/bin/terraform state list | wc -l
```

- If count is `0`, no resources are tracked in current state.
- If count is greater than `0`, destroy will target those tracked resources.

Optional: backup state before destroy:

```bash
/usr/bin/terraform state pull > terraform-state-backup.tfstate
```

Destroy local-state resources (dev example):

```bash
/usr/bin/terraform destroy -var-file="environments/dev.tfvars"
```

Verify state is empty after destroy:

```bash
/usr/bin/terraform state list | wc -l
```

For TFE-managed state:

- Run destroy from TFE workspace UI (same workspace that owns the state).

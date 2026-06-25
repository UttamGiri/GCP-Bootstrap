# TFE Workspace Environments

This folder contains separate Terraform root modules for TFE/TFC workspaces.

```text
tfe-workspace/
  envs/
    dev/
    prod/
  modules/
    gcs-buckets/
```

Each environment folder is a separate TFE working directory. It currently creates one GCP storage bucket. In GCP this is a **GCS bucket**; it is the GCP equivalent of an S3 bucket.

## Infrastructure Belongs In Code

Do not add each bucket, VPC, subnet, or firewall rule as TFE workspace variables.

Add environment-specific infrastructure in the environment folder:

```text
tfe-workspace/envs/dev/main.tf
tfe-workspace/envs/prod/main.tf
```

For example, add another dev bucket in `tfe-workspace/envs/dev/main.tf`:

```hcl
module "storage_buckets" {
  # ...

  buckets = {
    state = {
      # existing dev bucket
    }

    logs = {
      name               = "bootstrap-prj-500323-tfe-dev-logs"
      location           = "US"
      force_destroy      = false
      versioning_enabled = true
    }
  }
}
```

Later, add VPC resources directly in Terraform code, for example `google_compute_network`, `google_compute_subnetwork`, and firewall resources.

## How Authentication Works

The `tfe-dev` workspace does not authenticate by checking its own Terraform state.

TFE authenticates to GCP before Terraform runs by using workspace environment variables:

- `TFC_GCP_PROVIDER_AUTH=true`
- `TFC_GCP_PRINCIPAL_TYPE=service_account`
- `TFC_GCP_WORKLOAD_PROVIDER_NAME=<bootstrap workspace output tfe_workload_identity_provider>`
- `TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL=<bootstrap workspace output bootstrap_service_account_email>`

The bootstrap workspace must also trust the `tfe-dev` workspace ID by setting:

```hcl
additional_tfe_workspace_ids = [
  "ws-xxxxxxxxxxxxxxxx"
]
```

Then run `apply` in the bootstrap workspace before running this workspace.

## What Terraform Checks

For the bucket, Terraform checks the **state of this `tfe-dev` workspace**.

- If the bucket is in this workspace state, Terraform refreshes it against GCP.
- If the state is empty, Terraform plans to create the bucket.
- If the state is empty but the bucket already exists in GCP, apply can fail with an already-exists conflict. Import the bucket into this workspace state before applying.

The bootstrap workspace state is used only to read outputs like the bootstrap project, service account, and WIF provider.

## TFE Workspace Settings

Create separate workspaces:

```text
tfe-dev  -> working directory tfe-workspace/envs/dev
tfe-prod -> working directory tfe-workspace/envs/prod
```

Recommended settings:

- **Execution mode:** Remote
- **Working directory:** `tfe-workspace/envs/dev` or `tfe-workspace/envs/prod`
- **Remote state sharing:** allow access to the bootstrap workspace outputs
- **Auto-apply:** Off

No Terraform variables are required for bucket names or bucket settings. Those values are in the environment code.

## Required Bootstrap Output Access

This configuration reads:

```hcl
data "terraform_remote_state" "bootstrap"
```

The bootstrap workspace must share state with this workspace. In TFE/TFC, enable remote state sharing from `bootstrap-dev` to `tfe-dev`.

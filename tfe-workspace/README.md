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
- `TFC_GCP_WORKLOAD_PROVIDER_NAME=<bootstrap output tfe_workload_identity_provider>`
- `TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL=<bootstrap output bootstrap_service_account_email>`

First run:

- `GCP-tfe-workspace` uses the bootstrap service account from `GCP-Bootstrap`.
- It creates its own workspace service account and WIF pool/provider.
- It outputs `workspace_service_account_email` and `workspace_workload_identity_provider`.

Consecutive runs:

- Update `GCP-tfe-workspace` environment variables to use its own outputs:

```text
TFC_GCP_WORKLOAD_PROVIDER_NAME=<workspace output workspace_workload_identity_provider>
TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL=<workspace output workspace_service_account_email>
```

- Keep `TFC_GCP_PROVIDER_AUTH=true`.
- Keep `TFC_GCP_PRINCIPAL_TYPE=service_account`.

Important: Terraform cannot switch these auth values during the same run because TFE reads them before Terraform starts.

The bootstrap WIF provider must also trust the `tfe-dev` workspace ID. If it only trusts the bootstrap workspace ID, apply fails with:

```text
oauth2/google: status code 400: {"error":"unauthorized_client","error_description":"The given credential is rejected by the attribute condition."}
```

Fix:

1. Copy the `tfe-dev` workspace ID from TFE workspace settings.
2. Add it to the bootstrap dev environment code:

```hcl
additional_tfe_workspace_ids = [
  "ws-2UNjJ7BXhV5ZnrAG"
]
```

3. Update bootstrap WIF trust by applying the bootstrap workspace.
4. Re-run this workspace.

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
- **Remote state sharing:** allow this workspace to read the matching bootstrap workspace outputs
- **Auto-apply:** Off

No Terraform variables are required for bucket names or bucket settings. Those values are in the environment code.

This configuration uses its own TFE workspace state for managed resources, but reads bootstrap outputs with `terraform_remote_state`.

Remote state access:

- `tfe-dev` reads outputs from `GCP-Bootstrap`
- `tfe-prod` reads outputs from `bootstrap-prod`

In the bootstrap workspace settings, allow the workload workspace as an authorized remote state consumer.

If this is missing, the workload run fails with:

```text
Error retrieving state: forbidden
This Terraform run is not authorized to read the state of the workspace 'GCP-Bootstrap'.
```

Fix in TFE:

1. Open the matching bootstrap workspace, for example `GCP-Bootstrap`.
2. Go to **Settings -> General -> Remote state sharing**.
3. Choose **Share with specific workspaces**.
4. Add the workload workspace, for example `GCP-tfe-workspace`.
5. Save and re-run the workload workspace.

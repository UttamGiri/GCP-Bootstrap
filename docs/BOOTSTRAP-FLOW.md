# GCP Bootstrap Flow (Unified Stack)

```mermaid
flowchart TD broken badly badly
    A[Bootstrap repo zip or git source]
    A --> B[Open Google Cloud Shell]
    B --> C[unzip/clone repo]
    C --> D[cd terraform-bootstrap/envs/dev]
    D --> E[terraform init plan apply with local state]

    E --> P[Create bootstrap project under org/folder]
    E --> S[Create bs-tfe-sa and project IAM roles]
    E --> W[Create WIF pool/provider and workspace trust]
    E --> API[Enable required project APIs]

    E --> L[Local terraform.tfstate in Cloud Shell]
    L --> DL[Download state file to personal PC]
    DL --> UP[Upload state into TFE workspace]

    UP --> TV[Set Terraform variables in workspace]
    UP --> EV[Set TFC_GCP_* OIDC environment variables]
    TV --> RUN[Run plan/apply from TFE workspace UI]
    EV --> RUN

    RUN --> U[Future updates: APIs roles OIDC config]
```

## Step-by-step instructions

1. Create Terraform workspace in TFE/TFC and copy workspace ID (`ws-xxxxxxxxxxxxxxxx`).
2. Run unified stack from Cloud Shell using local state:
   - `unzip gcp-bootstrap.zip -d gcp-bootstrap`
   - `cd gcp-bootstrap/terraform-bootstrap/envs/dev`
   - review environment values in `main.tf`
   - `/usr/bin/terraform init`
   - `/usr/bin/terraform plan`
   - `/usr/bin/terraform apply`
3. Export local state:
   - `/usr/bin/terraform state pull > terraform-state-export.tfstate`
4. Download `terraform-state-export.tfstate` to your PC.
5. In TFE workspace UI, upload this state file (State Versions -> Upload).
6. Configure workspace variables:
   - Terraform vars from your tfvars
   - OIDC env vars:
     - `TFC_GCP_PROVIDER_AUTH=true`
     - `TFC_GCP_PRINCIPAL_TYPE=service_account`
     - `TFC_GCP_WORKLOAD_PROVIDER_NAME=<output tfe_workload_identity_provider>`
     - `TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL=<output bootstrap_service_account_email>`
7. Run from TFE workspace UI for future changes (APIs, roles, OIDC updates).

## Notes

- No manual bootstrap project creation is required when `create_project=true`.
- No local TFE authentication is required for initial Cloud Shell run.
- Do not commit `.tfstate` to Git.

# Workspace Identity (WIF + Service Account)

This module creates **machine identity** for one Terraform Cloud / Enterprise (TFE) workspace to authenticate to GCP without JSON keys.

It does **not** manage human SSO users, TFE team permissions, or application workloads (buckets, VPC, etc.).

## What gets created

For each TFE workspace that calls this module:

| Resource | Purpose |
|----------|---------|
| `google_service_account` | GCP identity Terraform runs as |
| `google_project_iam_member` | Project roles on that SA |
| `google_iam_workload_identity_pool` | Trust boundary for external OIDC |
| `google_iam_workload_identity_pool_provider` | Trusts TFE issuer (`https://app.terraform.io`) |
| `google_service_account_iam_member` | Lets WIF impersonate the SA (`workloadIdentityUser`) |

**Rule:** one TFE workspace → one service account → one WIF pool/provider pair.

The WIF provider uses an attribute condition so only the configured TFE workspace ID can impersonate the SA:

```hcl
attribute_condition = "assertion.terraform_workspace_id == '${var.workspace_id}'"
```

## Workload Identity Federation (WIF) in plain terms

Without WIF, TFE would store a long-lived GCP service account key. WIF replaces that:

```text
TFE run starts
  → TFE reads TFC_GCP_* workspace env vars
  → TFE presents a short-lived OIDC token to GCP
  → WIF pool validates token + workspace ID
  → GCP issues credentials as the target service account
  → Terraform provider talks to GCP APIs
```

Required TFE workspace environment variables:

| Variable | Example purpose |
|----------|-----------------|
| `TFC_GCP_PROVIDER_AUTH` | `true` — enable dynamic GCP auth |
| `TFC_GCP_PRINCIPAL_TYPE` | `service_account` |
| `TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL` | SA email to impersonate |
| `TFC_GCP_WORKLOAD_PROVIDER_NAME` | Full WIF provider resource name |

Terraform cannot change these during a run; TFE resolves them **before** `terraform plan`.

## Bootstrap vs workload identity (two layers)

This repo uses two separate identity stacks:

```text
GCP project (e.g. bootstrap-prj-501802)
│
├── Bootstrap layer          TFE: GCP-Vaflt-Bootstrap
│     SA:   bs-tfe-sa
│     WIF:  tfe-pool-dev-3 / tfe-provider-dev-3
│     Code: terraform-bootstrap/
│
└── Workload layer           TFE: GCP-vaflt-tfe-workspace (dev)
      SA:   gcp-tfe-workspace-sa-<suffix>
      WIF:  tfe-workspace-pool-<suffix> / tfe-workspace-provider-<suffix>
      Code: tfe-workspace/ (this module)
```

| Phase | Authenticates as | Why |
|-------|------------------|-----|
| Workload **first apply** | Bootstrap SA + bootstrap WIF | Workload SA/WIF do not exist yet |
| Workload **after sync auth** | Workload SA + workload WIF | Least privilege; bootstrap only for bootstrapping |

GitHub Actions:

- **Bump Bootstrap Auth** — copies bootstrap SA/WIF into workload workspace env vars (first run / reset).
- **TFE Sync Workload Auth** — copies workload outputs into its own env vars (steady state).

## Destroy order

Identity is created first and destroyed **last** so the service account can still delete buckets, WIF, and other resources during `terraform destroy`:

```text
Create:  SA → project IAM → WIF pool → WIF provider → impersonation binding
Destroy: workload resources → impersonation → provider → pool → project IAM → SA
```

`workload-project` creates identity first; destroy order matters when teams manage resources in their own repos.

## `resource_suffix`

WIF pool and provider IDs must be unique within a GCP project. If a partial apply/destroy leaves orphans, bump `resource_suffix` in the env root (e.g. `8` → `9`) to create a fresh pool/provider. This is separate from `bucket_suffix` (GCS names are globally unique).

## Where to put roles and privileges

There are **three different** access layers. Do not mix them in this module.

### 1. TFE machine identity — bootstrap SA roles

**What:** Roles for the bootstrap service account (creates projects, bootstraps other workspaces).

**Where:**

```text
terraform-bootstrap/envs/dev/main.tf   → bootstrap_roles
terraform-bootstrap/envs/prod/main.tf    → bootstrap_roles
```

**Not** in `workspace-identity/`.

### 2. TFE machine identity — workload SA roles

**What:** Roles for each TFE workload workspace SA (storage, IAM admin for its own resources, etc.).

**Where:** passed via `workload-project` from `platform-layout` (`service_account_roles` in the map or defaults).

**Where (recommended):** env root so dev and prod can differ:

```text
tfe-workspace/envs/dev/main.tf   → service_account_roles for dev
tfe-workspace/envs/prod/main.tf  → service_account_roles for prod
```

This module only **applies** the list; it does not choose which roles belong to which environment.

### 3. Human SSO / user access (different concern)

**What:** Google Workspace / Cloud Identity users or groups (`user@vaflt.com`, `group:gcp-admins@vaflt.com`) getting console or gcloud access — **not** TFE runs.

**Where:** **not** this module and **not** the same folder as WIF unless you only have a tiny setup.

Use a separate area when you add it, for example:

```text
iam/                          # or security/iam/ — new root, optional future repo
  envs/
    org/                      # org/folder-level bindings
    dev/
    prod/
  modules/
    project-iam/              # human group → role bindings
    custom-roles/
```

Or manage org-level human IAM in a dedicated **org / security** Terraform workspace, separate from bootstrap and workload.

**Why separate:**

| | TFE WIF (this module) | Human SSO IAM |
|--|----------------------|---------------|
| Principal | Service account via OIDC | Users / groups |
| Lifecycle | Per TFE workspace | Per person / team |
| Change frequency | Infra bootstrap | HR / access requests |
| Repo / state | `tfe-workspace` | Usually different workspace |

### 4. TFE organization / team permissions

**What:** Who can approve runs, change variables, or access workspace settings in Terraform Cloud.

**Where:** TFE UI or `tfe` provider in a **platform** workspace — not GCP IAM, not this module.

## Module inputs (summary)

| Variable | Set by | Notes |
|----------|--------|-------|
| `project_id` | Env root | GCP project where SA + WIF live |
| `workspace_id` | Env root | TFE workspace ID (`ws-...`) |
| `service_account_id` | `workload-project` / platform map | Per team |
| `workload_identity_pool_id` | `workload-project` / platform map | Per team |
| `workload_identity_provider_id` | `workload-project` / platform map | Per team |

## Outputs

| Output | Used for |
|--------|----------|
| `service_account_email` | `TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL` after sync |
| `workload_identity_provider` | `TFC_GCP_WORKLOAD_PROVIDER_NAME` after sync |

## Related docs

- [tfe-workspace/README.md](../../README.md) — auth flow and env layout
- [docs/BOOTSTRAP-FLOW.md](../../../docs/BOOTSTRAP-FLOW.md) — first-time bootstrap
- [docs/DAILY-WORKSPACE-FLOW.md](../../../docs/DAILY-WORKSPACE-FLOW.md) — day-2 operations and destroy order

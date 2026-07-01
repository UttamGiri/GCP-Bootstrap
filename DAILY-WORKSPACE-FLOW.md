<div style="font-size: 22px; line-height: 1.6;">

# Daily Workload Workspace Flow

This flow shows the handoff model where the first workload run uses the bootstrap service account, then the workload workspace creates its own service account and uses that identity for later runs.

---

## High-Level Goal

The goal is to support a daily destroy/recreate workflow without destroying the bootstrap identity path.

There are two identity phases:

- **Bootstrap identity phase:** `GCP-tfe-workspace` uses `bs-tfe-sa` and the bootstrap WIF provider for the first run.
- **Workload identity phase:** `GCP-tfe-workspace` switches to its own service account and its own WIF provider for later runs.

Terraform cannot automatically switch identities inside one run because TFE injects `TFC_GCP_*` environment variables before Terraform starts. The handoff therefore happens between runs.

---

## Diagram 1 — Bootstrap (persistent)

```mermaid
%%{init: {'themeVariables': {'fontSize': '22px'}}}%%
flowchart TB
    B1["GCP-Bootstrap workspace"]
    B2["terraform-bootstrap/envs/dev"]
    B3["Creates bs-tfe-sa"]
    B4["Creates bs WIF pool/provider"]
    B5["Trusts GCP-tfe-workspace"]
    B6["Shares outputs + state"]

    B1 --> B2
    B2 --> B3
    B2 --> B4
    B2 --> B5
    B2 --> B6
```

---

## Diagram 2 — First run (uses bootstrap SA)

```mermaid
%%{init: {'themeVariables': {'fontSize': '22px'}}}%%
flowchart TB
    A1["GCP-tfe-workspace env"]
    A2["Use bs-tfe-sa"]
    A3["Use bootstrap WIF provider"]
    W1["Read bootstrap outputs"]
    W2["Create gcp-tfe-workspace-sa"]
    W3["Create workload WIF pool/provider"]
    W4["Create bucket / VPC / app infra"]
    W5["Output workspace SA + WIF provider"]

    A1 --> A2
    A1 --> A3
    A2 --> W1
    A3 --> W1
    W1 --> W2
    W2 --> W3
    W3 --> W4
    W4 --> W5
```

---

## Diagram 3 — Later runs (uses own SA)

```mermaid
%%{init: {'themeVariables': {'fontSize': '22px'}}}%%
flowchart TB
    R1["Update TFE env vars"]
    R2["TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL = workspace SA"]
    R3["TFC_GCP_WORKLOAD_PROVIDER_NAME = workspace WIF provider"]
    R4["Plan / Apply"]
    R5["Modify workload resources"]

    R1 --> R2
    R1 --> R3
    R2 --> R4
    R3 --> R4
    R4 --> R5
```

---

## Diagram 4 — Daily lifecycle

```mermaid
%%{init: {'themeVariables': {'fontSize': '22px'}}}%%
flowchart LR
    D1["Morning apply"] --> D2["Resources created"]
    D2 --> D3["Daytime changes"]
    D3 --> D4["Night destroy"]
    D4 --> D5["Resources destroyed"]
    D5 --> D6["Keep workload SA + WIF"]
    D6 --> D1
```

---

## Key Rule

`GCP-tfe-workspace` can use `bs-tfe-sa` for the first run, create its own workload service account, and then use the workload service account for later runs.

---

## First Run Setup

In `GCP-tfe-workspace`, use bootstrap identity values:

<pre style="font-size: 20px;">
TFC_GCP_PROVIDER_AUTH=true
TFC_GCP_PRINCIPAL_TYPE=service_account
TFC_GCP_WORKLOAD_PROVIDER_NAME=&lt;GCP-Bootstrap output tfe_workload_identity_provider&gt;
TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL=&lt;GCP-Bootstrap output bootstrap_service_account_email&gt;
</pre>

The first run creates:

- workload service account, for example `gcp-tfe-workspace-sa`
- workload WIF pool/provider, for example `tfe-workspace-pool` / `tfe-workspace-provider`
- impersonation binding for workspace `ws-2UNjJ7BXhV5ZnrAG`
- workload resources such as buckets, VPCs, and application infrastructure

The first run outputs:

<pre style="font-size: 20px;">
workspace_service_account_email
workspace_workload_identity_provider
</pre>

---

## Handoff After First Run

After the first successful apply, update the `GCP-tfe-workspace` environment variables:

<pre style="font-size: 20px;">
TFC_GCP_WORKLOAD_PROVIDER_NAME=&lt;workspace output workspace_workload_identity_provider&gt;
TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL=&lt;workspace output workspace_service_account_email&gt;
</pre>

Keep these unchanged:

<pre style="font-size: 20px;">
TFC_GCP_PROVIDER_AUTH=true
TFC_GCP_PRINCIPAL_TYPE=service_account
</pre>

After this handoff, normal plans and applies use the workload workspace identity, not `bs-tfe-sa`.

---

## Daily Destroy And Rebuild

Daily destroy should remove only workload resources that are safe to recreate.

**Safe to destroy daily:**

- buckets used only for test/demo workload data
- VPC/subnets/firewalls for ephemeral environments
- application infrastructure

**Do not destroy** unless you intentionally want to repeat the bootstrap-identity handoff:

- `gcp-tfe-workspace-sa`
- `tfe-workspace-pool`
- `tfe-workspace-provider`
- impersonation binding for the TFE workspace

If those identity resources are destroyed, the next run cannot authenticate with the workload identity. Switch the TFE environment variables back to bootstrap values and run the first-run flow again.

---

## Important Limitation

- TFE chooses `TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL` before Terraform starts.
- Terraform cannot automatically switch from `bs-tfe-sa` to the workload service account inside the same run.
- After the first run creates the workload service account, update the TFE workspace environment variable to use that workload service account for later runs.

---

## Failure Modes

**WIF rejected:**

<pre style="font-size: 20px;">
The given credential is rejected by the attribute condition
</pre>

The WIF provider being used does not trust the current TFE workspace ID.

**Remote state forbidden:**

<pre style="font-size: 20px;">
Error retrieving state: forbidden
</pre>

`GCP-Bootstrap` has not shared remote state with `GCP-tfe-workspace`.

**After destroy:**

If later runs fail after a destroy, check whether the workload service account or workload WIF provider was destroyed. If yes, switch back to bootstrap identity for one run and recreate the workload identity.

</div>

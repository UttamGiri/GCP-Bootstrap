# TFE → GitHub Webhook Bridge

Cloud Function that receives **Terraform Enterprise** `run:completed` notifications and triggers GitHub **TFE Webhook Router**:

- successful **apply** → `tfe-workload-applied` → sync workload auth
- successful **destroy** → `tfe-workload-destroyed` → copy bootstrap auth

Deployed from **GCP-Bootstrap** so it survives daily workload destroys.

## Deploy

In **GCP-Bootstrap** workspace, set Terraform variables (sensitive):

| Variable | Description |
|----------|-------------|
| `bridge_github_pat` | GitHub fine-grained PAT — **Actions + Contents** on `UttamGiri/GCP-Bootstrap` |
| `bridge_tfe_token` | TFE API token (same as GitHub secret `TFE_TOKEN`) |
| `bridge_tfe_webhook_secret` | Random string — also used as TFE notification **Token** |

Apply **GCP-Bootstrap**. Copy output `tfe_github_bridge_webhook_url`.

## TFE notification — Completed only

**GCP-tfe-workspace** → **Settings** → **Notifications** → edit `github_call_webhook`:

| Field | Value |
|-------|--------|
| **Destination** | Webhook |
| **Webhook URL** | Output `tfe_github_bridge_webhook_url` (Cloud Function — **not** GitHub API) |
| **Token** | Same as `bridge_tfe_webhook_secret` |
| **Run Events** | **Only certain events** → enable **`Completed`** only |

Leave **Created**, **Planning**, **Applying**, **Needs attention**, and **Errored** **unchecked**.

TFE calls the webhook when a run **finishes** (apply or destroy). The function checks success and routes apply vs destroy to GitHub.

## GitHub

Repo secret `TFE_TOKEN` = same TFE API token used by the bridge.

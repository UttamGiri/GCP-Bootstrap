# Terraform Bootstrap

Bootstrap is split into environment roots and a shared module:

```text
terraform-bootstrap/ 
  envs/
    dev/
    prod/
  modules/
    bootstrap/
```

TFE workspace working directories:

```text
GCP-Vaflt-Bootstrap  -> terraform-bootstrap/envs/dev
bootstrap-prod       -> terraform-bootstrap/envs/prod
```

Environment-specific values are code-owned in each `envs/*/main.tf`. Do not put bootstrap infrastructure inventory in TFE workspace variables.

The `envs/dev` root includes `moved` blocks to migrate existing bootstrap state from the old root configuration into `module.bootstrap` addresses without recreating resources.

`GCP-Vaflt-Bootstrap` (`ws-MqdANNRijWaRBrMj`) is the state producer for workload workspaces. If a workload workspace reads bootstrap outputs with `terraform_remote_state`, configure **GCP-Vaflt-Bootstrap** → **Settings → General → Remote state sharing** to authorize that workload workspace, for example `GCP-vaflt-tfe-workspace`.

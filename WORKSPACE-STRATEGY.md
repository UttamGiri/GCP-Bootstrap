# Workspace Strategy for GCP Bootstrap

## Why separate workspaces are better

Using separate Terraform workspaces for `foundation` and `automation` is usually the safer enterprise pattern.

- **Lower blast radius**: day-2 IAM role updates cannot accidentally modify bootstrap trust resources (WIF pool/provider, core trust bindings).
- **Clear ownership**: each workspace has a focused scope and easier operational responsibility.
- **Cleaner approvals**: stricter approvals can be enforced for `foundation`, while `automation` can move faster.
- **Safer lifecycle**: `foundation` is rare/high-impact, `automation` is frequent/low-impact.
- **Easier troubleshooting**: drift and run failures are easier to isolate by workspace.
- **Predictable destroy flow**: destroy `automation` first, then `foundation`.

## Why not one workspace/state

One workspace with one state is simpler, but has tradeoffs:

- routine automation changes can touch trust/bootstrap resources
- larger plan/apply surface in every run
- harder to separate audit trail and approvals
- higher operational risk during refactors or destroy

## Cost of multiple workspaces

In most organizations, multiple workspaces are not the main cost driver.

### Direct platform cost

- **Usually low incremental cost per workspace** (depends on your TFC/TFE plan model).
- Cost is often tied more to:
  - plan tier / edition
  - user seats
  - run volume / concurrency limits
  - policy and governance features

### Operational cost

- **Slightly higher management overhead**:
  - more workspace variables to manage
  - more RBAC/policy assignments
  - naming and lifecycle governance needed

### Cloud cost impact

- **No meaningful extra GCP infra cost from workspace count itself**.
- Cloud spend is driven by resources you create, not by number of Terraform workspaces.

## Practical recommendation for this repo

Use two workspaces:

- `gcp-bootstrap-foundation` -> working directory `terraform/foundation`
- `gcp-bootstrap-automation` -> working directory `terraform/automation`

This gives strong safety boundaries with minimal extra cost and is aligned with common enterprise practice.

## Can one workspace have two states in different folders?

In Terraform Cloud/Enterprise, a single workspace cannot manage two independent state files.

- one TFE/TFC workspace = one state lineage
- changing folders in the same workspace does not create a second independent state

If you want same repo but separate states, use one of these:

- **Two TFE/TFC workspaces (recommended)**:
  - workspace A -> `terraform/foundation`
  - workspace B -> `terraform/automation`
- **External backend approach** (outside single-workspace model):
  - use GCS backend with different state keys/prefixes per stack

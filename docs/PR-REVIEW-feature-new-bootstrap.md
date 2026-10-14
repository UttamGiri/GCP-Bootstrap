# Pull request review: `feature/new-bootstrap` → `main`

**Reviewer note:** Copy this into GitHub **Pull requests → Review changes → Request changes** (or comment), or run `gh pr review` after `gh auth login`.

---

## Summary

Strong addition: Vertex PSC + **AWS→GCP WIF** for Kong IRSA, optional **workload-dev** + **shared GKE** (disabled by default), and extensive operator docs. Terraform structure and the kubernetes provider cycle fix look sound.

Please address the **required** items below before merge.

---

## Required changes

### 1. Default `aws_wif.enabled = true` in dev

` tfe-workspace/envs/dev/main.tf` enables AWS WIF on every apply, binding the Vertex client SA to an AWS role before AWS IRSA may exist.

**Fix (pick one):**

- Set `aws_wif.enabled = false` until AWS confirms `kong-ai-dev-vertex`, **or**
- Keep `true` but add a prominent comment in `main.tf` + `VERTEX-KONG-AWS-IRSA-WIF.md` that apply is intentional and locked by `attribute_condition`.

### 2. GKE API server open to the world when shared GKE is enabled

`modules/shared-gke/main.tf` uses `master_authorized_networks_config` with `0.0.0.0/0` (`temp-open-for-dev`). If someone sets `shared_gke.enabled = true` without reading docs, the control plane is exposed.

**Fix:**

- Add variable `master_authorized_networks` (list of CIDRs), default empty or office/VPN CIDRs.
- Only apply `0.0.0.0/0` when an explicit `allow_public_control_plane = true` dev flag is set.
- Document in `DESIGN-WORKLOAD-DEV-GKE.md`.

### 3. Commit history / messages

Latest commit message `git pu` and typo `worlload` in history hurt reviewability.

**Fix:**

- Squash or reword before merge (single commit or clean series).

### 4. Docs promise `gfg` Terraform that is not in this branch

`DESIGN-WORKLOAD-GFG.md` and `GEMINI-ENTERPRISE-KONG-MCP-OIDC.md` reference a **gfg** workload project, but there is no `tfe-workspace/workloads/gfg/` (or equivalent) in the PR.

**Fix (pick one):**

- Add the `gfg` workload module + `envs/dev/workload-gfg.tf` in this PR, **or**
- Mark gfg as **follow-up PR** in those docs so `main` does not imply Terraform exists.

### 5. Verify GKE RBAC + impersonation path

`shared-gke` RoleBinding uses `User` = deployer SA email. This works with impersonation + `get-credentials`, but is easy to misconfigure.

**Fix:**

- Add a **Verification** subsection to `DESIGN-WORKLOAD-DEV-GKE.md`:
  - impersonate `gke-deployer`
  - `kubectl auth can-i create deployment -n workload-dev`

---

## Suggestions (non-blocking)

| Topic | Suggestion |
|-------|------------|
| Hardcoded org/billing/AWS account in `envs/dev/main.tf` | Add `terraform.tfvars.example` or TFE variable notes for forks. |
| NAT/router on host VPC | Document cost/ownership when `shared_gke` is enabled. |
| Node `cloud-platform` scope | Consider narrowing scopes later. |
| Doc overlap | Cross-link `AWS-EKS-NAMESPACE-HELM-ACCESS.md` ↔ `DESIGN-WORKLOAD-DEV-GKE.md` at the top. |
| WIF pool IDs | Document recreate/destroy if pool name conflicts (`aws-kong-vertex`). |

---

## What looked good

- AWS WIF: single-role `attribute_condition`, reuse of Vertex client SA, good handoff docs (`VERTEX-AWS-WIF-REQUIREMENTS.md`).
- Feature flags: `workload_dev` / `shared_gke` default **false**.
- Preserving `secondary_ranges` when passing PSC subnets (required for VPC-native GKE).
- Separate GKE endpoint outputs to break provider cycle.
- `vertex_aws_wif` output for AWS team.
- Vertex test runbooks and PSC/Gemini docs.

---

## Suggested test plan (for PR author)

- [ ] `terraform validate` in `tfe-workspace/envs/dev`
- [ ] TFE plan with current flags (WIF on/off per your fix, GKE off) — no unexpected GKE/NAT
- [ ] `TEST-VERTEX.md` smoke test unchanged
- [ ] When enabling WIF E2E: `terraform output vertex_aws_wif` + AWS IRSA per docs
- [ ] Before `shared_gke.enabled = true`: Shared VPC host, secondary ranges, restricted authorized networks

---

## Verdict

**Request changes** — address items 1–4 (and 5 doc verification) then re-request review.

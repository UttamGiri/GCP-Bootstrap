# Guide: Vertex AI via Shared VPC PSC

End-to-end operator guide for what this repo deployed, how traffic flows, and
how to call Gemini / Claude from a laptop or OpenShift — both on the **public
API path** (available today) and the **private PSC path** (needs VPN later).

Companion architecture notes: [VERTEX-AI-PSC-ONPREM.md](VERTEX-AI-PSC-ONPREM.md).

**Jump to testing:** [How to test — full steps](#how-to-test--full-steps-copy-paste)

---

## How to test — full steps (copy-paste)

Your org enforces **`iam.disableServiceAccountKeyCreation`**, so you **cannot**
download a JSON key for the Vertex client SA. That is normal and secure.

For laptop testing, use **service account impersonation**: your user account
asks Google to mint a short-lived access token *as* the Vertex SA. No key file.
The call still runs as:

```text
vertex-psc-client-1@bootstrap-prj-501802.iam.gserviceaccount.com
```

| Item | Dev value |
|---|---|
| Project (billing / quota) | `bootstrap-prj-501802` |
| Service account | `vertex-psc-client-1@bootstrap-prj-501802.iam.gserviceaccount.com` |
| PSC IP (private path later) | `10.10.100.5` |
| Auth for laptop (org policy) | Impersonation — **no JSON key** |

### Step 1 — Login to Google Cloud on your laptop

```bash
gcloud auth login
gcloud config set project bootstrap-prj-501802
```

### Step 2 — Allow your user to impersonate the Vertex SA (once)

You need `roles/iam.serviceAccountTokenCreator` on the client SA (or a broader
role that includes it). Run as a project owner / IAM admin:

```bash
export CLIENT_SA=vertex-psc-client-1@bootstrap-prj-501802.iam.gserviceaccount.com
export MY_USER=$(gcloud config get-value account)

gcloud iam service-accounts add-iam-policy-binding "${CLIENT_SA}" \
  --project=bootstrap-prj-501802 \
  --member="user:${MY_USER}" \
  --role="roles/iam.serviceAccountTokenCreator"
```

Console path: **IAM & Admin → Service Accounts → `vertex-psc-client-1` →
Permissions → Grant access** → your user → role **Service Account Token Creator**.

### Step 3 — Mint a short-lived access token (as the SA)

```bash
export CLIENT_SA=vertex-psc-client-1@bootstrap-prj-501802.iam.gserviceaccount.com

TOKEN=$(gcloud auth print-access-token --impersonate-service-account="${CLIENT_SA}")
echo "token length: ${#TOKEN}"
# A real token is hundreds of characters.
```

This token is an OAuth access token for the SA. It expires in about one hour.
It is **not** stored in the repo. Do not paste it into GitHub or chat.

> Note: `vertex-sa-token.sh` needs a JSON key file. With the org policy, skip
> that script on your laptop and use `gcloud auth print-access-token
> --impersonate-service-account=...` instead.

### Step 4 — Call Gemini (public API — works today, no VPN)

```bash
export CALLING_PROJECT=bootstrap-prj-501802

curl -sS -X POST \
  "https://aiplatform.googleapis.com/v1/projects/${CALLING_PROJECT}/locations/global/publishers/google/models/gemini-2.5-pro:generateContent" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"contents":{"role":"user","parts":{"text":"Reply with exactly: OK"}}}'
```

**Pass:** JSON response with the model text (HTTP 200).  
**Fail common cases:**

| Code / message | Meaning |
|---|---|
| Impersonation permission denied | Missing Token Creator on the SA (Step 2) |
| `401` | Token expired — re-run Step 3 |
| `403` on Vertex | SA missing `roles/aiplatform.user` (Terraform should have granted this) |
| `404` | Wrong model or location |

### Step 5 — Call Claude (optional; enable Model Garden first)

In the Cloud Console for `bootstrap-prj-501802`: Vertex AI → Model Garden →
Claude Sonnet 5 → enable / accept terms.

```bash
curl -sS -X POST \
  "https://aiplatform.googleapis.com/v1/projects/${CALLING_PROJECT}/locations/global/publishers/anthropic/models/claude-sonnet-5:rawPredict" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "anthropic_version": "vertex-2023-10-16",
    "messages": [{"role":"user","content":"Reply with exactly: OK"}],
    "max_tokens": 32
  }'
```

### Step 6 — Private PSC path (later, after VPN)

Same token mint (Step 3). Traffic must resolve and route privately:

```bash
# Must print 10.10.100.5
dig +short aiplatform.googleapis.com A
nc -vz 10.10.100.5 443

# Then repeat the curl from Step 4 with a fresh TOKEN
TOKEN=$(gcloud auth print-access-token --impersonate-service-account="${CLIENT_SA}")
```

`test-vertex-psc-from-external.sh` still expects `SA_KEY_FILE`; with the org
policy, use the `gcloud` + `curl` steps above instead of that script.

### Auth options when JSON keys are blocked

| Option | Use for | Needs |
|---|---|---|
| **Impersonation** (`print-access-token --impersonate-service-account`) | Laptop testing **now** | Your user + Token Creator on SA |
| **Workload Identity Federation** | OpenShift / on-prem long term | External IdP → GCP WIF → SA |
| JSON SA key + `vertex-sa-token.sh` | Only if org grants an exception | Org policy exception |

`create_sa_key = true` in Terraform will also fail under this org policy — leave
it `false`.

### What you have vs what you do not

| Artifact | Where it lives | In GitHub? |
|---|---|---|
| SA email | GCP IAM (created by Terraform) | OK to document |
| SA JSON key | **Blocked by org policy** — do not create | **Never** |
| Impersonated access token | Shell variable `TOKEN` (~1 hour) | **Never** |
| Helper scripts | `tfe-workspace/envs/dev/scripts/` | Yes (no secrets inside) |
| TFC API token | Terraform Cloud / your password manager | **Never** |

---

## 1. What we built

One Shared VPC host project owns a single Private Service Connect (PSC) endpoint
for Google APIs. Callers do **not** get a dedicated “Vertex endpoint” resource —
Gemini and Claude are publisher models reached through
`aiplatform.googleapis.com`, which the PSC fronts.

| Resource | Value / notes (dev) |
|---|---|
| TFE org / workspace | `vaflt-org` / `GCP-vaflt-tfe-workspace` |
| Host project | Bootstrap project from remote state (`GCP-Vaflt-Bootstrap`) |
| VPC / network suffix | `vertex-psc-1` network family (`network_suffix = "1"`) |
| Subnets | `us-central1` `10.10.0.0/24` |
| **PSC endpoint IP** | **`10.10.100.5`** |
| PSC forwarding rule name | `vpsc1ep` (Google requires ≤20 chars, letters/digits only) |
| PSC target | `all-apis` |
| Private DNS zone | `googleapis.com` — only allowlisted names resolve |
| Inbound DNS policy | Present — for future on-prem / OpenShift forwarders |
| Client SA | Host SA with `roles/aiplatform.user` |
| Models intended | Gemini 2.5 Pro, Claude Sonnet 5 |
| HA VPN / Interconnect | **Not deployed** (cost control) |
| SA key in Terraform | **`create_sa_key = false`** — create keys out of band |
| Model org policy | **`enforce_model_allowlist = false`** until org-level `orgpolicy.policyAdmin` |
| Shared VPC host flag | **`enable_shared_vpc_host = false`** until org-level `compute.xpnAdmin` |

### Apply status (reference)

Successful apply after renaming the forwarding rule to `vpsc1ep`:

- Commit: `7b04c46`
- Run: `run-Kj7bfSZg4TKXpjrs`
- UI: https://app.terraform.io/app/vaflt-org/workspaces/GCP-vaflt-tfe-workspace

---

## 2. Architecture in one picture

```text
┌─────────────────────────────┐         ┌──────────────────────────────────────┐
│ Local PC / OpenShift        │         │ HOST PROJECT                         │
│                             │         │                                      │
│ 1. Sign SA JWT locally      │         │  VPC                                 │
│ 2. Resolve                  │  VPN /  │   ├─ PSC 10.10.100.5  (vpsc1ep)      │
│    aiplatform.googleapis.com│ Inter-  │   ├─ Private DNS googleapis.com      │
│    → 10.10.100.5            │ connect │   │    aiplatform → 10.10.100.5      │
│ 3. HTTPS :443 + Bearer      │ ──────► │   │    oauth2     → 10.10.100.5      │
│                             │         │   └─ Inbound DNS forwarder IPs       │
└─────────────────────────────┘         │                                      │
                                        │  PSC ══► Google backbone             │
                                        │           └─► Vertex AI               │
                                        │                ├─ Gemini 2.5 Pro     │
                                        │                └─ Claude Sonnet 5    │
                                        └──────────────────────────────────────┘
```

**Important today:** without VPN/Interconnect, your laptop cannot reach
`10.10.100.5`. You can still call Vertex on the **public** hostname with the same
JWT. PSC is ready inside GCP; the private last mile is not.

---

## 3. Two access modes

| Mode | When to use | DNS result for `aiplatform.googleapis.com` | Network path |
|---|---|---|---|
| **A. Public API + JWT** | Now, from any internet-connected PC | Public Google IPs | Internet |
| **B. PSC private path** | After VPN + DNS forwarding | **`10.10.100.5`** | Private → PSC |

Same URL shape and same auth in both modes:

```text
https://aiplatform.googleapis.com/v1/projects/CALLING_PROJECT/locations/global/...
Authorization: Bearer <token>
```

DNS + routing decide whether packets hit the public edge or `10.10.100.5`.

---

## 4. Collect Terraform outputs

In the TFE UI (workspace **Outputs**) or via CLI against the workspace state:

| Output key | Meaning |
|---|---|
| `vertex_psc.endpoint_ip` | `10.10.100.5` |
| `vertex_psc.endpoint_name` | `vpsc1ep` |
| `vertex_psc.host_client_sa` | SA email for JWT signing |
| `vertex_psc.allowed_api_hosts` | Hostnames that resolve privately |
| `vertex_psc.dns_inbound_forwarder_ips` | Targets for on-prem `googleapis.com` forwarders |
| `vertex_psc.cloud_router_name` | Empty while `enable_hybrid_router = false` |
| `vertex_psc_client_key_json` | Empty while `create_sa_key = false` |

Example shape (names may wrap under the workload module):

```bash
# If you have local remote state configured for the workspace:
terraform output -json vertex_psc | jq '{
  endpoint_ip,
  endpoint_name,
  host_client_sa,
  dns_inbound_forwarder_ips,
  allowed_api_hosts,
  allowed_models
}'
```

---

## 5. Authentication (service-account JWT)

PSC answers **where** traffic goes. The JWT answers **who** is calling.

### Scripts (local helpers — they do **not** download keys)

Neither script talks to Terraform or creates service accounts. You must already
have a JSON **key file** on disk (`gcloud iam service-accounts keys create ...`).
They only **sign a JWT** (or exchange it for an OAuth token) and call Vertex.

| Script | Role |
|---|---|
| `tfe-workspace/envs/dev/scripts/vertex-sa-token.sh` | Reads your local SA JSON key → prints a bearer token |
| `tfe-workspace/envs/dev/scripts/test-vertex-psc-from-external.sh` | Resolves API host, calls the token script, hits Gemini + Claude |

**Service account name (dev):**

```text
vertex-psc-client-1@bootstrap-prj-501802.iam.gserviceaccount.com
```

(`account_id` = `vertex-psc-client-${network_suffix}` with `network_suffix = "1"`,
project = host/bootstrap project.)

Terraform created that SA. It did **not** create a downloadable key
(`create_sa_key = false`). Create a key yourself when you need to call Vertex.

### Token modes

| Mode | Flag | Network needed for token mint | DNS allowlist need |
|---|---|---|---|
| OAuth (default for helper) | `--mode oauth` | `oauth2.googleapis.com` | Include `oauth2.googleapis.com` |
| Self-signed | `--mode self-signed` | **None** (local openssl only) | Not required for token mint |

Self-signed is preferred on the private PSC path so token mint does not depend on
the OAuth host.

```bash
cd tfe-workspace/envs/dev/scripts

# OAuth access token
TOKEN=$(./vertex-sa-token.sh --key ~/vertex-sa.json --mode oauth)

# Self-signed JWT for aiplatform
TOKEN=$(./vertex-sa-token.sh --key ~/vertex-sa.json --mode self-signed \
  --audience 'https://aiplatform.googleapis.com/')
```

### Create an SA key (required once; not in Terraform)

See **[Step 2](#step-2--create-the-service-account-key-once)** in the full
testing walkthrough above for the exact commands with this project’s SA email.

---

## 6. Mode A — call Vertex today (public path)

No VPN. Uses public DNS and the public API. Prefer the numbered walkthrough:
**[How to test — full steps](#how-to-test--full-steps-copy-paste)** (Steps 1–6).

### Claude prerequisite

In each calling project: Model Garden → Claude Sonnet 5 → enable / accept terms
→ request quota if needed. Gemini only needs the Vertex AI API + IAM.

---

## 7. Mode B — call via PSC (private path)

### Prerequisites

1. Private connectivity: HA VPN or Interconnect into the host VPC (not in this
   Terraform stack yet).
2. Advertise / route **`10.10.100.5/32`** to the caller network.
3. On-prem or OpenShift DNS: conditional forwarder for `googleapis.com` →
   `vertex_psc.dns_inbound_forwarder_ips`.
4. Optional: set `enable_hybrid_router = true` and `hybrid_source_ranges` when
   you accept hybrid cost and wire VPN outside (or in a follow-up change).

### Prove you are on PSC before calling models

From the **real** caller (laptop on VPN, or OpenShift pod):

```bash
# Expect 10.10.100.5 — NOT a public Google IP
dig +short aiplatform.googleapis.com A
# or: getent ahostsv4 aiplatform.googleapis.com
# or macOS: dscacheutil -q host -a name aiplatform.googleapis.com

nc -vz 10.10.100.5 443
```

| Check | Pass means |
|---|---|
| Resolves to `10.10.100.5` | Private DNS / forwarder is working |
| TCP 443 to `10.10.100.5` succeeds | Routing / VPN / firewall OK |
| Resolves to public IP | Still on public internet DNS — not PSC |

### Run the bundled PSC test

```bash
cd tfe-workspace/envs/dev/scripts

CALLING_PROJECT=YOUR_HOST_PROJECT_ID \
SA_KEY_FILE=~/vertex-sa.json \
PSC_IP=10.10.100.5 \
TOKEN_MODE=self-signed \
./test-vertex-psc-from-external.sh
```

The script:

1. Resolves `aiplatform.googleapis.com`
2. Optionally asserts it equals `PSC_IP`
3. Mints a JWT
4. Calls Gemini `generateContent` and Claude `rawPredict`
5. Prints `PASS` if both return HTTP 200

---

## 8. Approved API hosts and models

### DNS allowlist (private zone)

Configured in `tfe-workspace/envs/dev/main.tf`:

- `aiplatform.googleapis.com`
- `oauth2.googleapis.com`
- `sts.googleapis.com`
- Plus regional hosts derived from subnets:
  - `us-central1-aiplatform.googleapis.com`

Any other `*.googleapis.com` name gets **NXDOMAIN** inside this private zone
(no public fallback for those queries when the private zone is authoritative).

### Models

| Model | Path | Method |
|---|---|---|
| Gemini 2.5 Pro | `publishers/google/models/gemini-2.5-pro` | `:generateContent` |
| Claude Sonnet 5 | `publishers/anthropic/models/claude-sonnet-5` | `:rawPredict` |

Org-policy allowlist entries (when `enforce_model_allowlist = true`):

```text
publishers/google/models/gemini-2.5-pro:predict
publishers/anthropic/models/claude-sonnet-5:predict
```

---

## 9. OpenShift notes

```bash
# Create secret from the SA key (never bake into the image)
oc -n APP_NAMESPACE create secret generic vertex-ai-sa \
  --from-file=sa.json=/secure/sa.json

# In the pod:
export SA_KEY_FILE=/var/run/secrets/vertex/sa.json
export CALLING_PROJECT=YOUR_CALLING_PROJECT_ID
export TOKEN_MODE=self-signed
export PSC_IP=10.10.100.5
```

Mount the secret read-only. Prefer Workload Identity Federation when OpenShift
can federate to Google Cloud so you can drop long-lived keys.

DNS: configure CoreDNS / upstream resolvers to forward `googleapis.com` to the
Cloud DNS inbound forwarder IPs once VPN exists.

---

## 10. Multi-project (Shared VPC consumers)

The **one** PSC endpoint stays in the host project. Additional app projects:

1. Attach as Shared VPC service projects (needs org-level Shared VPC admin when
   enabling the host).
2. Add each under `vertex_psc.service_projects` in `envs/dev/main.tf`.
3. Enable Vertex AI API in each calling project.
4. Grant / create client SA with `roles/aiplatform.user` in that project.
5. Put the **calling project id** in the URL path
   (`/v1/projects/CALLING_PROJECT/...`) — that project is billed and
   quota-checked even though the network path is shared.

---

## 11. Terraform knobs (dev)

File: `tfe-workspace/envs/dev/main.tf` → `module.workload.vertex_psc`

| Knob | Current | Effect |
|---|---|---|
| `enabled` | `true` | Create the PSC stack |
| `psc_endpoint_ip` | `10.10.100.5` | Fixed internal VIP |
| `enable_hybrid_router` | `false` | No Cloud Router / hybrid cost |
| `create_sa_key` | `false` | No private key in TFE state |
| `enforce_model_allowlist` | `false` | DNS+IAM only until org policy admin |
| `enable_shared_vpc_host` | `false` | Manual/org Shared VPC enable if needed |
| `service_projects` | `{}` | No attached consumers yet |

Code layout:

```text
tfe-workspace/envs/dev/main.tf          # wiring + flags
tfe-workspace/modules/workload-stack/   # stack entry
tfe-workspace/modules/workload-resources/
tfe-workspace/modules/vertex-psc/       # VPC, PSC, DNS, SA, optional policy
tfe-workspace/envs/dev/scripts/         # token + external test helpers
```

---

## 12. Cost notes (why VPN is off)

Rough low-cost posture for a short test:

- PSC endpoint + private DNS + inbound policy: on the order of a few dollars for
  several days.
- HA VPN tunnels: ~$0.05/hr **each**, plus traffic — intentionally omitted.

Destroy the workspace when the test is done if you do not need the endpoint to
keep running.

---

## 13. Troubleshooting

| Symptom | Likely cause | What to do |
|---|---|---|
| Hostname → public IP | Not using Cloud DNS forwarder | Fix on-prem/OpenShift DNS; confirm VPN |
| Hostname NXDOMAIN | Host missing from allowlist | Add to `allowed_api_hosts` and apply |
| TCP timeout to `10.10.100.5` | No VPN / route / firewall | Complete hybrid connectivity |
| `401 UNAUTHENTICATED` | Bad JWT, clock skew, deleted key | Retry `--mode oauth`; check key and time |
| `403 Permission denied` | Missing `roles/aiplatform.user` | Grant on SA in `CALLING_PROJECT` |
| Claude-only `403` | Model Garden not enabled | Enable Claude in that project |
| `404` model / location | Wrong region or model id | Use `locations/global` and names above |
| PSC create error on name | Name has `-` or >20 chars | Use pattern like `vpsc${suffix}ep` |
| Cannot create SA key | Org constraint | Use WIF instead of JSON keys |
| Cannot set Shared VPC / org policy at project | Roles invalid at project scope | Grant `xpnAdmin` / `orgpolicy.policyAdmin` at folder or org |

---

## 14. Quick decision tree

```text
Can you reach 10.10.100.5:443 from the caller?
 ├─ YES, and DNS = 10.10.100.5
 │    → Use Mode B (PSC). Prefer TOKEN_MODE=self-signed.
 └─ NO
      → Use Mode A (public API + JWT) for functional tests.
         PSC is deployed but not on your network path yet.
```

---

## 15. Security checklist

- [ ] Treat any TFC / SA token pasted in chat as compromised — rotate it.
- [ ] `chmod 600` on SA JSON keys; never commit keys.
- [ ] Prefer WIF for OpenShift over downloadable keys.
- [ ] Keep `create_sa_key = false` unless you accept keys in TFE state.
- [ ] Do not widen `allowed_api_hosts` without review (same PSC fronts all Google APIs).
- [ ] When ready, turn on `enforce_model_allowlist` with org-level policy admin.

---

## 16. References

- [Access Google APIs through PSC](https://cloud.google.com/vpc/docs/configure-private-service-connect-apis)
- [Shared VPC](https://cloud.google.com/vpc/docs/shared-vpc)
- [Cloud DNS inbound forwarding](https://cloud.google.com/dns/docs/policies)
- [Claude on Vertex AI](https://cloud.google.com/vertex-ai/generative-ai/docs/partner-models/use-claude)
- [Service account JWT / OAuth](https://developers.google.com/identity/protocols/oauth2/service-account)
- [AIP-4111 self-signed JWT](https://google.aip.dev/auth/4111)
- Repo architecture: [VERTEX-AI-PSC-ONPREM.md](VERTEX-AI-PSC-ONPREM.md)

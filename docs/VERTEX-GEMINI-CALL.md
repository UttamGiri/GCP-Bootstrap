# Vertex call path: DNS → PSC mapping + working Gemini test

How `aiplatform.googleapis.com` is mapped to the PSC endpoint, and the exact
commands that successfully called **Gemini 2.5 Pro** from a laptop (public path
today; same URL over VPN later).

---

## 1. Working Gemini call (copy-paste)

This is the call that worked. It uses **SA impersonation** (no JSON key) and the
**public** API path (not PSC yet — no VPN).

```bash
export CLIENT_SA=vertex-psc-client-1@bootstrap-prj-501802.iam.gserviceaccount.com

TOKEN=$(gcloud auth print-access-token --impersonate-service-account="${CLIENT_SA}")

curl -sS -X POST \
  "https://aiplatform.googleapis.com/v1/projects/bootstrap-prj-501802/locations/global/publishers/google/models/gemini-2.5-pro:generateContent" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"contents":{"role":"user","parts":{"text":"Reply with exactly: OK"}}}'
```

**Pass:** JSON with `"text": "OK"`.

| Prerequisite | Detail |
|---|---|
| `gcloud auth login` | Your user |
| Token Creator on the SA | Once: `roles/iam.serviceAccountTokenCreator` for your user on `CLIENT_SA` |
| Project | `bootstrap-prj-501802` |

Grant Token Creator if needed:

```bash
export CLIENT_SA=vertex-psc-client-1@bootstrap-prj-501802.iam.gserviceaccount.com
export MY_USER=$(gcloud config get-value account)

gcloud iam service-accounts add-iam-policy-binding "${CLIENT_SA}" \
  --project=bootstrap-prj-501802 \
  --member="user:${MY_USER}" \
  --role="roles/iam.serviceAccountTokenCreator"
```

---

## 2. Where hostname → PSC IP is mapped

You always call:

```text
https://aiplatform.googleapis.com/...
```

You do **not** put `10.10.100.5` in the URL. DNS decides whether that hostname
is public Google or the PSC VIP.

### Mapping (private Cloud DNS)

```text
aiplatform.googleapis.com     →  A  →  10.10.100.5
oauth2.googleapis.com         →  A  →  10.10.100.5
sts.googleapis.com            →  A  →  10.10.100.5
us-central1-aiplatform...     →  A  →  10.10.100.5   (auto from subnet)
```

| Piece | Where |
|---|---|
| PSC IP `10.10.100.5` | `tfe-workspace/envs/dev/main.tf` → `psc_endpoint_ip` |
| Allowed hostnames | same file → `allowed_api_hosts` |
| DNS A records | `tfe-workspace/modules/vertex-psc/main.tf` → `google_dns_record_set.allowed_api` |
| PSC forwarding rule | same module → `vpsc1ep` |
| Console | Network Services → Cloud DNS → private zone for `googleapis.com` |

Terraform that creates the A records:

```hcl
# tfe-workspace/modules/vertex-psc/main.tf
resource "google_dns_record_set" "allowed_api" {
  for_each     = local.allowed_api_hosts
  name         = "${each.value}."
  type         = "A"
  rrdatas      = [google_compute_global_address.psc.address]  # 10.10.100.5
}
```

Configured hosts in dev:

```hcl
# tfe-workspace/envs/dev/main.tf
psc_endpoint_ip = "10.10.100.5"
allowed_api_hosts = [
  "aiplatform.googleapis.com",
  "oauth2.googleapis.com",
  "sts.googleapis.com",
]
```

---

## 3. Public today vs PSC after VPN

Same Gemini `curl` and same `TOKEN`. Only DNS + routing change.

| | Laptop today (what worked) | After VPN |
|---|---|---|
| URL | `https://aiplatform.googleapis.com/...` | **Same URL** |
| DNS result | Public Google IPs | **`10.10.100.5`** |
| Path | Internet | VPN → Shared VPC → PSC `vpsc1ep` |
| Auth | Impersonation token | Same |

Prove PSC path later:

```bash
dig +short aiplatform.googleapis.com A
# expect: 10.10.100.5

nc -vz 10.10.100.5 443
# then re-run the Gemini curl above
```

---

## 4. Client SA

```text
vertex-psc-client-1@bootstrap-prj-501802.iam.gserviceaccount.com
```

```bash
gcloud iam service-accounts list \
  --project=bootstrap-prj-501802 \
  --filter='email:vertex-psc-client'
```

No JSON key (org policy). Impersonation only for laptop tests.

---

## 5. Related docs

| Doc | Use |
|---|---|
| [TEST-VERTEX.md](TEST-VERTEX.md) | Full test runbook (Gemini, Claude, scripts) |
| [GUIDE-VERTEX.md](GUIDE-VERTEX.md) | Operator guide |
| [VERTEX-AI-PSC-ONPREM.md](VERTEX-AI-PSC-ONPREM.md) | Architecture |

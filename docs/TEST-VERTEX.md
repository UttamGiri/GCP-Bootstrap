# Test Vertex AI — one-page runbook

Everything you need to test Gemini / Claude from your laptop against this
project. Copy-paste ready.

Related deeper docs: [GUIDE-VERTEX.md](GUIDE-VERTEX.md) ·
[VERTEX-AI-PSC-ONPREM.md](VERTEX-AI-PSC-ONPREM.md) ·
[VERTEX-KONG-AWS-IRSA-WIF.md](VERTEX-KONG-AWS-IRSA-WIF.md) (Kong on AWS, not implemented)

---

## Facts (dev)

| Item | Value |
|---|---|
| Project | `bootstrap-prj-501802` |
| Client SA | `vertex-psc-client-1@bootstrap-prj-501802.iam.gserviceaccount.com` |
| PSC endpoint IP | `10.10.100.5` (created; **not used** from laptop without VPN) |
| SA JSON keys | **Blocked** by org policy — use impersonation |
| What worked in our tests | **Gemini 2.5 Pro only** |
| Claude Sonnet 5 / 4.5 | Auth OK, but **429 quota** until Console increase |

---

## Scripts in this repo

| Script | Path | When to use |
|---|---|---|
| `vertex-sa-token.sh` | `tfe-workspace/envs/dev/scripts/vertex-sa-token.sh` | Mint token from a **JSON key file** — **blocked in your org** |
| `test-vertex-psc-from-external.sh` | `tfe-workspace/envs/dev/scripts/test-vertex-psc-from-external.sh` | End-to-end Gemini+Claude using a key file + DNS check — **needs key**; skip for now |

**What you should run today:** `gcloud` impersonation + `curl` (below).  
The shell scripts stay for later if keys or WIF key-like creds become available.

---

## A) Full test (works today) — impersonation + Gemini

### 1. Login

```bash
gcloud auth login
gcloud config set project bootstrap-prj-501802
```

### 2. Grant Token Creator once (if not already done)

```bash
export CLIENT_SA=vertex-psc-client-1@bootstrap-prj-501802.iam.gserviceaccount.com
export MY_USER=$(gcloud config get-value account)

gcloud iam service-accounts add-iam-policy-binding "${CLIENT_SA}" \
  --project=bootstrap-prj-501802 \
  --member="user:${MY_USER}" \
  --role="roles/iam.serviceAccountTokenCreator"
```

Wait 1–2 minutes after the first grant if impersonation fails immediately.

### 3. Mint token (as the SA)

```bash
export CLIENT_SA=vertex-psc-client-1@bootstrap-prj-501802.iam.gserviceaccount.com

TOKEN=$(gcloud auth print-access-token --impersonate-service-account="${CLIENT_SA}")
echo "token length: ${#TOKEN}"
# Expect ~1000+. If 0, impersonation failed — fix Step 2.
```

### 4. Test Gemini 2.5 Pro (public API — this is what works)

```bash
export CALLING_PROJECT=bootstrap-prj-501802

curl -sS -X POST \
  "https://aiplatform.googleapis.com/v1/projects/${CALLING_PROJECT}/locations/global/publishers/google/models/gemini-2.5-pro:generateContent" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"contents":{"role":"user","parts":{"text":"Reply with exactly: OK"}}}'
```

**Pass:** JSON with `"text": "OK"`.

---

## B) Test Claude (same token) — needs quota first

Enable in **Vertex AI → Model Garden** (Claude Sonnet 4.5 and/or 5), then request
quota:

https://console.cloud.google.com/iam-admin/quotas?project=bootstrap-prj-501802  

Filter: `claude` or `global_online_prediction` → **Request increase**.  
Requesting quota is **free**; you pay only when calls succeed.

### Claude Sonnet 4.5

```bash
curl -sS -X POST \
  "https://aiplatform.googleapis.com/v1/projects/${CALLING_PROJECT}/locations/global/publishers/anthropic/models/claude-sonnet-4-5:rawPredict" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "anthropic_version": "vertex-2023-10-16",
    "messages": [{"role":"user","content":"Reply with exactly: OK"}],
    "max_tokens": 32
  }'
```

### Claude Sonnet 5

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

| Result | Meaning |
|---|---|
| Model reply | Working |
| `429 RESOURCE_EXHAUSTED` | Quota — not a token problem |
| `401` | Re-mint `TOKEN` (Step 3) |
| `403` | Model Garden / IAM |

---

## C) Did this call use PSC?

**No** — laptop tests use the **public** `aiplatform.googleapis.com` path.

| Check | Public (today) | PSC (later) |
|---|---|---|
| `dig +short aiplatform.googleapis.com` | Google public IPs | `10.10.100.5` |
| Network | Internet | VPN / Interconnect to Shared VPC |
| Auth | Same SA token | Same SA token |

PSC endpoint **is created**; your Mac simply cannot reach `10.10.100.5` without hybrid connectivity.

---

## D) Repo scripts (only if you get a JSON key someday)

Org policy blocks keys today. If an exception is granted:

```bash
cd tfe-workspace/envs/dev/scripts

# Mint token from key file
TOKEN=$(./vertex-sa-token.sh --key ~/vertex-sa.json --mode oauth)

# Or one-shot Gemini + Claude (public DNS; omit PSC_IP)
CALLING_PROJECT=bootstrap-prj-501802 \
SA_KEY_FILE=~/vertex-sa.json \
TOKEN_MODE=oauth \
./test-vertex-psc-from-external.sh

# Private path later (DNS must be 10.10.100.5)
CALLING_PROJECT=bootstrap-prj-501802 \
SA_KEY_FILE=~/vertex-sa.json \
PSC_IP=10.10.100.5 \
TOKEN_MODE=self-signed \
./test-vertex-psc-from-external.sh
```

Default Claude model in that script: `claude-sonnet-4-5`.

---

## E) One-block cheat sheet (Gemini)

```bash
gcloud config set project bootstrap-prj-501802
export CLIENT_SA=vertex-psc-client-1@bootstrap-prj-501802.iam.gserviceaccount.com
export CALLING_PROJECT=bootstrap-prj-501802

TOKEN=$(gcloud auth print-access-token --impersonate-service-account="${CLIENT_SA}")

curl -sS -X POST \
  "https://aiplatform.googleapis.com/v1/projects/${CALLING_PROJECT}/locations/global/publishers/google/models/gemini-2.5-pro:generateContent" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"contents":{"role":"user","parts":{"text":"Reply with exactly: OK"}}}'
```

---

## F) Do not put in GitHub

- Access tokens / JWTs  
- SA JSON keys  
- Terraform Cloud tokens  

Scripts and SA **email** are fine to commit.

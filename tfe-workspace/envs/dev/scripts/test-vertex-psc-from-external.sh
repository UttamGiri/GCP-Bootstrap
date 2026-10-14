#!/usr/bin/env bash
# Call Gemini and Claude directly from a local PC or an OpenShift pod.
#
# Prerequisites: the caller has a route to the PSC /32 through HA VPN or
# Interconnect, and its DNS forwards googleapis.com to the host VPC's Cloud DNS
# inbound address. No VM, IAP tunnel, SOCKS proxy, gcloud login, or metadata
# server is involved.
#
# Usage:
#   CALLING_PROJECT=app-prj SA_KEY_FILE=/secure/sa.json ./test-vertex-psc-from-external.sh
#   CALLING_PROJECT=app-prj SA_KEY_FILE=/var/run/secrets/vertex/sa.json \
#     TOKEN_MODE=self-signed ./test-vertex-psc-from-external.sh

set -euo pipefail

CALLING_PROJECT="${CALLING_PROJECT:?set CALLING_PROJECT to the project billed for the call}"
SA_KEY_FILE="${SA_KEY_FILE:?set SA_KEY_FILE to the service-account JSON key}"
TOKEN_MODE="${TOKEN_MODE:-self-signed}"
LOCATION="${LOCATION:-global}"
GEMINI_MODEL="${GEMINI_MODEL:-gemini-2.5-pro}"
CLAUDE_MODEL="${CLAUDE_MODEL:-claude-sonnet-4-5}"
PSC_IP="${PSC_IP:-}"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TOKEN_HELPER="${SCRIPT_DIR}/vertex-sa-token.sh"

[ -f "$SA_KEY_FILE" ] || { echo "ERROR: SA_KEY_FILE not found: $SA_KEY_FILE" >&2; exit 1; }
[ -x "$TOKEN_HELPER" ] || { echo "ERROR: missing executable $TOKEN_HELPER" >&2; exit 1; }

if [ "$LOCATION" = "global" ]; then
  API_HOST="aiplatform.googleapis.com"
else
  API_HOST="${LOCATION}-aiplatform.googleapis.com"
fi

# macOS often lacks getent; prefer getent, then dig, then dscacheutil.
resolve_host() {
  local host="$1" ip=""
  if command -v getent >/dev/null 2>&1; then
    ip=$(getent hosts "$host" 2>/dev/null | awk '{print $1}' | head -n1 || true)
  fi
  if [ -z "$ip" ] && command -v dig >/dev/null 2>&1; then
    ip=$(dig +short "$host" A 2>/dev/null | awk '/^[0-9.]+$/ {print; exit}' || true)
  fi
  if [ -z "$ip" ] && command -v dscacheutil >/dev/null 2>&1; then
    ip=$(dscacheutil -q host -a name "$host" 2>/dev/null | awk '/^ip_address:/{print $2; exit}' || true)
  fi
  if [ -z "$ip" ] && command -v host >/dev/null 2>&1; then
    ip=$(host -t A "$host" 2>/dev/null | awk '/has address/{print $4; exit}' || true)
  fi
  printf '%s' "$ip"
}

resolved=$(resolve_host "$API_HOST")
[ -n "$resolved" ] || {
  echo "ERROR: $API_HOST did not resolve. Forward googleapis.com to Cloud DNS over VPN/Interconnect." >&2
  exit 1
}
if [ -n "$PSC_IP" ] && [ "$resolved" != "$PSC_IP" ]; then
  echo "ERROR: $API_HOST resolved to $resolved, expected PSC_IP $PSC_IP" >&2
  exit 1
fi

echo "Caller:          external (local PC or OpenShift)"
echo "Calling project: ${CALLING_PROJECT}"
echo "API host:        ${API_HOST} -> ${resolved}"
echo "Auth:            service account JWT (${TOKEN_MODE})"

if [ "$TOKEN_MODE" = "oauth" ]; then
  TOKEN=$("$TOKEN_HELPER" --key "$SA_KEY_FILE" --mode oauth)
else
  TOKEN=$("$TOKEN_HELPER" --key "$SA_KEY_FILE" --mode self-signed --audience "https://${API_HOST}/")
fi

call_model() {
  local label="$1" url="$2" payload="$3" body code
  body=$(mktemp)
  code=$(curl -sS -o "$body" -w '%{http_code}' -X POST "$url" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H 'Content-Type: application/json' --max-time 120 -d "$payload" || echo "000")
  echo "--- ${label}: HTTP ${code}"
  head -c 700 "$body"; echo
  rm -f "$body"
  [ "$code" = "200" ]
}

call_model "Gemini" \
  "https://${API_HOST}/v1/projects/${CALLING_PROJECT}/locations/${LOCATION}/publishers/google/models/${GEMINI_MODEL}:generateContent" \
  '{"contents":{"role":"user","parts":{"text":"Reply with exactly: PSC_OK"}}}'
call_model "Claude" \
  "https://${API_HOST}/v1/projects/${CALLING_PROJECT}/locations/${LOCATION}/publishers/anthropic/models/${CLAUDE_MODEL}:rawPredict" \
  '{"anthropic_version":"vertex-2023-10-16","messages":[{"role":"user","content":"Reply with exactly: PSC_OK"}],"max_tokens":32}'

echo "PASS: both models used the same PSC-resolved API hostname."

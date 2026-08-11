#!/usr/bin/env bash
# Mint a Vertex AI bearer token from a service account key. No gcloud, no SDK —
# only openssl plus jq or python3, so it runs on an on-prem host or any laptop.
#
# Prints the token to stdout and nothing else, so it composes:
#   TOKEN=$(./vertex-sa-token.sh --key sa.json)
#   curl -H "Authorization: Bearer $TOKEN" ...
#
# Modes:
#   self-signed  Sign a JWT and send it directly as the bearer token. No network
#                call at all, so it works even when oauth2.googleapis.com is
#                unreachable. Claims carry "aud", never "scope" — Google rejects
#                a JWT that sets both.
#   oauth        Sign a JWT assertion and exchange it for an OAuth access token at
#                oauth2.googleapis.com. One extra round trip, accepted everywhere.
#
# Usage:
#   ./vertex-sa-token.sh --key sa.json                      # oauth (default)
#   ./vertex-sa-token.sh --key sa.json --mode self-signed    # no round trip
#   ./vertex-sa-token.sh --key sa.json --proxy socks5h://127.0.0.1:11080
#
# The key file may also come from GOOGLE_APPLICATION_CREDENTIALS.

set -euo pipefail

MODE="oauth"
KEY_FILE="${GOOGLE_APPLICATION_CREDENTIALS:-}"
AUDIENCE="https://aiplatform.googleapis.com/"
SCOPE="https://www.googleapis.com/auth/cloud-platform"
LIFETIME=3600
PROXY=""

die() { echo "ERROR: $*" >&2; exit 1; }

# Reprints the header comment block, so help never drifts from the source.
usage() {
  awk 'NR > 1 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "$0"
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --key)      KEY_FILE="${2:-}"; shift 2 ;;
    --mode)     MODE="${2:-}"; shift 2 ;;
    --audience) AUDIENCE="${2:-}"; shift 2 ;;
    --scope)    SCOPE="${2:-}"; shift 2 ;;
    --lifetime) LIFETIME="${2:-}"; shift 2 ;;
    --proxy)    PROXY="${2:-}"; shift 2 ;;
    -h|--help)  usage 0 ;;
    *)          echo "unknown argument: $1" >&2; usage 1 ;;
  esac
done

case "$MODE" in
  self-signed|oauth) ;;
  *) die "--mode must be self-signed or oauth" ;;
esac
[ -n "$KEY_FILE" ] || die "pass --key or set GOOGLE_APPLICATION_CREDENTIALS"
[ -f "$KEY_FILE" ] || die "key file not found: ${KEY_FILE}"
command -v openssl >/dev/null || die "openssl is required"

# Prefer jq, fall back to python3, so this works on hosts that have only one.
if command -v jq >/dev/null 2>&1; then
  json_get() { jq -r --arg k "$1" '.[$k] // empty'; }
elif command -v python3 >/dev/null 2>&1; then
  json_get() { python3 -c 'import json,sys; print(json.load(sys.stdin).get(sys.argv[1],""))' "$1"; }
else
  die "either jq or python3 is required to read the key file"
fi

CLIENT_EMAIL=$(json_get client_email <"$KEY_FILE")
PRIVATE_KEY_ID=$(json_get private_key_id <"$KEY_FILE")
KEY_TYPE=$(json_get type <"$KEY_FILE")

[ "$KEY_TYPE" = "service_account" ] || die "key type is '${KEY_TYPE:-<none>}', expected service_account (gcloud user credentials will not work here)"
[ -n "$CLIENT_EMAIL" ] || die "no client_email in ${KEY_FILE}"

# The PEM has to hit the filesystem for openssl, so keep it 0600 and short-lived.
PEM=$(mktemp); chmod 600 "$PEM"
trap 'rm -f "$PEM"' EXIT
json_get private_key <"$KEY_FILE" >"$PEM"
[ -s "$PEM" ] || die "no private_key in ${KEY_FILE}"

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

NOW=$(date +%s)
EXP=$((NOW + LIFETIME))

HEADER=$(printf '{"alg":"RS256","typ":"JWT","kid":"%s"}' "$PRIVATE_KEY_ID" | b64url)

if [ "$MODE" = "self-signed" ]; then
  CLAIMS=$(printf '{"iss":"%s","sub":"%s","aud":"%s","iat":%s,"exp":%s}' \
    "$CLIENT_EMAIL" "$CLIENT_EMAIL" "$AUDIENCE" "$NOW" "$EXP" | b64url)
else
  CLAIMS=$(printf '{"iss":"%s","scope":"%s","aud":"%s","iat":%s,"exp":%s}' \
    "$CLIENT_EMAIL" "$SCOPE" "https://oauth2.googleapis.com/token" "$NOW" "$EXP" | b64url)
fi

SIGNING_INPUT="${HEADER}.${CLAIMS}"
SIGNATURE=$(printf '%s' "$SIGNING_INPUT" | openssl dgst -sha256 -sign "$PEM" | b64url)
JWT="${SIGNING_INPUT}.${SIGNATURE}"

if [ "$MODE" = "self-signed" ]; then
  printf '%s\n' "$JWT"
  exit 0
fi

set -- --silent --show-error --max-time 30
[ -n "$PROXY" ] && set -- "$@" --proxy "$PROXY"

RESPONSE=$(curl "$@" \
  --request POST https://oauth2.googleapis.com/token \
  --header 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer' \
  --data-urlencode "assertion=${JWT}") || die "token request failed — is oauth2.googleapis.com reachable?"

ACCESS_TOKEN=$(printf '%s' "$RESPONSE" | json_get access_token)
if [ -z "$ACCESS_TOKEN" ]; then
  echo "ERROR: no access_token in response:" >&2
  printf '%s\n' "$RESPONSE" >&2
  echo "" >&2
  echo "'invalid_grant' usually means clock skew or an expired/deleted key." >&2
  exit 1
fi

printf '%s\n' "$ACCESS_TOKEN"

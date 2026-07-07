#!/usr/bin/env bash
# Destroy all resources in GCP-tfe-workspace and reset auth to GCP-Bootstrap.
#
# Usage:
#   export TFE_TOKEN=<your TFE API token>
#   ./destroy-gcp-tfe-workspace.sh
#
# Get token: TFE → User settings → Tokens → Create API token

set -euo pipefail

TFE_HOSTNAME="${TFE_HOSTNAME:-app.terraform.io}"
TFE_ORG="${TFE_ORG:-vaflt-org}"
WORKLOAD_NAME="${WORKLOAD_NAME:-GCP-tfe-workspace}"
BOOTSTRAP_NAME="${BOOTSTRAP_NAME:-GCP-Bootstrap}"
API="https://${TFE_HOSTNAME}/api/v2"

auth() { echo "Authorization: Bearer ${TFE_TOKEN}"; }

if [ -z "${TFE_TOKEN:-}" ]; then
  echo "ERROR: export TFE_TOKEN first (TFE User settings → Tokens)"
  exit 1
fi

resolve_workspace_id() {
  curl -sS --header "$(auth)" --header "Content-Type: application/vnd.api+json" \
    "${API}/organizations/${TFE_ORG}/workspaces/$1" \
    | jq -r '.data.id // empty'
}

discard_stuck_runs() {
  local ws_id="$1"
  curl -sS --header "$(auth)" --header "Content-Type: application/vnd.api+json" \
    "${API}/workspaces/${ws_id}/runs?page%5Bsize%5D=20" \
    | jq -r '.data[]? | select(.attributes.status | test("^(pending|planning|planned|confirmed|apply_queued|plan_queued)$")) | .id' \
    | while read -r run_id; do
        [ -z "$run_id" ] && continue
        echo "Discarding stuck run ${run_id}..."
        curl -sS --header "$(auth)" --header "Content-Type: application/vnd.api+json" \
          --request POST "${API}/runs/${run_id}/actions/discard" >/dev/null 2>&1 || true
      done
}

read_env_var() {
  curl -sS --header "$(auth)" --header "Content-Type: application/vnd.api+json" \
    "${API}/workspaces/$1/vars?page%5Bsize%5D=100" \
    | jq -r --arg k "$2" '[.data[]? | select(.attributes.key==$k and .attributes.category=="env")][0].attributes.value // empty'
}

read_output() {
  curl -sS --header "$(auth)" --header "Content-Type: application/vnd.api+json" \
    "${API}/workspaces/$1/current-state-version-outputs" \
    | jq -r --arg k "$2" '[.data[]? | select(.attributes.name==$k)][0].attributes.value // empty'
}

upsert_env_var() {
  local ws_id="$1" key="$2" value="$3" existing_id
  existing_id=$(curl -sS --header "$(auth)" --header "Content-Type: application/vnd.api+json" \
    "${API}/workspaces/${ws_id}/vars?page%5Bsize%5D=100" \
    | jq -r --arg k "$key" '[.data[]? | select(.attributes.key==$k and .attributes.category=="env")][0].id // empty')
  if [ -n "$existing_id" ]; then
    curl -sS --header "$(auth)" --header "Content-Type: application/vnd.api+json" \
      --request PATCH \
      --data "$(jq -n --arg val "$value" '{data:{type:"vars",attributes:{value:$val}}}')" \
      "${API}/vars/${existing_id}" >/dev/null
  else
    curl -sS --header "$(auth)" --header "Content-Type: application/vnd.api+json" \
      --request POST \
      --data "$(jq -n --arg key "$key" --arg val "$value" '{data:{type:"vars",attributes:{key:$key,value:$val,category:"env",hcl:false,sensitive:false}}}')" \
      "${API}/workspaces/${ws_id}/vars" >/dev/null
  fi
  echo "  set ${key}"
}

copy_bootstrap_auth() {
  local bootstrap_id="$1" workload_id="$2" sa wif
  sa=$(read_env_var "$bootstrap_id" "TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL")
  [ -z "$sa" ] && sa=$(read_output "$bootstrap_id" "TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL")
  wif=$(read_env_var "$bootstrap_id" "TFC_GCP_WORKLOAD_PROVIDER_NAME")
  [ -z "$wif" ] && wif=$(read_output "$bootstrap_id" "TFC_GCP_WORKLOAD_PROVIDER_NAME")
  upsert_env_var "$workload_id" "TFC_GCP_PROVIDER_AUTH" "true"
  upsert_env_var "$workload_id" "TFC_GCP_PRINCIPAL_TYPE" "service_account"
  upsert_env_var "$workload_id" "TFC_GCP_AUTH_IDENTITY" "bootstrap"
  upsert_env_var "$workload_id" "TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL" "$sa"
  upsert_env_var "$workload_id" "TFC_GCP_WORKLOAD_PROVIDER_NAME" "$wif"
  echo "  TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL=${sa}"
  echo "  TFC_GCP_WORKLOAD_PROVIDER_NAME=${wif}"
}

sync_workload_auth() {
  local workload_id="$1" sa wif
  sa=$(read_output "$workload_id" "TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL")
  wif=$(read_output "$workload_id" "TFC_GCP_WORKLOAD_PROVIDER_NAME")
  if [ -z "$sa" ] || [ -z "$wif" ]; then
    echo "ERROR: workload outputs missing — apply first or run TFE Sync Workload Auth"
    exit 1
  fi
  upsert_env_var "$workload_id" "TFC_GCP_PROVIDER_AUTH" "true"
  upsert_env_var "$workload_id" "TFC_GCP_PRINCIPAL_TYPE" "service_account"
  upsert_env_var "$workload_id" "TFC_GCP_AUTH_IDENTITY" "workload"
  upsert_env_var "$workload_id" "TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL" "$sa"
  upsert_env_var "$workload_id" "TFC_GCP_WORKLOAD_PROVIDER_NAME" "$wif"
  echo "  TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL=${sa}"
  echo "  TFC_GCP_WORKLOAD_PROVIDER_NAME=${wif}"
}

USER=$(curl -sS --header "$(auth)" --header "Content-Type: application/vnd.api+json" \
  "${API}/account/details" | jq -r '.data.attributes.username // empty')
if [ -z "$USER" ]; then
  echo "ERROR: TFE_TOKEN unauthorized — create a new token at User settings → Tokens"
  exit 1
fi
echo "TFE user: ${USER}"

WORKLOAD_ID=$(resolve_workspace_id "$WORKLOAD_NAME")
BOOTSTRAP_ID=$(resolve_workspace_id "$BOOTSTRAP_NAME")
if [ -z "$WORKLOAD_ID" ]; then
  echo "ERROR: workspace ${WORKLOAD_NAME} not found"
  exit 1
fi

echo "=== ${WORKLOAD_NAME} (${WORKLOAD_ID}) ==="
discard_stuck_runs "$WORKLOAD_ID"
sleep 3

allow_destroy=$(curl -sS --header "$(auth)" --header "Content-Type: application/vnd.api+json" \
  "${API}/workspaces/${WORKLOAD_ID}" | jq -r '.data.attributes["allow-destroy-plan"] // false')
if [ "$allow_destroy" != "true" ]; then
  echo "Enabling allow-destroy-plan..."
  curl -sS --header "$(auth)" --header "Content-Type: application/vnd.api+json" \
    --request PATCH \
    --data '{"data":{"type":"workspaces","attributes":{"allow-destroy-plan":true}}}' \
    "${API}/workspaces/${WORKLOAD_ID}" >/dev/null
fi

resource_count=$(curl -sS --header "$(auth)" --header "Content-Type: application/vnd.api+json" \
  "${API}/workspaces/${WORKLOAD_ID}" | jq -r '.data.attributes["resource-count"] // 0')
echo "Resource count: ${resource_count}"

finish_destroy() {
  local rc="$1"
  echo "Done. Resource count: ${rc}"
  echo "Copying bootstrap auth..."
  copy_bootstrap_auth "$BOOTSTRAP_ID" "$WORKLOAD_ID"
  echo ""
  echo "Next: run GitHub Actions workflow 'Bump Bootstrap Auth' to bump resource_suffix (+1) for SA/WIF only."
  exit 0
}

if [ "$resource_count" = "0" ]; then
  echo "State empty — copying bootstrap auth only."
  copy_bootstrap_auth "$BOOTSTRAP_ID" "$WORKLOAD_ID"
  echo ""
  echo "Next: run GitHub Actions workflow 'Bump Bootstrap Auth' to bump resource_suffix (+1) for SA/WIF only."
  exit 0
fi

echo "Switching to bootstrap auth before destroy (reliable for UI and script)..."
copy_bootstrap_auth "$BOOTSTRAP_ID" "$WORKLOAD_ID"
echo "Waiting for TFE to pick up env vars on the destroy run..."
sleep 10

RUN_RESPONSE=$(curl -sS --header "$(auth)" --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data "$(jq -n --arg ws "$WORKLOAD_ID" '{
    data: {
      type: "runs",
      attributes: {
        message: "Destroy from local script",
        "is-destroy": true,
        "auto-apply": false,
        refresh: false
      },
      relationships: { workspace: { data: { type: "workspaces", id: $ws } } }
    }
  }')" \
  "${API}/runs")

RUN_ID=$(echo "$RUN_RESPONSE" | jq -r '.data.id // empty')
if [ -z "$RUN_ID" ]; then
  echo "Failed to queue destroy:"
  echo "$RUN_RESPONSE" | jq '.errors // .'
  exit 1
fi
echo "Destroy run: https://app.terraform.io/app/${TFE_ORG}/workspaces/${WORKLOAD_NAME}/runs/${RUN_ID}"

apply_attempted=false
for i in $(seq 1 120); do
  run_json=$(curl -sS --header "$(auth)" --header "Content-Type: application/vnd.api+json" "${API}/runs/${RUN_ID}")
  status=$(echo "$run_json" | jq -r '.data.attributes.status')
  confirmable=$(echo "$run_json" | jq -r '.data.attributes.actions["is-confirmable"] // false')
  echo "  poll ${i}: ${status} (confirmable=${confirmable})"

  case "$status" in
    applied|planned_and_finished)
      resource_count=$(curl -sS --header "$(auth)" --header "Content-Type: application/vnd.api+json" \
        "${API}/workspaces/${WORKLOAD_ID}" | jq -r '.data.attributes["resource-count"] // 0')
      finish_destroy "$resource_count"
      ;;
    errored)
      resource_count=$(curl -sS --header "$(auth)" --header "Content-Type: application/vnd.api+json" \
        "${API}/workspaces/${WORKLOAD_ID}" | jq -r '.data.attributes["resource-count"] // 0')
      if [ "$resource_count" = "0" ]; then
        echo "Destroy errored but state is empty — treating as success."
        finish_destroy "$resource_count"
      fi
      echo "Destroy failed: ${status} (resource_count=${resource_count})"
      echo "If you see 'workspace is not locked' — discard other planned runs and retry this script once."
      exit 1
      ;;
    canceled|discarded)
      echo "Destroy failed: ${status}"
      echo "If you see 'workspace is not locked' — discard other planned runs and retry this script once."
      exit 1
      ;;
  esac

  if [ "$confirmable" = "true" ] && [ "$apply_attempted" = "false" ]; then
    echo "Applying destroy..."
    apply_response=$(curl -sS --header "$(auth)" --header "Content-Type: application/vnd.api+json" \
      --request POST "${API}/runs/${RUN_ID}/actions/apply" 2>/dev/null || true)
    if echo "$apply_response" | jq -e '.errors' >/dev/null 2>&1; then
      err_status=$(echo "$apply_response" | jq -r '.errors[0].status // empty')
      [ "$err_status" != "409" ] && echo "$apply_response" | jq '.errors' && exit 1
    else
      apply_attempted=true
    fi
  fi
  sleep 10
done

echo "Timed out"
exit 1

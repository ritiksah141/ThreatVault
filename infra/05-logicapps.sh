#!/usr/bin/env bash
# 05 — Deploy all 8 Logic Apps from the workflow definition files. Each Logic App
# is a Consumption-tier serverless workflow exposing a POST endpoint and binding
# to the cosmos / blob API connections deployed in step 04.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/parameters.sh"
ensure_logged_in

[[ -f "$SCRIPT_DIR/.state.connections" ]] || fail "Run 04-connections.sh first"
source "$SCRIPT_DIR/.state.connections"

# (workflow_name, definition_filename, output_key_in_config)
WORKFLOWS=(
  "$LA_EV_LIST   la-evidence-list.def.json   evidenceList"
  "$LA_EV_CREATE la-evidence-create.def.json evidenceCreate"
  "$LA_EV_UPDATE la-evidence-update.def.json evidenceUpdate"
  "$LA_EV_DELETE la-evidence-delete.def.json evidenceDelete"
  "$LA_CS_LIST   la-cases-list.def.json      casesList"
  "$LA_CS_CREATE la-cases-create.def.json    casesCreate"
  "$LA_CS_UPDATE la-cases-update.def.json    casesUpdate"
  "$LA_CS_DELETE la-cases-delete.def.json    casesDelete"
  "$LA_AU_LIST   la-audit-list.def.json      auditList"
  "$LA_AU_LOG    la-audit-create.def.json    auditCreate"
)

# Ensure expected variable names exist (back-compat with parameters.sh which had
# the older 6-app names).
: "${LA_EV_LIST:=la-evidence-list}"
: "${LA_EV_CREATE:=la-evidence-create}"
: "${LA_EV_UPDATE:=la-evidence-update}"
: "${LA_EV_DELETE:=la-evidence-delete}"
: "${LA_CS_LIST:=la-cases-list}"
: "${LA_CS_CREATE:=la-cases-create}"
: "${LA_CS_UPDATE:=la-cases-update}"
: "${LA_CS_DELETE:=la-cases-delete}"
: "${LA_AU_LIST:=la-audit-logs}"
: "${LA_AU_LOG:=la-audit-quicklog}"

ENDPOINTS_JSON="$SCRIPT_DIR/.state.endpoints.json"
echo "{}" >"$ENDPOINTS_JSON"

deploy_workflow() {
  local name="$1" def="$2" key="$3"
  banner "Deploying $name ($def)"
  local depName="$name-$(date +%s)"
  az deployment group create \
    -g "$RG_NAME" -n "$depName" \
    -f "$SCRIPT_DIR/logicapps/_template.json" \
    --parameters \
      workflowName="$name" \
      location="$LOCATION" \
      cosmosConnId="$COSMOS_CONN_ID" \
      blobConnId="$BLOB_CONN_ID" \
      definition=@"$SCRIPT_DIR/logicapps/$def" \
    --query "properties.outputs.callbackUrl.value" -o tsv >"$SCRIPT_DIR/.tmp_url"
  local url
  url="$(cat "$SCRIPT_DIR/.tmp_url")"
  rm -f "$SCRIPT_DIR/.tmp_url"
  ok "$name deployed"
  # Append into endpoints JSON via python (portable JSON merge)
  python3 - "$ENDPOINTS_JSON" "$key" "$url" <<'PY'
import json, sys, pathlib
path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
data[sys.argv[2]] = sys.argv[3]
path.write_text(json.dumps(data, indent=2))
PY
}

for line in "${WORKFLOWS[@]}"; do
  read -r name def key <<<"$line"
  deploy_workflow "$name" "$def" "$key"
done

ok "All Logic Apps deployed. Endpoints map written to $ENDPOINTS_JSON"

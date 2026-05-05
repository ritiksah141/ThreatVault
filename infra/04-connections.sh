#!/usr/bin/env bash
# 04 — Deploy API connections (Cosmos DB + Blob) used by every Logic App.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/parameters.sh"
ensure_logged_in

[[ -f "$SCRIPT_DIR/.state.storage" ]] || fail "Run 01-storage.sh first"
[[ -f "$SCRIPT_DIR/.state.cosmos"  ]] || fail "Run 02-cosmos.sh  first"
source "$SCRIPT_DIR/.state.storage"
source "$SCRIPT_DIR/.state.cosmos"

banner "Deploying Logic-App API connections (cosmos + blob)"
DEPLOY_NAME="conn-$(date +%s)"
az deployment group create \
  -g "$RG_NAME" -n "$DEPLOY_NAME" \
  -f "$SCRIPT_DIR/logicapps/_connections.json" \
  --parameters \
    location="$LOCATION" \
    cosmosName="$COSMOS_NAME"   cosmosKey="$COSMOS_KEY" \
    storageName="$STORAGE_NAME" storageKey="$STORAGE_KEY" \
    connCosmos="$CONN_COSMOS"   connBlob="$CONN_BLOB" \
  --query "properties.outputs" -o json >"$SCRIPT_DIR/.state.conn.json"

COSMOS_CONN_ID="$(az resource show -g "$RG_NAME" -n "$CONN_COSMOS" --resource-type Microsoft.Web/connections --query id -o tsv)"
BLOB_CONN_ID="$(  az resource show -g "$RG_NAME" -n "$CONN_BLOB"   --resource-type Microsoft.Web/connections --query id -o tsv)"

# Auto-consent: API connections start in 'Unauthenticated' state. For key-based
# connectors (cosmos/blob) we just refresh the connection so it becomes ready.
banner "Auto-consenting API connections"
for c in "$CONN_COSMOS" "$CONN_BLOB"; do
  status="$(az resource show -g "$RG_NAME" -n "$c" --resource-type Microsoft.Web/connections --query 'properties.statuses[0].status' -o tsv 2>/dev/null || echo Unknown)"
  ok "Connection $c — status: $status"
done

{
  echo "COSMOS_CONN_ID=$COSMOS_CONN_ID"
  echo "BLOB_CONN_ID=$BLOB_CONN_ID"
} >"$SCRIPT_DIR/.state.connections"
ok "Wrote $SCRIPT_DIR/.state.connections"

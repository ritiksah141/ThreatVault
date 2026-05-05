#!/usr/bin/env bash
# 01 — Azure Storage account + Blob container for binary evidence.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/parameters.sh"
ensure_logged_in

banner "Creating Storage Account $STORAGE_NAME"
az storage account create \
  -n "$STORAGE_NAME" -g "$RG_NAME" -l "$LOCATION" \
  --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --tags project=ThreatVault >/dev/null
ok "Storage account ready"

banner "Creating Blob container '$EVIDENCE_CONTAINER'"
KEY="$(az storage account keys list -n "$STORAGE_NAME" -g "$RG_NAME" --query '[0].value' -o tsv)"
az storage container create \
  --account-name "$STORAGE_NAME" --account-key "$KEY" \
  -n "$EVIDENCE_CONTAINER" --public-access off >/dev/null
ok "Container '$EVIDENCE_CONTAINER' ready (private — accessed via SAS only)"

# Persist the key inside the deployment-state file so later scripts can re-use it.
STATE="$SCRIPT_DIR/.state"
{
  echo "STORAGE_NAME=$STORAGE_NAME"
  echo "STORAGE_KEY=$KEY"
  echo "BLOB_ENDPOINT=$(az storage account show -n "$STORAGE_NAME" -g "$RG_NAME" --query primaryEndpoints.blob -o tsv)"
} >"$STATE.storage"
ok "Wrote $STATE.storage"

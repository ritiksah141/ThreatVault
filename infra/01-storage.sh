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

# Generate a short-lived (90-day) read-only SAS for the evidence container so the
# front-end can fetch private blobs without ever holding the storage key. This is
# the "Zero-Trust Blob Access" feature — container is private, SAS is the credential.
banner "Generating read-only SAS for '$EVIDENCE_CONTAINER'"
SAS_EXPIRY="$(date -u -v +90d +'%Y-%m-%dT%H:%MZ' 2>/dev/null || date -u -d '+90 days' +'%Y-%m-%dT%H:%MZ')"
SAS_TOKEN="$(az storage container generate-sas \
  --account-name "$STORAGE_NAME" --account-key "$KEY" \
  -n "$EVIDENCE_CONTAINER" \
  --permissions r --expiry "$SAS_EXPIRY" --https-only -o tsv)"
ok "SAS issued (expires $SAS_EXPIRY)"

BLOB_ENDPOINT="$(az storage account show -n "$STORAGE_NAME" -g "$RG_NAME" --query primaryEndpoints.blob -o tsv)"

# Persist the key inside the deployment-state file so later scripts can re-use it.
STATE="$SCRIPT_DIR/.state"
{
  echo "STORAGE_NAME=$STORAGE_NAME"
  echo "STORAGE_KEY=$KEY"
  echo "BLOB_ENDPOINT=$BLOB_ENDPOINT"
  echo "EVIDENCE_SAS=$SAS_TOKEN"
  echo "EVIDENCE_SAS_EXPIRY=$SAS_EXPIRY"
} >"$STATE.storage"
ok "Wrote $STATE.storage"

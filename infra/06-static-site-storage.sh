#!/usr/bin/env bash
# 06 — Create Static Website on Azure Storage. This replaces Azure Static Web App
# because SWA is not available in the regions allowed by the current subscription policy.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/parameters.sh"
ensure_logged_in

# Load storage info from state file
source "$SCRIPT_DIR/.state.storage"

banner "Enabling Static Website on Storage Account $STORAGE_NAME"
az storage blob service-properties update \
  --account-name "$STORAGE_NAME" --account-key "$STORAGE_KEY" \
  --static-website true --index-document index.html --404-document index.html >/dev/null
ok "Static website enabled"

# Retrieve the web endpoint (e.g., account.z6.web.core.windows.net)
WEB_ENDPOINT="$(az storage account show -n "$STORAGE_NAME" -g "$RG_NAME" --query "primaryEndpoints.web" -o tsv | sed 's/https:\/\///;s/\///')"

{
  echo "SWA_NAME=$STORAGE_NAME"
  echo "SWA_HOST=$WEB_ENDPOINT"
  echo "SWA_TOKEN=N/A"
} >"$SCRIPT_DIR/.state.swa"
ok "Wrote $SCRIPT_DIR/.state.swa"

echo "Public URL: https://$WEB_ENDPOINT"

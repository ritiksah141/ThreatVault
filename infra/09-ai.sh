#!/usr/bin/env bash
# 09 — Azure AI Content Safety (free F0 tier). Used by la-evidence-moderate to
# auto-flag evidence titles/notes with adult/violence/hate/selfharm severity.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/parameters.sh"
ensure_logged_in

CS_NAME="${CS_NAME:-cs-${SUFFIX}}"
# Pin Content Safety to the same region as the rest of the stack. Student-tier
# subscription policies lock allowed regions, so the default matches LOCATION.
CS_LOCATION="${CS_LOCATION:-$LOCATION}"

banner "Provisioning Azure AI Content Safety $CS_NAME ($CS_LOCATION, F0)"
if az cognitiveservices account show -n "$CS_NAME" -g "$RG_NAME" >/dev/null 2>&1; then
  ok "Content Safety account already exists"
else
  az cognitiveservices account create \
    -n "$CS_NAME" -g "$RG_NAME" -l "$CS_LOCATION" \
    --kind ContentSafety --sku F0 --yes \
    --custom-domain "$CS_NAME" \
    --tags project=ThreatVault >/dev/null
  ok "Content Safety created"
fi

CS_ENDPOINT="$(az cognitiveservices account show -n "$CS_NAME" -g "$RG_NAME" --query properties.endpoint -o tsv)"
CS_KEY="$(az cognitiveservices account keys list -n "$CS_NAME" -g "$RG_NAME" --query key1 -o tsv)"
ok "Endpoint: $CS_ENDPOINT"

# Persist for downstream steps + Key Vault.
{
  echo "CS_NAME=$CS_NAME"
  echo "CS_ENDPOINT=$CS_ENDPOINT"
  echo "CS_KEY=$CS_KEY"
} >"$SCRIPT_DIR/.state.contentsafety"
ok "Wrote $SCRIPT_DIR/.state.contentsafety"

if [[ -f "$SCRIPT_DIR/.state.monitor" ]]; then
  source "$SCRIPT_DIR/.state.monitor"
  az keyvault secret set --vault-name "$KV_NAME" -n contentsafety-key      --value "$CS_KEY"      >/dev/null
  az keyvault secret set --vault-name "$KV_NAME" -n contentsafety-endpoint --value "$CS_ENDPOINT" >/dev/null
  ok "Stored Content Safety credentials in Key Vault $KV_NAME"
fi

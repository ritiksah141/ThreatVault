#!/usr/bin/env bash
# 03 — Log Analytics + Application Insights (advanced telemetry feature) + Key Vault.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/parameters.sh"
ensure_logged_in

banner "Creating Log Analytics Workspace $LAW_NAME"
az monitor log-analytics workspace create \
  -g "$RG_NAME" -n "$LAW_NAME" -l "$LOCATION" \
  --sku PerGB2018 --tags project=ThreatVault >/dev/null
LAW_ID="$(az monitor log-analytics workspace show -g "$RG_NAME" -n "$LAW_NAME" --query id -o tsv)"
ok "Workspace ready"

banner "Creating Application Insights $APPI_NAME (workspace-based)"
az extension add --name application-insights --upgrade --only-show-errors >/dev/null 2>&1 || true
az monitor app-insights component create \
  -a "$APPI_NAME" -g "$RG_NAME" -l "$LOCATION" \
  --kind web --workspace "$LAW_ID" \
  --tags project=ThreatVault >/dev/null
APPI_KEY="$(az monitor app-insights component show -a "$APPI_NAME" -g "$RG_NAME" --query instrumentationKey -o tsv)"
APPI_CONN="$(az monitor app-insights component show -a "$APPI_NAME" -g "$RG_NAME" --query connectionString -o tsv)"
ok "App Insights ready"

banner "Creating Key Vault $KV_NAME"
if az keyvault show -n "$KV_NAME" -g "$RG_NAME" >/dev/null 2>&1; then
  ok "Key Vault $KV_NAME already exists"
else
  az keyvault create \
    -n "$KV_NAME" -g "$RG_NAME" -l "$LOCATION" \
    --enable-rbac-authorization false \
    --sku standard --tags project=ThreatVault >/dev/null
  ok "Key Vault ready"
fi

# Store secrets we already know about (storage + cosmos keys)
if [[ -f "$SCRIPT_DIR/.state.storage" ]]; then
  source "$SCRIPT_DIR/.state.storage"
  az keyvault secret set --vault-name "$KV_NAME" -n storage-key   --value "$STORAGE_KEY"   >/dev/null
  ok "Stored storage-key in Key Vault"
fi
if [[ -f "$SCRIPT_DIR/.state.cosmos" ]]; then
  source "$SCRIPT_DIR/.state.cosmos"
  az keyvault secret set --vault-name "$KV_NAME" -n cosmos-key    --value "$COSMOS_KEY"    >/dev/null
  az keyvault secret set --vault-name "$KV_NAME" -n cosmos-endpoint --value "$COSMOS_ENDPOINT" >/dev/null
  ok "Stored cosmos-key + cosmos-endpoint in Key Vault"
fi

STATE="$SCRIPT_DIR/.state"
{
  echo "LAW_ID=$LAW_ID"
  echo "APPI_NAME=$APPI_NAME"
  echo "APPI_KEY=$APPI_KEY"
  echo "APPI_CONN=$APPI_CONN"
  echo "KV_NAME=$KV_NAME"
} >"$STATE.monitor"
ok "Wrote $STATE.monitor"

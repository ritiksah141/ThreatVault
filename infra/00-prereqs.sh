#!/usr/bin/env bash
# 00 — Pre-requisites: log in, register providers, create resource group.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=parameters.sh
source "$SCRIPT_DIR/parameters.sh"

ensure_logged_in

banner "Registering required resource providers"
for ns in Microsoft.Storage Microsoft.DocumentDB Microsoft.Web Microsoft.Logic \
          Microsoft.Insights Microsoft.OperationalInsights Microsoft.KeyVault; do
  state="$(az provider show -n "$ns" --query registrationState -o tsv 2>/dev/null || echo NotRegistered)"
  if [[ "$state" != "Registered" ]]; then
    az provider register -n "$ns" --wait >/dev/null
    ok "Registered $ns"
  else
    ok "$ns already registered"
  fi
done

banner "Creating resource group $RG_NAME in $LOCATION"
az group create -n "$RG_NAME" -l "$LOCATION" \
  --tags project=ThreatVault module=COM682 region=italynorth >/dev/null
ok "Resource group ready"

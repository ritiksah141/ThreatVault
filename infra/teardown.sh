#!/usr/bin/env bash
# Removes the entire ThreatVault resource group.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/parameters.sh"
ensure_logged_in

read -rp "Delete resource group $RG_NAME and all resources? (yes/N): " yn
[[ "$yn" == "yes" ]] || { echo "Aborted."; exit 0; }

az group delete -n "$RG_NAME" --yes --no-wait
ok "Deletion started — Azure will reclaim resources in the background."
rm -f "$SCRIPT_DIR"/.state.* "$SCRIPT_DIR"/.tmp_url 2>/dev/null || true

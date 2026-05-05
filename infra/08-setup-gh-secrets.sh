#!/usr/bin/env bash
# 09 — Automate GitHub Secrets setup using the 'gh' CLI.
# This sets up AZURE_CREDENTIALS and STORAGE_ACCOUNT_NAME.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/parameters.sh"
ensure_logged_in

# Check for gh CLI
if ! command -v gh &> /dev/null; then
    fail "GitHub CLI (gh) is not installed. Please install it or set secrets manually."
fi

# Ensure user is logged into gh
gh auth status >/dev/null 2>&1 || fail "Not logged into GitHub CLI. Run: gh auth login"

# Load storage info
[[ -f "$SCRIPT_DIR/.state.storage" ]] || fail "Run 01-storage.sh first"
source "$SCRIPT_DIR/.state.storage"

# 1. Create Service Principal for GitHub Actions
banner "Generating Azure Service Principal for GitHub Actions"
SP_NAME="ThreatVault-CI-${SUFFIX}"
# Use --sdk-auth to get the JSON format required by azure/login.
# We suppress output to avoid leaking credentials in logs.
az ad sp create-for-rbac --name "$SP_NAME" --role contributor \
  --scopes "/subscriptions/$SUB_ID/resourceGroups/$RG_NAME" \
  --sdk-auth 2>/dev/null | gh secret set AZURE_CREDENTIALS

ok "Set secret: AZURE_CREDENTIALS"

gh secret set STORAGE_ACCOUNT_NAME --body "$STORAGE_NAME"
ok "Set secret: STORAGE_ACCOUNT_NAME"

banner "GitHub Secrets setup complete!"
echo "You can now push your code to trigger the deployment."

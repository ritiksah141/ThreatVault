#!/usr/bin/env bash
# 08 — Push the secrets the GitHub Actions workflow needs to deploy the
# frontend to the storage account's static-website ($web) container.
# Sets:  AZURE_STORAGE_ACCOUNT  (e.g. sttv5fb957)
#        AZURE_STORAGE_KEY      (primary access key)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/parameters.sh"
ensure_logged_in

command -v gh >/dev/null 2>&1 || fail "GitHub CLI (gh) not installed. Run: brew install gh"
gh auth status >/dev/null 2>&1 || fail "Not logged into gh. Run: gh auth login"

[[ -f "$SCRIPT_DIR/.state.storage" ]] || fail "Run 01-storage.sh first"
source "$SCRIPT_DIR/.state.storage"

banner "Setting GitHub Actions secrets for storage-static-website deploy"
gh secret set AZURE_STORAGE_ACCOUNT --body "$STORAGE_NAME" >/dev/null
ok "Set: AZURE_STORAGE_ACCOUNT = $STORAGE_NAME"

printf '%s' "$STORAGE_KEY" | gh secret set AZURE_STORAGE_KEY >/dev/null
ok "Set: AZURE_STORAGE_KEY (hidden)"

banner "GitHub Secrets ready — push to main to trigger the deploy."

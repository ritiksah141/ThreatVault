#!/usr/bin/env bash
# Master deployment script — runs every step in order. Idempotent-ish: scripts
# use az CLI 'create' (which is upsert for most resource types) so re-running
# them on an already-deployed environment is safe.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "$SCRIPT_DIR/00-prereqs.sh"
bash "$SCRIPT_DIR/01-storage.sh"
bash "$SCRIPT_DIR/02-cosmos.sh"
bash "$SCRIPT_DIR/03-monitor.sh"
bash "$SCRIPT_DIR/04-connections.sh"
bash "$SCRIPT_DIR/05-logicapps.sh"
bash "$SCRIPT_DIR/06-static-site-storage.sh"
bash "$SCRIPT_DIR/07-write-config.sh"
bash "$SCRIPT_DIR/08-setup-gh-secrets.sh"

cat <<'BANNER'

═══════════════════════════════════════════════════════════════
 ✓ ThreatVault deployment complete
═══════════════════════════════════════════════════════════════
 Next steps:
 1. GitHub Secrets: AZURE_CREDENTIALS and STORAGE_ACCOUNT_NAME
    have been automatically configured via 'gh' CLI.
 2. Push to main — GitHub Actions will deploy the front-end.
 3. Open the URL printed above and log in
    (analyst@threatvault.com / ThreatVault1!)
═══════════════════════════════════════════════════════════════
BANNER

#!/usr/bin/env bash
# ThreatVault — central deployment parameters.
# Edit RG_NAME, SUFFIX or LOCATION before running deploy-all.sh.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Region pinned to italynorth (CW2 brief & Azure Policy region lock).
LOCATION="${LOCATION:-italynorth}"

# Short alphanumeric suffix to keep names globally unique (storage, cosmos, swa).
STATE_SUFFIX="$SCRIPT_DIR/.state.suffix"
if [[ -f "$STATE_SUFFIX" ]]; then
  SUFFIX="$(cat "$STATE_SUFFIX")"
else
  SUFFIX="${SUFFIX:-tv$(printf '%s' "$(whoami)$(date +%s)" | shasum | cut -c1-6)}"
  echo "$SUFFIX" > "$STATE_SUFFIX"
fi

# Resource group
RG_NAME="${RG_NAME:-rg-threatvault}"

# Resource names (override via env if you want)
STORAGE_NAME="${STORAGE_NAME:-st${SUFFIX}}"          # Storage account (Blob)
EVIDENCE_CONTAINER="${EVIDENCE_CONTAINER:-evidence}" # Blob container

COSMOS_NAME="${COSMOS_NAME:-cosmos-${SUFFIX}}"       # Cosmos DB account
COSMOS_DB="${COSMOS_DB:-threatvault}"                # Database
COSMOS_EVIDENCE="${COSMOS_EVIDENCE:-evidence}"       # Containers
COSMOS_CASES="${COSMOS_CASES:-cases}"
COSMOS_AUDIT="${COSMOS_AUDIT:-audit}"
COSMOS_USERS="${COSMOS_USERS:-users}"

LAW_NAME="${LAW_NAME:-law-threatvault}"              # Log Analytics workspace
APPI_NAME="${APPI_NAME:-appi-threatvault}"           # Application Insights
KV_NAME="${KV_NAME:-kv-${SUFFIX}}"                   # Key Vault

# API Connections (Logic Apps connectors)
CONN_COSMOS="${CONN_COSMOS:-conn-cosmos}"
CONN_BLOB="${CONN_BLOB:-conn-blob}"

# Logic Apps (Consumption) — one per CRUD operation, all method=POST.
LA_EV_LIST="${LA_EV_LIST:-la-evidence-list}"
LA_EV_CREATE="${LA_EV_CREATE:-la-evidence-create}"
LA_EV_UPDATE="${LA_EV_UPDATE:-la-evidence-update}"
LA_EV_DELETE="${LA_EV_DELETE:-la-evidence-delete}"
LA_CS_LIST="${LA_CS_LIST:-la-cases-list}"
LA_CS_CREATE="${LA_CS_CREATE:-la-cases-create}"
LA_CS_UPDATE="${LA_CS_UPDATE:-la-cases-update}"
LA_CS_DELETE="${LA_CS_DELETE:-la-cases-delete}"
LA_AU_LIST="${LA_AU_LIST:-la-audit-logs}"
LA_AU_LOG="${LA_AU_LOG:-la-audit-quicklog}"
LA_AUTH_LOGIN="${LA_AUTH_LOGIN:-la-auth-login}"
LA_AUTH_REGISTER="${LA_AUTH_REGISTER:-la-auth-register}"
LA_AUTH_PASSWORD="${LA_AUTH_PASSWORD:-la-auth-password}"
LA_AUTH_PROFILE="${LA_AUTH_PROFILE:-la-auth-profile}"
LA_AUTH_DELETE="${LA_AUTH_DELETE:-la-auth-delete}"
LA_EV_MODERATE="${LA_EV_MODERATE:-la-evidence-moderate}"   # Azure AI Content Safety
LA_AU_ANOMALY="${LA_AU_ANOMALY:-la-audit-anomaly}"         # Threshold-based anomaly detection

# Static Web App (frontend host)
SWA_NAME="${SWA_NAME:-swa-threatvault-${SUFFIX}}"

# Helper — print a banner
banner() { printf '\n\033[1;36m▶ %s\033[0m\n' "$*"; }
ok()     { printf '\033[32m✓ %s\033[0m\n'  "$*"; }
warn()   { printf '\033[33m⚠ %s\033[0m\n'  "$*"; }
fail()   { printf '\033[31m✗ %s\033[0m\n'  "$*" >&2; exit 1; }

# Subscription helper
ensure_logged_in() {
  az account show >/dev/null 2>&1 || fail "Not logged in. Run: az login"
  SUB_ID="$(az account show --query id -o tsv)"
  ok "Subscription: $(az account show --query name -o tsv) ($SUB_ID)"
}

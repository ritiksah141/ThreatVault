#!/usr/bin/env bash
# 11 — Deploy SQL API connection + 2 IOC Logic Apps (la-ioc-list, la-ioc-create).
# Reads .state.sql written by 10-sql.sh. Appends iocList / iocCreate endpoints
# to .state.endpoints.json and regenerates config.js via 07-write-config.sh.
# Zero changes to existing Cosmos / Blob / Logic App infrastructure.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/parameters.sh"
ensure_logged_in

[[ -f "$SCRIPT_DIR/.state.sql" ]] || fail "Run 10-sql.sh first"
source "$SCRIPT_DIR/.state.sql"

[[ -f "$SCRIPT_DIR/.state.endpoints.json" ]] || fail "Run 05-logicapps.sh first"

# ── SQL Logic App names ───────────────────────────────────────────────────────
LA_IOC_LIST="${LA_IOC_LIST:-la-ioc-list}"
LA_IOC_CREATE="${LA_IOC_CREATE:-la-ioc-create}"
CONN_SQL="${CONN_SQL:-conn-sql}"

# ── 1. Register Microsoft.Web provider (needed for API connections) ───────────
banner "Registering Microsoft.Web provider"
state="$(az provider show -n Microsoft.Web --query registrationState -o tsv 2>/dev/null || echo NotRegistered)"
if [[ "$state" != "Registered" ]]; then
  az provider register -n Microsoft.Web --wait >/dev/null
  ok "Microsoft.Web registered"
else
  ok "Microsoft.Web already registered"
fi

# ── 2. Deploy conn-sql API connection ────────────────────────────────────────
banner "Deploying SQL API connection: $CONN_SQL"
SQL_CONN_DEP="conn-sql-$(date +%s)"
SQL_CONN_ID="$(az deployment group create \
  -g "$RG_NAME" -n "$SQL_CONN_DEP" \
  -f "$SCRIPT_DIR/logicapps/_sql-connections.json" \
  --parameters \
    location="$LOCATION" \
    sqlServer="$SQL_HOST" \
    sqlDb="$SQL_DB" \
    sqlUser="$SQL_ADMIN" \
    sqlPass="$SQL_PASS" \
    connSql="$CONN_SQL" \
  --query "properties.outputs.sqlConnId.value" -o tsv)"
ok "conn-sql deployed: $SQL_CONN_ID"

# ── 3. Helper: deploy one SQL Logic App ──────────────────────────────────────
deploy_sql_workflow() {
  local name="$1" def="$2" key="$3"
  banner "Deploying $name ($def)"
  local depName="$name-$(date +%s)"
  local url
  url="$(az deployment group create \
    -g "$RG_NAME" -n "$depName" \
    -f "$SCRIPT_DIR/logicapps/_sql-template.json" \
    --parameters \
      workflowName="$name" \
      location="$LOCATION" \
      sqlConnId="$SQL_CONN_ID" \
      definition=@"$SCRIPT_DIR/logicapps/$def" \
    --query "properties.outputs.callbackUrl.value" -o tsv)"
  ok "$name deployed"
  # Merge into endpoints JSON
  python3 - "$SCRIPT_DIR/.state.endpoints.json" "$key" "$url" <<'PY'
import json, sys, pathlib
path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
data[sys.argv[2]] = sys.argv[3]
path.write_text(json.dumps(data, indent=2))
PY
}

# ── 4. Deploy IOC Logic Apps ──────────────────────────────────────────────────
deploy_sql_workflow "$LA_IOC_LIST"   "la-ioc-list.def.json"   "iocList"
deploy_sql_workflow "$LA_IOC_CREATE" "la-ioc-create.def.json" "iocCreate"

# ── 5. Persist state ──────────────────────────────────────────────────────────
{
  echo "LA_IOC_LIST=$LA_IOC_LIST"
  echo "LA_IOC_CREATE=$LA_IOC_CREATE"
  echo "CONN_SQL=$CONN_SQL"
  echo "SQL_CONN_ID=$SQL_CONN_ID"
} >"$SCRIPT_DIR/.state.sql-logicapps"
ok "Wrote $SCRIPT_DIR/.state.sql-logicapps"

# ── 6. Regenerate config.js ───────────────────────────────────────────────────
banner "Regenerating config.js"
bash "$SCRIPT_DIR/07-write-config.sh"

banner "SQL Logic Apps setup complete"
echo ""
echo "  IOC List   : $LA_IOC_LIST"
echo "  IOC Create : $LA_IOC_CREATE"
echo "  Endpoints appended to .state.endpoints.json"
echo "  config.js regenerated — redeploy SWA to publish"
echo ""

#!/usr/bin/env bash
# 10 — Azure SQL Server + Database + threat_intel table.
# Additive only — zero changes to existing Cosmos / Blob / Logic App infrastructure.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/parameters.sh"
ensure_logged_in

# ── SQL-specific names (no overlap with any existing resource) ────────────────
SQL_SERVER="${SQL_SERVER:-sql-${SUFFIX}}"
SQL_DB="${SQL_DB:-threatvault}"
SQL_ADMIN="${SQL_ADMIN:-tvadmin}"
# Deterministic password derived from suffix — meets Azure complexity rules.
SQL_PASS="${SQL_PASS:-Tv@${SUFFIX}Azure1!}"
SQL_HOST="${SQL_SERVER}.database.windows.net"

# ── 1. Register provider (idempotent) ────────────────────────────────────────
banner "Registering Microsoft.Sql provider"
state="$(az provider show -n Microsoft.Sql --query registrationState -o tsv 2>/dev/null || echo NotRegistered)"
if [[ "$state" != "Registered" ]]; then
  az provider register -n Microsoft.Sql --wait >/dev/null
  ok "Microsoft.Sql registered"
else
  ok "Microsoft.Sql already registered"
fi

# ── 2. SQL Server ─────────────────────────────────────────────────────────────
banner "Creating Azure SQL Server: $SQL_SERVER"
if az sql server show -n "$SQL_SERVER" -g "$RG_NAME" >/dev/null 2>&1; then
  ok "SQL Server $SQL_SERVER already exists — skipping"
else
  az sql server create \
    -n "$SQL_SERVER" -g "$RG_NAME" -l "$LOCATION" \
    --admin-user "$SQL_ADMIN" \
    --admin-password "$SQL_PASS" \
    --tags project=ThreatVault module=COM682 >/dev/null
  ok "SQL Server created"
fi

# ── 3. Firewall — allow Azure services ───────────────────────────────────────
banner "Firewall rule: allow Azure services"
az sql server firewall-rule create \
  -g "$RG_NAME" --server "$SQL_SERVER" \
  -n AllowAzureServices \
  --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0 >/dev/null 2>&1 || true
ok "Firewall rule ready"

# ── 4. Database (Basic — cheapest tier, ~£4/mo) ───────────────────────────────
banner "Creating SQL Database: $SQL_DB"
if az sql db show -n "$SQL_DB" -s "$SQL_SERVER" -g "$RG_NAME" >/dev/null 2>&1; then
  ok "Database $SQL_DB already exists — skipping"
else
  az sql db create \
    -g "$RG_NAME" --server "$SQL_SERVER" \
    -n "$SQL_DB" \
    --edition Basic --capacity 5 \
    --tags project=ThreatVault >/dev/null
  ok "Database created"
fi

# ── 5. Write init.sql ─────────────────────────────────────────────────────────
SQL_DIR="$SCRIPT_DIR/sql"
mkdir -p "$SQL_DIR"
cat >"$SQL_DIR/init.sql" <<'SQL'
-- ThreatVault SQL schema — Threat Intelligence IOC table.
-- Run once in Azure Portal → SQL Database → Query Editor
-- or via: sqlcmd -S <host> -d threatvault -U tvadmin -P <pass> -i infra/sql/init.sql

IF NOT EXISTS (
  SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[threat_intel]') AND type = 'U'
)
BEGIN
  CREATE TABLE [dbo].[threat_intel] (
    [id]          INT            IDENTITY(1,1) NOT NULL PRIMARY KEY,
    [ioc_type]    NVARCHAR(50)   NOT NULL,        -- IP | Domain | Hash | CVE | URL
    [ioc_value]   NVARCHAR(500)  NOT NULL,
    [severity]    NVARCHAR(20)   NOT NULL DEFAULT 'Medium',  -- Critical | High | Medium | Low
    [source]      NVARCHAR(255)  NULL,
    [description] NVARCHAR(1000) NULL,
    [created_at]  DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME()
  );
  PRINT 'threat_intel table created.';
END
ELSE
BEGIN
  PRINT 'threat_intel table already exists — skipped.';
END
SQL
ok "Wrote $SQL_DIR/init.sql"

# ── 6. Run init.sql (auto if sqlcmd available, else print instructions) ───────
banner "Initialising schema"
if command -v sqlcmd >/dev/null 2>&1; then
  ok "sqlcmd found — running init.sql"
  sqlcmd -S "$SQL_HOST" -d "$SQL_DB" \
         -U "$SQL_ADMIN" -P "$SQL_PASS" \
         -i "$SQL_DIR/init.sql"
  ok "Schema initialised via sqlcmd"
else
  warn "sqlcmd not installed — run init.sql manually in the Azure Portal:"
  echo ""
  echo "  1. Portal → SQL databases → $SQL_DB → Query editor (preview)"
  echo "  2. Login: user=$SQL_ADMIN  password=$SQL_PASS"
  echo "  3. Paste and run the contents of:  infra/sql/init.sql"
  echo ""
fi

# ── 7. Persist state for 11-sql-logicapps.sh ──────────────────────────────────
{
  echo "SQL_SERVER=$SQL_SERVER"
  echo "SQL_DB=$SQL_DB"
  echo "SQL_ADMIN=$SQL_ADMIN"
  echo "SQL_PASS=$SQL_PASS"
  echo "SQL_HOST=$SQL_HOST"
} >"$SCRIPT_DIR/.state.sql"
ok "Wrote $SCRIPT_DIR/.state.sql"

banner "SQL setup complete"
echo ""
echo "  Server  : $SQL_HOST"
echo "  Database: $SQL_DB"
echo "  Admin   : $SQL_ADMIN"
echo "  Next    : run  bash infra/11-sql-logicapps.sh"
echo ""

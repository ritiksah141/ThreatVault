#!/usr/bin/env bash
# 02 — Cosmos DB (NoSQL/SQL API) account, database, three containers.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/parameters.sh"
ensure_logged_in

banner "Creating Cosmos DB account $COSMOS_NAME (this can take ~5 min)"
az cosmosdb create \
  -n "$COSMOS_NAME" -g "$RG_NAME" \
  --kind GlobalDocumentDB \
  --locations regionName="$LOCATION" failoverPriority=0 isZoneRedundant=False \
  --default-consistency-level Session \
  --enable-free-tier true \
  --tags project=ThreatVault >/dev/null 2>&1 || \
az cosmosdb create \
  -n "$COSMOS_NAME" -g "$RG_NAME" \
  --kind GlobalDocumentDB \
  --locations regionName="$LOCATION" failoverPriority=0 isZoneRedundant=False \
  --default-consistency-level Session \
  --tags project=ThreatVault >/dev/null
ok "Cosmos DB account ready"

banner "Creating database $COSMOS_DB"
az cosmosdb sql database create \
  -a "$COSMOS_NAME" -g "$RG_NAME" -n "$COSMOS_DB" >/dev/null
ok "Database ready"

create_container() {
  local name="$1" pk="$2"
  banner "Creating container '$name' (partition key $pk)"
  az cosmosdb sql container create \
    -a "$COSMOS_NAME" -g "$RG_NAME" -d "$COSMOS_DB" \
    -n "$name" -p "$pk" --throughput 400 >/dev/null
  ok "Container '$name' ready"
}

create_container "$COSMOS_EVIDENCE" "/caseID"
create_container "$COSMOS_CASES"    "/id"
create_container "$COSMOS_AUDIT"    "/user"
create_container "$COSMOS_USERS"    "/email"

# Persist key + endpoint
KEY="$(az cosmosdb keys list -n "$COSMOS_NAME" -g "$RG_NAME" --query primaryMasterKey -o tsv)"
ENDPOINT="$(az cosmosdb show -n "$COSMOS_NAME" -g "$RG_NAME" --query documentEndpoint -o tsv)"
STATE="$SCRIPT_DIR/.state"
{
  echo "COSMOS_NAME=$COSMOS_NAME"
  echo "COSMOS_KEY=$KEY"
  echo "COSMOS_ENDPOINT=$ENDPOINT"
} >"$STATE.cosmos"
ok "Wrote $STATE.cosmos"

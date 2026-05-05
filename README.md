# ThreatVault — COM682 Cloud Native Development (CW2)

ThreatVault is a cloud-native digital-evidence vault for security analysts.
Binary evidence manifests live in **Azure Blob Storage**, metadata in
**Azure Cosmos DB (NoSQL)**, CRUD is served by **Azure Logic Apps**
(REST endpoints), and the front-end is hosted on **Azure Static Web Apps**.
Operational telemetry flows into **Application Insights** + **Log Analytics**;
secrets are kept in **Azure Key Vault**. Region is pinned to **Italy North**.

---

## Architecture

```
┌────────────────┐   HTTPS (CORS-simple POST, JSON)
│  Static Web App│ ──────────────────────────────►  ┌──────────────────────────┐
│  index.html    │                                  │ 10× Logic App (POST)     │
│  config.js     │ ◄─── Application Insights ───────│  evidence-{list,create,  │
└────────────────┘                                  │   update,delete}         │
        ▲                                            │  cases-{list,create,    │
        │ GitHub Actions (push to main)              │   update,delete}        │
        │                                            │  audit-{list,quicklog}  │
   GitHub repo                                       └──────────┬───────────────┘
                                                                │
                                  ┌─────────────────────────────┼───────────────┐
                                  ▼                             ▼               ▼
                          ┌──────────────┐            ┌──────────────────┐  ┌──────────┐
                          │ Cosmos DB    │            │ Blob Storage     │  │ Key Vault│
                          │ NoSQL        │            │ container:       │  │ secrets  │
                          │ evidence /   │            │ "evidence"       │  └──────────┘
                          │ cases /audit │            │ (JSON manifests) │
                          └──────────────┘            └──────────────────┘
```

---

## Repository layout

```
.
├── index.html                       # Single-page front-end
├── config.js                        # Endpoints + region (auto-generated)
├── staticwebapp.config.json         # SWA routing/headers
├── .github/workflows/
│   └── azure-static-web-apps.yml    # CI/CD to SWA on push to main
└── infra/
    ├── parameters.sh                # Central names & helpers
    ├── deploy-all.sh                # Master deploy script (00 → 07)
    ├── teardown.sh                  # az group delete --no-wait
    ├── 00-prereqs.sh                # Provider registration + RG
    ├── 01-storage.sh                # Storage account + blob container
    ├── 02-cosmos.sh                 # Cosmos DB + 3 containers
    ├── 03-monitor.sh                # Log Analytics + App Insights + Key Vault
    ├── 04-connections.sh            # Logic Apps API connections (cosmos, blob)
    ├── 05-logicapps.sh              # 10× Logic App workflows
    ├── 06-static-web-app.sh         # SWA Free tier
    ├── 07-write-config.sh           # Generate config.js from state
    └── logicapps/
        ├── _connections.json        # ARM template — API connections
        ├── _template.json           # ARM template — generic Logic App wrapper
        └── la-*.def.json            # 10 workflow definitions
```

---

## Prerequisites

* Azure subscription with Contributor on the target subscription
* `az` CLI ≥ 2.55 (`az login` already done)
* `bash`, `jq`
* GitHub repository with this code pushed

---

## Deploy

```bash
# 1. Provision every Azure resource (italynorth)
bash infra/deploy-all.sh

# 2. Add the SWA deploy token from infra/.state.swa as a GitHub secret named
#    AZURE_STATIC_WEB_APPS_API_TOKEN

# 3. git push origin main   →  GitHub Actions deploys index.html + config.js
```

`deploy-all.sh` runs `00 → 07` in sequence. Each script is safe to re-run; Azure CLI
`create` is upsert-style for the resource types we use.

### Teardown

```bash
bash infra/teardown.sh   # az group delete --no-wait
```

---

## CW2 rubric coverage

| Rubric criterion | Where it's met |
| --- | --- |
| **Storage for binary data (Blob)** | `01-storage.sh` — `evidence` container; `la-evidence-create` writes JSON manifests; `la-evidence-delete` removes them |
| **NoSQL / RDS storage** | `02-cosmos.sh` — Cosmos DB SQL API, 3 containers with partition keys (`/caseID`, `/id`, `/user`) |
| **REST CRUD API (Logic Apps)** | `05-logicapps.sh` + `logicapps/la-*.def.json` — 10 endpoints, one per CRUD verb across `evidence` / `cases` / `audit` |
| **CI/CD via Git** | `.github/workflows/azure-static-web-apps.yml` — push to main = deploy |
| **Application Insights / Monitor** | `03-monitor.sh` — workspace-based App Insights wired into front-end via `config.js` |
| **Key Vault** | `03-monitor.sh` — stores `storage-key`, `cosmos-key`, `cosmos-endpoint` |
| **Region: Italy North** | `parameters.sh` LOCATION=italynorth, tagged on every resource |

### Region note

Static Web Apps' control plane currently lives in `westeurope` for italynorth-region
SWAs (Free tier limitation). Content is still served globally and tagged
`region=italynorth`. All other resources are deployed directly into Italy North.

### CORS note

Logic Apps Consumption can't natively answer the OPTIONS preflight, so the
front-end issues **CORS-simple** requests by sending `Content-Type: text/plain`
in `lcCall()` (no preflight needed). Each workflow returns
`Access-Control-Allow-Origin: *` in its `Response` action.

---

## Demo credentials (front-end only)

```
analyst@threatvault.com  /  ThreatVault1!
```

Used by the local SHA-256 login flow. Real auth is out of scope for CW2 —
the rubric scores the Azure plumbing, which lives behind the Logic Apps.

---

## Video walkthrough script (≈5 min)

1. **00:00** — open SWA URL; show login page; sign in (`analyst@…`).
2. **00:30** — open the Azure Portal → resource group `rg-threatvault`; pan over
   resources (storage, cosmos, 10 logic apps, app insights, key vault, swa).
   Confirm all are in **Italy North** (or westeurope tag for SWA control plane).
3. **01:15** — back in the app, create a Case → show it appear in Cosmos DB
   `cases` container.
4. **02:00** — submit Evidence linked to the case → show:
   * new doc in Cosmos `evidence` container (with SHA-256 hash, partitioned by caseID)
   * new JSON manifest in Blob container `evidence`
5. **02:45** — open the Audit tab → entry shows `evidence.create` event;
   open the same audit container in Cosmos.
6. **03:15** — edit + delete an evidence record; show audit entries appear.
7. **03:45** — Application Insights → Live Metrics; refresh the SPA; show
   page-views + custom events.
8. **04:15** — Key Vault → show `storage-key`, `cosmos-key`, `cosmos-endpoint` secrets.
9. **04:30** — GitHub repo → make a tiny edit to `index.html`, push to main,
   show the Actions run, then refresh SWA.
10. **04:55** — wrap up: rubric checklist superimposed.

---

## Local / demo mode

If `config.js` has empty endpoint URLs the front-end falls back to an in-memory
demo dataset baked into `index.html`, so the page still works without Azure.
Useful for offline review.

---

## Credential-leak prevention (existing)

1. Install the scanner: `pip install detect-secrets`
2. Enable repo hooks: `git config core.hooksPath .githooks`
3. (Optional) Refresh the baseline: `detect-secrets scan > .secrets.baseline`

# ThreatVault — SETUP (deploy → test → vodcast)

A linear, step-by-step runbook for **your** machine. Repo, scripts, configs and
GitHub remote (`https://github.com/ritiksah141/ThreatVault.git`) are already
in place. Follow top-to-bottom.

Working directory: `/Users/ritiksah/ThreatVault`

---

## Already done (you don't need to redo these)

- Repo cloned to `~/ThreatVault`
- `infra/*.sh` are executable (`chmod +x` already applied)
- `config.js` placeholder, `staticwebapp.config.json`, `.github/workflows/azure-static-web-apps.yml`, `README.md`, `SETUP.md` all written
- 10 Logic App workflow definitions in `infra/logicapps/`
- `git remote origin` points at GitHub

You have on disk: `az 2.84.0`, `jq 1.7.1`, `git`. Good to go.

---

## 1. Sign in to Azure

```bash
az login
az account show --query "{name:name, id:id}" -o table
```

If you have multiple subs, pin the right one:

```bash
az account set --subscription "<SUBSCRIPTION_NAME_OR_ID>"
```

**Verify:** the printed subscription is the one you want to deploy into.

> Student-tier note: if `italynorth` is blocked on your sub, edit
> `infra/parameters.sh` and change `LOCATION` to `westeurope` or `northeurope`
> *before* step 2.

---

## 2. Run the master deploy script

**One command — runs every script in order:**

```bash
cd ~/ThreatVault && bash infra/deploy-all.sh
```

**With logging to a file (recommended — easier to debug if anything fails):**

```bash
cd ~/ThreatVault && bash infra/deploy-all.sh 2>&1 | tee infra/deploy.log
```

**Or run them one-by-one** (only needed if you want to re-run a single failed step):

```bash
bash infra/00-prereqs.sh
bash infra/01-storage.sh
bash infra/02-cosmos.sh
bash infra/03-monitor.sh
bash infra/04-connections.sh
bash infra/05-logicapps.sh
bash infra/06-static-site-storage.sh
bash infra/07-write-config.sh
bash infra/08-setup-gh-secrets.sh
```

Expect **8–12 minutes** total. You'll see banners like:

```
▶ Creating Storage account ...
✓ Storage created
▶ Creating Cosmos DB ...
...
✓ ThreatVault deployment complete
```

**If a step fails** — fix the cause (region, quota, name conflict) and re-run.
The script is idempotent.

**Verify after success:**

```bash
az group show -n rg-threatvault \
  --query "{name:name, location:location, state:properties.provisioningState}" -o table
ls infra/.state.*           # endpoints.json, monitor, swa, suffix
```

---

## 3. Confirm the 10 Logic App URLs were captured

```bash
jq '. | keys' infra/.state.endpoints.json
```

Expected (order may differ):

```json
[
  "auditCreate", "auditList",
  "casesCreate", "casesDelete", "casesList", "casesUpdate",
  "evidenceCreate", "evidenceDelete", "evidenceList", "evidenceUpdate"
]
```

If a key is missing → re-run `bash infra/05-logicapps.sh`.

---

## 4. Confirm `config.js` was generated with live URLs

```bash
head -25 config.js
```

You should see real `https://prod-...italynorth.logic.azure.com:443/...` URLs in
the `endpoints` block. If they're empty strings, re-run
`bash infra/07-write-config.sh`.

---

## 5. Automated GitHub Setup

The script `bash infra/08-setup-gh-secrets.sh` (run as part of `deploy-all.sh`)
automatically creates an Azure Service Principal and sets up the following
secrets in your GitHub repo:

1. `AZURE_CREDENTIALS` (JSON block for login)
2. `STORAGE_ACCOUNT_NAME` (e.g. `sttv5fb957`)

**Verify they are set:**
Open https://github.com/ritiksah141/ThreatVault/settings/secrets/actions

---

## 6. Commit and push everything

```bash
cd ~/ThreatVault
git add -A
git status                                   # sanity-check what is staged
git commit -m "ThreatVault CW2: infra + storage hosting + CI/CD - v:1.1"
git push origin main
```

---

## 7. Watch the GitHub Actions run

1. https://github.com/ritiksah141/ThreatVault/actions → click the latest run.
2. Wait for **Build and deploy** (Deploy ThreatVault Frontend to Azure Storage) to turn green (≈1–2 min).

If it fails:
* Check the logs in the **Upload to Blob Storage** step.

---

## 8. Open the deployed site

```bash
open "https://$(grep '^SWA_HOST=' infra/.state.swa | cut -d= -f2-)"
```

You should see the ThreatVault login page.

---

## 10. Smoke-test in the browser (this is also your record-rehearsal)

Sign in with the demo credentials baked into the front-end:

```
analyst@threatvault.com
ThreatVault1!
```

Walk every CRUD path so you know Azure plumbing works.

### 10.1 — Cases (Cosmos CRUD)

1. Cases tab → New case → title `Demo Case A`, severity High → Save.
2. Open the case, change severity → Save.
3. Delete one (do this **after** the evidence demo below).

**Verify in Azure**: Portal → Cosmos DB account → Data Explorer →
`threatvault > cases` → see the doc.

### 10.2 — Evidence (Cosmos + Blob CRUD)

1. Evidence tab → New evidence linked to `Demo Case A`. Description + a small
   file or text — SHA-256 is computed in-browser. Save.
2. Edit the evidence (change description) → Save.
3. Delete it.

**Verify in Azure**:
* Cosmos `evidence` container → doc with the SHA-256 hash, `caseID` partition.
* Storage account → container `evidence` → JSON manifest blob.

### 10.3 — Audit (Cosmos)

Open the **Audit** tab. You should see entries for `case.create`,
`evidence.create`, `evidence.update`, `evidence.delete`.

**Verify in Azure**: Cosmos `audit` container → matching docs partitioned by `/user`.

### 10.4 — Application Insights

1. Portal → `appi-threatvault` → **Live Metrics** (keep open).
2. In the SPA, click around / refresh.
3. Confirm request counts climb in Live Metrics.

---

## 11. Record the vodcast (≈5 min)

Record on macOS with `Cmd+Shift+5` → **Record Entire Screen** (or use OBS/Loom).
Speak over each step.

Pre-stage these tabs/windows before pressing record:

* **Browser tab A** — your deployed SWA URL (logged out)
* **Browser tab B** — Azure Portal → resource group `rg-threatvault`
* **Browser tab C** — https://github.com/ritiksah141/ThreatVault/actions
* **Terminal** — already in `~/ThreatVault`

### Vodcast script (timed)

| Time | Action | What to say |
| --- | --- | --- |
| 0:00 | Show SWA URL + login screen, sign in | "ThreatVault is deployed at this Static Web App URL. The frontend ships via GitHub Actions." |
| 0:30 | Switch to Azure Portal RG view | "Resource group `rg-threatvault` in **Italy North**: storage, Cosmos DB, App Insights, Log Analytics, Key Vault, ten Logic Apps, and the Static Web App." |
| 1:15 | Back in SPA — create case `Demo Case A` | "Create-case calls the `cases-create` Logic App, writing to Cosmos `cases` partitioned by `/id`." |
| 1:35 | Portal → Cosmos → cases → show doc | "The doc that just appeared." |
| 2:00 | SPA → submit evidence linked to that case | "Evidence is hashed in-browser with SHA-256, then `evidence-create` writes a JSON manifest to Blob and metadata to Cosmos." |
| 2:30 | Portal → Storage → container `evidence` → blob | "Blob manifest." |
| 2:45 | Portal → Cosmos → evidence → doc | "Cosmos metadata, `/caseID` partition." |
| 3:00 | SPA → edit + delete an evidence record | "Update and delete go through `evidence-update` and `evidence-delete`." |
| 3:20 | SPA → Audit tab | "Every operation is journalled by `audit-create`." |
| 3:40 | Portal → App Insights → Live Metrics, refresh SPA | "Application Insights wired via the connection string in `config.js`." |
| 4:00 | Portal → Key Vault → Secrets list | "Cosmos and Storage keys live in Key Vault, never in the repo." |
| 4:15 | Terminal: small edit, commit, push | "Push to main triggers GitHub Actions…" |
| 4:35 | GitHub → Actions → green run | "…which deploys the frontend automatically." |
| 4:50 | SPA — refresh, show the change | "Change is live." |
| 5:00 | End | "ThreatVault: COM682 CW2." |

**Stop recording**, save as `ThreatVault-CW2-walkthrough.mp4`.

---

## 12. (Optional) Tear down to save credit

```bash
bash infra/teardown.sh
# type "yes" when prompted
```

---

## Troubleshooting cheat-sheet

| Symptom | Fix |
| --- | --- |
| `az login` opens browser then errors | `az login --use-device-code` |
| `Location 'italynorth' not available` | Edit `infra/parameters.sh` → `LOCATION=westeurope`, then re-run step 2 |
| Logic App returns 500 / `BadRequest` | Open the run history in Portal — usually a missing field in the JSON payload |
| Browser console: CORS preflight error | Don't change `Content-Type` away from `text/plain` in `lcCall()` |
| `config.js` endpoints are blank | Re-run `bash infra/07-write-config.sh` |
| GitHub Action fails (Azure Login) | Re-run `bash infra/08-setup-gh-secrets.sh` to refresh credentials |
| SWA shows old version after push | Wait 30s for CDN; hard-refresh (`Cmd+Shift+R`) |

That's it — deploy, test, record, submit.

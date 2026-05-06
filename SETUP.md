# ThreatVault — SETUP (deploy → test → vodcast)

A linear, step-by-step runbook. Repo, scripts, configs, and the GitHub remote
(`https://github.com/ritiksah141/ThreatVault.git`) are already in place — follow
top-to-bottom.

Working directory: `/Users/ritiksah/ThreatVault`

---

## Already done (you don't need to redo these)

- Repo cloned to `~/ThreatVault`
- `infra/*.sh` are executable (`chmod +x` already applied)
- `staticwebapp.config.json`, `.github/workflows/azure-static-web-apps.yml`, `README.md`, `SETUP.md` all written
- **17** Logic App workflow definitions in `infra/logicapps/`
  (5 evidence incl. moderate · 4 cases · 3 audit incl. anomaly · **5 auth**)
- `git remote origin` points at GitHub

You have on disk: `az 2.84.0`, `jq 1.7.1`, `gh`, `git`, `python3`. Good to go.

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

The suffix is pinned in `infra/.state.suffix` (e.g. `tv5fb957`) so re-running
**reuses** existing storage / cosmos / static-website resources rather than
creating duplicates.

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
bash infra/01-storage.sh           # mints a 90-day read-only SAS for evidence container
bash infra/02-cosmos.sh
bash infra/03-monitor.sh
bash infra/04-connections.sh
bash infra/09-ai.sh                # Content Safety F0 — must precede 05
bash infra/05-logicapps.sh         # 17 workflows; substitutes CS endpoint/key
bash infra/06-static-site-storage.sh
bash infra/07-write-config.sh      # writes endpoints + AppI conn-string + SAS into config.js
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

> ⚠️ Step 05 always rotates the trigger SAS signatures on every Logic App, so
> step 07 must follow it (it's already chained inside `deploy-all.sh`).

**If a step fails** — fix the cause (region, quota, name conflict) and re-run.
Each script is idempotent.

**Verify after success:**

```bash
az group show -n rg-threatvault \
  --query "{name:name, location:location, state:properties.provisioningState}" -o table
ls infra/.state.*           # endpoints.json, monitor, swa, suffix, conn.json, ...
```

---

## 3. Confirm all 17 Logic App URLs were captured

```bash
jq '. | keys | length' infra/.state.endpoints.json   # → 17
jq '. | keys' infra/.state.endpoints.json
```

Expected (order may differ):

```json
[
  "auditAnomaly", "auditCreate", "auditList",
  "authDelete", "authLogin", "authPassword", "authProfile", "authRegister",
  "casesCreate", "casesDelete", "casesList", "casesUpdate",
  "evidenceCreate", "evidenceDelete", "evidenceList", "evidenceModerate", "evidenceUpdate"
]
```

If a key is missing → re-run `bash infra/05-logicapps.sh && bash infra/07-write-config.sh`.

---

## 4. Confirm `config.js` was generated with live URLs

```bash
grep -E '"authLogin"|"authRegister"|"authPassword"|"authProfile"|"authDelete"' config.js | wc -l
# → 5
```

You should see real `https://prod-...italynorth.logic.azure.com:443/...` URLs in
the `endpoints` block. If they're empty strings or the count is wrong, re-run
`bash infra/07-write-config.sh`.

---

## 5. Automated GitHub Setup

`bash infra/08-setup-gh-secrets.sh` (run as part of `deploy-all.sh`)
automatically pushes the following secrets to your GitHub repo:

1. `AZURE_STORAGE_ACCOUNT` (e.g. `sttv5fb957`)
2. `AZURE_STORAGE_KEY` (primary key)

The Actions workflow uses these to `az storage blob upload-batch` to `$web`.

**Verify they are set:**
Open https://github.com/ritiksah141/ThreatVault/settings/secrets/actions

---

## 6. Commit and push everything

```bash
cd ~/ThreatVault
git add -A
git status                                   # sanity-check what is staged
git commit -m "ThreatVault CW2: live auth Logic Apps + landing page"
git push origin main
```

---

## 7. Watch the GitHub Actions run

```bash
gh run watch
```

Or in the browser:

1. https://github.com/ritiksah141/ThreatVault/actions → click the latest run.
2. Wait for **Deploy ThreatVault Frontend to Azure Storage** to turn green (≈1–2 min).

If it fails → check the logs in the **Upload to Blob Storage** step.

---

## 8. Open the deployed site

```bash
open "https://$(grep '^SWA_HOST=' infra/.state.swa | cut -d= -f2-)"
```

You should see the **landing page** (hero + feature cards). Hard-refresh
(`Cmd+Shift+R`) if you're seeing a stale cached version.

---

## 9. Smoke-test in the browser (this is also your record-rehearsal)

The app is **purely live**. Two demo accounts are pre-seeded (password
`ThreatVault1!` for both):

| Email | Display name | Role |
| --- | --- | --- |
| `analyst@threatvault.com` | Sarah Chen | Analyst |
| `admin@threatvault.com`   | Ritik Sah  | Admin |

You can sign in with either, or click **Get started** to register a third
account. The seeded data includes 4 cases, 8 evidence (one Content-Safety-flagged),
and ~50 audit entries (with a deliberate burst by `analyst@…` in the last 60
minutes so the anomaly scan lights up).

### 9.1 — Register + Login (auth Logic Apps)

1. Landing → **Get started** → fill name, email, password (≥ 8 chars).
2. After register success, sign in with the same credentials.

**Verify in Azure**: Portal → Cosmos DB → `threatvault > users` →
new doc, partitioned by `/email`, with SHA-256 `passwordHash`.
Audit `audit` container has an `ACCOUNT_REGISTER` row.

### 9.2 — Cases (Cosmos CRUD)

1. Cases tab → New case → title `Demo Case A`, severity High → Save.
2. Open the case, change severity → Save.
3. Delete one (do this **after** the evidence demo below).

**Verify in Azure**: Cosmos `cases` container → see the doc.

### 9.3 — Evidence (Cosmos + Blob CRUD)

1. Evidence tab → New evidence linked to `Demo Case A`. Description + a small
   file or text — SHA-256 is computed in-browser. Save.
2. Edit the evidence (change description) → Save.
3. Delete it.

**Verify in Azure**:
* Cosmos `evidence` container → doc with the SHA-256 hash, `caseID` partition.
* Storage account → container `evidence` → uploaded media + JSON manifest.

### 9.4 — Profile + password (more auth Logic Apps)

1. Settings → **Profile** card → change display name + role → Save.
2. Settings → **Password** card → change password (verify with current).

**Verify in Azure**:
* `users` doc reflects the new name/role/passwordHash.
* `audit` container has `PROFILE_UPDATE` and `PASSWORD_CHANGE` rows.

### 9.5 — Audit (Cosmos) + Anomaly Scan

Open the **Audit** tab. You should see entries for `LOGIN`, `CREATE`,
`UPDATE`, `DELETE`, `PROFILE_UPDATE`, etc. Click **Anomaly Scan** — any user
with ≥ 5 actions in the last 60 minutes gets red-highlighted (the seeded
`analyst@threatvault.com` already qualifies).

### 9.6 — Content Safety auto-flag

Submit a new evidence item whose **notes** contain abusive/violent text.
Within ~1 s the card flips to a red **FLAGGED** badge — `la-evidence-moderate`
called Content Safety, the response surfaced severity ≥ 4, and the workflow
patched `flagged:true` + `contentModeratorStatus:rejected` onto the Cosmos doc.

### 9.7 — SAS download

Open any evidence card → **Download (SAS)**. The browser hits Blob Storage
directly using the read-only SAS in `config.js → storage.evidenceSas`
(account-key signed at deploy time, 90-day expiry, `sp=r&spr=https`).

### 9.8 — Application Insights

1. Portal → `appi-threatvault` → **Live Metrics** (keep open).
2. In the SPA, click around / refresh.
3. Confirm request counts climb in Live Metrics.
4. **Logs** → `customEvents | take 50` shows `Auth.Login`, `Evidence.Create`,
   `Case.Create`, `LogicApp.Error`.

---

## 10. Record the vodcast (≈5 min)

Record on macOS with `Cmd+Shift+5` → **Record Entire Screen** (or use OBS/Loom).
Speak over each step.

Pre-stage these tabs/windows before pressing record:

* **Browser tab A** — your deployed site URL (logged out, landing page)
* **Browser tab B** — Azure Portal → resource group `rg-threatvault`
* **Browser tab C** — https://github.com/ritiksah141/ThreatVault/actions
* **Terminal** — already in `~/ThreatVault`

### Vodcast script (timed)

| Time | Action | What to say |
| --- | --- | --- |
| 0:00 | Show landing page, click **Get started** | "ThreatVault is hosted on Azure Storage's static-website endpoint. The frontend ships via GitHub Actions on every push to main." |
| 0:20 | Register a fresh user → land on dashboard | "Registration calls `la-auth-register`, which inserts a SHA-256-hashed user into Cosmos and writes an audit row." |
| 0:50 | Portal → Cosmos → `users` → show new doc | "Partitioned by `/email`, never stores plaintext." |
| 1:15 | Portal → RG view | "Resource group `rg-threatvault` in **Italy North**: storage, Cosmos DB, App Insights, Log Analytics, Key Vault, **17** Logic Apps, **Azure AI Content Safety**, and the Storage static-website host." |
| 1:45 | SPA — create case `Demo Case A` | "`la-cases-create` writes to Cosmos `cases` partitioned by `/id`." |
| 2:05 | Portal → Cosmos → `cases` → show doc | "The doc that just appeared." |
| 2:25 | SPA — submit evidence linked to that case | "Evidence is hashed in-browser, the file goes to Blob, and metadata to Cosmos." |
| 2:40 | SPA — submit a second evidence with abusive notes | "Content Safety auto-flags it — red `FLAGGED` badge, no manual review." |
| 2:50 | SPA — click **Download (SAS)** on an evidence card | "Read-only SAS, 90-day expiry, account key never touches the browser." |
| 2:55 | Portal → Storage → `evidence` container → blob | "Blob payload + manifest." |
| 3:10 | Portal → Cosmos → `evidence` → doc | "Cosmos metadata, `/caseID` partition; flagged doc shows `contentModeratorStatus:rejected`." |
| 3:25 | SPA — Audit tab → click **Anomaly Scan** | "Threshold-based scan over the last 60 min — burst behaviour lights up red." |
| 3:45 | Settings → change display name | "`la-auth-profile` updates the `users` doc and emits `PROFILE_UPDATE`." |
| 4:00 | Portal → App Insights → Live Metrics, refresh SPA | "Application Insights — auto pageviews + custom events for auth/evidence/case actions." |
| 4:20 | Portal → Key Vault → Secrets list | "Cosmos and Storage keys live in Key Vault, never in the repo." |
| 4:35 | Terminal: small edit, commit, push | "Push to main triggers GitHub Actions…" |
| 4:50 | GitHub → Actions → green run | "…which deploys the frontend automatically." |
| 4:55 | SPA — hard-refresh, show the change | "Change is live." |
| 5:00 | End | "ThreatVault: COM682 CW2." |

**Stop recording**, save as `ThreatVault-CW2-walkthrough.mp4`.

---

## 11. (Optional) Tear down to save credit

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
| `config.js` endpoints are blank or count ≠ 17 | Re-run `bash infra/05-logicapps.sh && bash infra/07-write-config.sh` |
| `evidenceModerate` returns `Content Safety call failed` | `bash infra/09-ai.sh && bash infra/05-logicapps.sh` (the moderate workflow needs the CS endpoint substituted at deploy time) |
| Download (SAS) button missing or 403 | `config.js → storage.evidenceSas` is empty/expired — re-run `bash infra/01-storage.sh && bash infra/07-write-config.sh` |
| Login page says "Auth service is not configured" | `config.js` is missing `authLogin` / `authRegister` — re-run step 07 |
| GitHub Action fails (auth) | Re-run `bash infra/08-setup-gh-secrets.sh` to refresh credentials |
| Site shows old version after push | Wait 30s; hard-refresh (`Cmd+Shift+R`) |
| Service Pulse shows OFFLINE on a row | Click the row to retry; if persistent, open the Logic App run history |
| Duplicate Azure resources after re-deploy | `cat infra/.state.suffix` — must be the original suffix; if missing, restore it before re-running |

That's it — deploy, test, record, submit.

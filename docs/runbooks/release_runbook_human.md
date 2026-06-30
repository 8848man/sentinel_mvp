# Sentinel Production Release Runbook — Human Operator

**Audience:** Engineer performing the production deployment.  
**Companion:** See [`release_runbook_claude.md`](./release_runbook_claude.md) for all automated verification steps Claude performs in parallel.  
**Stack:** FastAPI on Cloud Run · PostgreSQL on Cloud SQL · Flutter Web on Firebase Hosting · Supabase Auth  
**Last updated:** 2026-06-30

---

## Before You Begin

This runbook covers the full release sequence from pre-flight to post-deploy monitoring.  
Work through it top to bottom. Do not skip a checkpoint.

**Estimated time:** 30–45 minutes  
**Required access:**
- [ ] GCP project IAM (`roles/run.admin`, `roles/cloudsql.admin`)
- [ ] Firebase Hosting deployment rights
- [ ] Cloud SQL instance credentials
- [ ] Supabase project dashboard access
- [ ] Secret Manager read access

---

## Section 1 — Pre-Deployment

### 1.1 Database Backup

**Purpose:** Create a recoverable snapshot before any schema changes.

**Prerequisites:**
- Cloud SQL Admin API enabled
- `gcloud` authenticated to the correct GCP project

**Procedure:**

```bash
# Confirm target project
gcloud config get-value project

# Trigger on-demand backup
gcloud sql backups create \
  --instance=sentinel-db \
  --description="pre-release-$(date +%Y%m%d-%H%M)"
```

**Expected result:** Command exits 0. Backup appears in Cloud Console → Cloud SQL → sentinel-db → Backups within 2–3 minutes.

**Failure handling:** If the command fails with an auth error, re-run `gcloud auth login` and verify project. If the instance is not found, confirm you are targeting the correct GCP project.

**Checkpoint:**
- [ ] Backup ID recorded: `_____________________`
- [ ] Backup status: `SUCCESSFUL`

---

### 1.2 Supabase Project Verification

**Purpose:** Confirm auth infrastructure is healthy before deploying backend changes.

**Prerequisites:** Supabase dashboard access.

**Procedure:**

1. Log in to [supabase.com](https://supabase.com) → project dashboard.
2. Navigate to **Authentication → Users**. Confirm sign-in is enabled.
3. Navigate to **Settings → API**. Record the Project URL and verify JWKS endpoint is reachable:

```bash
curl -s "<SUPABASE_URL>/auth/v1/.well-known/jwks.json" | python -m json.tool
```

4. Confirm the response contains at least one key with `"alg": "ES256"`.

**Expected result:** JWKS endpoint returns a valid JSON object with one or more keys.

**Failure handling:** If the JWKS endpoint is unreachable, do not proceed. Supabase auth must be healthy before the backend can verify JWTs.

**Checkpoint:**
- [ ] Supabase project URL confirmed: `_____________________`
- [ ] JWKS endpoint returns ES256 key

---

## Section 2 — Database Migration

### 2.1 Run Alembic Migration

**Purpose:** Apply schema changes to the production PostgreSQL database.

**Prerequisites:**
- Backup from Section 1.1 is `SUCCESSFUL`
- `DATABASE_URL` set to the production Cloud SQL connection string
- Python virtual environment with `alembic` and `asyncpg` installed

**Procedure:**

```bash
cd backend

# Confirm current migration state before applying
alembic current

# Apply all pending migrations
alembic upgrade head
```

**Expected result:** Each pending revision prints `Running upgrade <from> -> <to>`. The final line shows the head revision ID with no errors.

**Failure handling:**

| Symptom | Action |
|---|---|
| `FATAL: relation already exists` | Migration may be partially applied. Run `alembic current` and compare to `alembic heads`. Coordinate with Claude to identify which steps completed. |
| `connection refused` | Verify `DATABASE_URL` env var and Cloud SQL Auth Proxy status. |
| Migration rolls back with exception | Do not re-run. Check Cloud SQL logs. Restore from backup in Section 5.2 if data is corrupted. |

**Checkpoint:**
- [ ] `alembic current` shows `head` revision after upgrade
- [ ] No errors in migration output

---

### 2.2 Verify Migration Result

**Purpose:** Confirm that schema changes are live and correct.

**Procedure:**

```bash
# Connect to Cloud SQL
gcloud sql connect sentinel-db --user=postgres --database=sentinel

# Verify new columns on incidents table
\d incidents

# Verify analysis_jobs table exists
\d analysis_jobs

# Verify partial unique index
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'analysis_jobs';
```

**Expected result:**
- `incidents` has columns `analysis_status` (varchar 20, not null, default `'pending'`) and `analysis_error` (text, nullable).
- `analysis_jobs` table exists with columns: `id`, `incident_id`, `attempt_number`, `status`, `error_message`, `is_inferred`, `input_char_count`, `started_at`, `completed_at`, `created_at`.
- Index `uix_analysis_jobs_incident_active` appears in `pg_indexes`.

**Failure handling:** If columns or tables are missing, do not deploy the backend. Investigate `alembic history` to determine which migration did not apply.

**Checkpoint:**
- [ ] `analysis_status` column present on `incidents`
- [ ] `analysis_jobs` table present
- [ ] `uix_analysis_jobs_incident_active` index present

---

## Section 3 — Backend Deployment

### 3.1 Deploy Cloud Run Revision

**Purpose:** Release the new backend image to production traffic.

**Prerequisites:**
- New Docker image built and pushed to Artifact Registry
- All migration checkpoints from Section 2 passed

**Procedure:**

```bash
# Replace <IMAGE_SHA> with the commit SHA of the release
gcloud run deploy sentinel-backend \
  --image=asia-northeast3-docker.pkg.dev/<PROJECT_ID>/sentinel/backend:<IMAGE_SHA> \
  --region=asia-northeast3 \
  --platform=managed \
  --no-traffic
```

> Deploy with `--no-traffic` first. Traffic is shifted in step 3.2 after health verification.

**Expected result:** Command completes with `OK` and a new revision name is printed (e.g., `sentinel-backend-00042-xyz`).

**Failure handling:** If the deploy command fails, check Artifact Registry to confirm the image exists. If the revision is created but immediately crashes, check Cloud Run logs (Section 4.1) before shifting traffic.

**Checkpoint:**
- [ ] New revision name recorded: `_____________________`
- [ ] Revision status: `READY`

---

### 3.2 Verify Revision Health and Shift Traffic

**Purpose:** Confirm the new revision is healthy before it receives live traffic.

**Procedure:**

1. Open Cloud Console → Cloud Run → `sentinel-backend` → Revisions.
2. Find the new revision. Status must be `READY`.
3. Click the revision URL directly (not the service URL) and call the health endpoint:

```bash
curl -s https://<REVISION_URL>/health
# Expected: {"status": "ok", "version": "1.0.0"}

curl -s https://<REVISION_URL>/health/ready
# Expected: {"status": "ready"}
```

4. If both probes pass, shift 100% traffic to the new revision:

```bash
gcloud run services update-traffic sentinel-backend \
  --to-latest \
  --region=asia-northeast3
```

**Decision tree:**

```
/health → 200?
  YES → /health/ready → 200?
           YES → Shift traffic (step 4 above)
           NO  → DB connectivity issue — check Section 4.1 logs, do NOT shift traffic
  NO  → Container crash — check Section 4.1 logs, roll back (Section 5.1)
```

**Checkpoint:**
- [ ] `/health` returns `{"status": "ok"}`
- [ ] `/health/ready` returns `{"status": "ready"}`
- [ ] 100% traffic shifted to new revision

---

## Section 4 — Frontend Deployment

### 4.1 Deploy Firebase Hosting

**Purpose:** Release the new Flutter web build to the CDN.

**Prerequisites:**
- `flutter` SDK installed and on PATH
- `firebase-tools` installed and authenticated
- Backend `/health/ready` confirmed in Section 3.2

**Procedure:**

```bash
cd frontend/sentinel

# Build release artifact with production config
flutter build web --release \
  --dart-define=SUPABASE_URL=<SUPABASE_URL> \
  --dart-define=SUPABASE_ANON_KEY=<SUPABASE_ANON_KEY> \
  --dart-define=API_BASE_URL=<CLOUD_RUN_SERVICE_URL> \
  --dart-define=AUTH_PROVIDER=supabase \
  --dart-define=USE_MOCK_DATA=false

# Deploy to Firebase Hosting
cd ../..
firebase deploy --only hosting --project <PROJECT_ID>
```

**Expected result:** Firebase CLI prints `Deploy complete!` with a hosting URL.

**Failure handling:** If the Flutter build fails, check that all `--dart-define` values are set and match Secret Manager values. If Firebase deploy fails, verify `firebase.json` references `frontend/sentinel/build/web`.

**Checkpoint:**
- [ ] `flutter build web` completed with no errors
- [ ] Firebase deploy URL accessible in browser
- [ ] App loads without JS errors in DevTools console

---

## Section 5 — Post-Deployment Monitoring

### 5.1 Monitor Cloud Run Logs

**Purpose:** Detect runtime errors introduced by the new revision during the first 15 minutes of live traffic.

**Procedure:**

```bash
# Stream live logs from the new revision
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="sentinel-backend" AND severity>=WARNING' \
  --limit=50 \
  --freshness=15m \
  --format="table(timestamp, severity, textPayload)"
```

Alternatively, use Cloud Console → Logging → Log Explorer and filter by:
- Resource: `Cloud Run Revision`
- Severity: `WARNING` or higher

**Watch for:**
- `500 Internal Server Error` on any `POST /incidents` call
- `503 Database unavailable` from `/health/ready`
- Unhandled exceptions in the analysis background worker
- `asyncio` task errors

**Expected result:** No `ERROR` or `CRITICAL` log entries in the first 15 minutes.

**Failure handling:** If errors appear, capture the full stack trace from logs and proceed to Section 6 (Rollback) if errors are widespread or user-impacting.

**Checkpoint:**
- [ ] 15-minute log watch complete
- [ ] No `ERROR` or higher severity entries observed

---

## Section 6 — Rollback Procedures

### 6.1 Roll Back Cloud Run Revision

**Purpose:** Revert backend traffic to the last known-good revision without redeploying.

**When to use:** Backend is serving 500s, crashes, or `/health/ready` returns 503 after traffic shift.

**Procedure:**

```bash
# List recent revisions to find the previous good one
gcloud run revisions list \
  --service=sentinel-backend \
  --region=asia-northeast3 \
  --format="table(name, status.conditions[0].status, spec.traffic)"

# Route 100% traffic back to the previous revision
gcloud run services update-traffic sentinel-backend \
  --to-revisions=<PREVIOUS_REVISION_NAME>=100 \
  --region=asia-northeast3
```

**Expected result:** Traffic immediately returns to the previous revision. `/health` and `/health/ready` return 200.

**Checkpoint:**
- [ ] Previous revision name used: `_____________________`
- [ ] `/health/ready` returns 200 after rollback

---

### 6.2 Roll Back Firebase Hosting

**Purpose:** Revert the frontend to the previous hosting release.

**When to use:** Frontend is broken (blank page, JS errors, API URL misconfigured).

**Procedure:**

1. Open Firebase Console → Hosting → Release history.
2. Find the last successful release.
3. Click **Rollback** on that release.

Or via CLI:

```bash
firebase hosting:rollback --project <PROJECT_ID>
```

**Checkpoint:**
- [ ] Previous hosting release active
- [ ] App loads correctly in browser

---

### 6.3 Roll Back Database Migration

**Purpose:** Revert the database schema to the state before this migration.

**When to use:** Migration introduced a schema error that is causing backend failures AND a forward fix is not immediately available.

> **Warning:** Downgrade removes the `analysis_jobs` table and its data. Only proceed if directed by the incident lead and a backup exists.

**Procedure:**

```bash
cd backend

# Downgrade one revision
alembic downgrade -1

# Confirm state
alembic current
```

**After downgrade:** Also roll back the Cloud Run revision (Section 6.1) because the running backend expects the new schema.

**Checkpoint:**
- [ ] `alembic current` shows the pre-release revision
- [ ] Cloud Run rolled back to previous revision

---

## Section 7 — Production Checklist

Complete this checklist before closing the release window.

### Pre-Deployment
- [ ] On-demand database backup created and confirmed `SUCCESSFUL`
- [ ] Supabase JWKS endpoint healthy
- [ ] Alembic `upgrade head` completed without errors
- [ ] Schema verified: `analysis_status` column, `analysis_jobs` table, partial unique index

### Deployment
- [ ] Cloud Run revision deployed with `--no-traffic`
- [ ] `/health` and `/health/ready` both return 200 on new revision URL
- [ ] 100% traffic shifted to new revision
- [ ] Flutter web build completed with all `--dart-define` flags
- [ ] Firebase Hosting deploy completed
- [ ] Frontend loads in browser without console errors

### Post-Deployment
- [ ] 15-minute Cloud Run log watch: no `ERROR` or `CRITICAL` entries
- [ ] Claude smoke test passed (see [`release_runbook_claude.md`](./release_runbook_claude.md) → Section 4)
- [ ] Claude background job verification passed (see [`release_runbook_claude.md`](./release_runbook_claude.md) → Section 5)

### Rollback Readiness (confirm before starting)
- [ ] Previous Cloud Run revision name recorded: `_____________________`
- [ ] Backup ID recorded: `_____________________`
- [ ] Firebase rollback procedure reviewed

---

## Section 8 — Recovery Checklist

Use this checklist if an issue is detected post-deployment.

### Triage Decision Tree

```
Is the frontend broken (blank page / JS error)?
  YES → Roll back Firebase Hosting (Section 6.2) — no DB impact
  NO  → Continue

Is /health/ready returning 503?
  YES → DB connectivity issue
        → Check Cloud SQL instance status in GCP Console
        → Check DATABASE_URL secret in Secret Manager
        → If misconfigured secret: update Secret Manager, redeploy revision
        → If DB is down: escalate to DB admin
  NO  → Continue

Are POST /incidents returning 500?
  YES → Check Cloud Run logs for stack trace
        → Is the error in execute_analysis (background job)?
             YES → analysis_jobs table or schema mismatch suspected
                   → Run Claude schema verification (release_runbook_claude.md §2)
                   → If schema is wrong: roll back migration (Section 6.3)
             NO  → Identify error, hotfix, redeploy
  NO  → Continue

Are users unable to log in?
  YES → Supabase JWKS issue — check SUPABASE_URL in Secret Manager
        → Re-verify JWKS endpoint (Section 1.2)
```

### After Recovery
- [ ] Root cause documented
- [ ] All traffic confirmed on stable revision
- [ ] `/health/ready` returning 200
- [ ] Frontend loads without errors
- [ ] Post-mortem scheduled if user impact exceeded 5 minutes

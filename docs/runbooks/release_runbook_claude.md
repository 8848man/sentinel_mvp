# Sentinel Production Release Runbook — Claude Code

**Audience:** Claude Code performing automated verification during a production deployment.  
**Companion:** See [`release_runbook_human.md`](./release_runbook_human.md) for all steps that require a human operator.  
**Constraint:** Claude must never perform human-only actions (backup creation, traffic shifting, Firebase deploy, Alembic migration execution). When a human action is required, instruct the operator explicitly.

---

## How to Use This Runbook

Run sections in this order during a release:

1. **Pre-deployment verification** (before human runs migration)
2. **Migration verification** (after human runs `alembic upgrade head`)
3. **API compatibility verification** (after human deploys Cloud Run revision)
4. **Smoke testing** (after traffic is shifted)
5. **Background job verification** (15 minutes post-deploy)
6. **Rollback verification** (if human initiates rollback)
7. **Regression testing** (before closing the release window)

For each section: read the **Goal**, run the **Method**, check **Expected result** against actual output, and act on **Failure criteria** if something is wrong.

---

## Section 1 — Pre-Deployment Verification

### 1.1 Code Consistency Verification

**Goal:** Confirm that the migration file, ORM model, and service layer are mutually consistent before anything touches production.

**Method:**

Read the following files and cross-check:
- `backend/alembic/versions/a1b2c3d4e5f6_add_analysis_jobs.py` — DDL to be applied
- `backend/app/models/models.py` — SQLAlchemy ORM definitions
- `backend/app/services/incident_service.py` — service layer referencing new fields

Check:
1. Every column in the migration `upgrade()` function has a matching field in the ORM model.
2. Every field accessed in `incident_service.py` (`analysis_status`, `AnalysisJob`, etc.) exists in the ORM model.
3. Default values in the migration (`server_default='pending'`) match the ORM defaults.
4. The `down_revision` in the migration file matches the actual previous revision head (run `alembic history` or read the migration chain).

**Expected result:** No discrepancies. Each column in the migration appears in `models.py`. Service layer accesses only columns that exist.

**Failure criteria:** Any column referenced in `incident_service.py` that is absent from `models.py`, or absent from the migration.

**Suggested recovery:** Report the specific discrepancy to the operator. Do not proceed to deployment until the code is corrected and committed.

---

### 1.2 API Contract Verification

**Goal:** Confirm that the API schema contracts in `sdd/backend/05_api_spec.md` are consistent with the Pydantic schemas and router implementations.

**Method:**

Read:
- `backend/app/schemas/incident.py`
- `backend/app/routers/incidents.py`
- `sdd/backend/05_api_spec.md`

Check:
1. `POST /incidents` response includes `analysis_status` field (added in this release).
2. No endpoint returns a field that does not exist in the Pydantic response model.
3. All required request fields in the spec have corresponding validators in the Pydantic schema.

**Expected result:** Spec, schema, and router are consistent. `analysis_status` appears in the incident response schema.

**Failure criteria:** A field promised by the spec is missing from the Pydantic model, or a router returns an unvalidated field directly from the ORM.

**Suggested recovery:** Report the discrepancy. Operator must correct the schema before deploying.

---

### 1.3 Frontend API Compatibility Verification

**Goal:** Confirm that the Flutter frontend's API client handles the new `analysis_status` field and async response behavior introduced in this release.

**Method:**

Read:
- `frontend/sentinel/lib/core/api_client.dart`
- `frontend/sentinel/lib/features/incidents/data/` — incident data layer
- `frontend/sentinel/lib/features/incidents/domain/` — incident models

Check:
1. The incident model in the frontend has a field for `analysis_status` (or gracefully ignores unknown fields).
2. The frontend does not assume the incident response contains fully populated `fix_flows`, `root_cause`, or `confidence` immediately after `POST /incidents` — the async architecture means these may be null initially.
3. The frontend polls or handles a pending analysis state rather than treating null `root_cause` as an error.

**Expected result:** The frontend model can deserialize a response where `root_cause` is null and `analysis_status` is `"pending"`.

**Failure criteria:** Frontend model has no nullable handling for `root_cause`, or the UI crashes on a null analysis result.

**Suggested recovery:** Instruct operator to hold frontend deployment until the Flutter code is updated to handle the pending state.

---

## Section 2 — Migration Verification

> Run this section after the human operator has executed `alembic upgrade head` and completed `release_runbook_human.md` Section 2.

### 2.1 Schema Verification

**Goal:** Confirm the applied schema matches what the code expects, catching any partial-apply scenario.

**Method:**

Ask the operator to run the following query against the production database and share the output:

```sql
-- 1. Verify analysis_status column
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'incidents'
  AND column_name IN ('analysis_status', 'analysis_error');

-- 2. Verify analysis_jobs table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'analysis_jobs'
ORDER BY ordinal_position;

-- 3. Verify partial unique index
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'analysis_jobs'
  AND indexname = 'uix_analysis_jobs_incident_active';
```

**Expected result:**

| Table | Column | Expected |
|---|---|---|
| `incidents` | `analysis_status` | `varchar`, not null, default `'pending'` |
| `incidents` | `analysis_error` | `text`, nullable |
| `analysis_jobs` | all 10 columns | present |
| `pg_indexes` | `uix_analysis_jobs_incident_active` | present with `WHERE status IN ('pending', 'processing')` |

**Failure criteria:** Any column missing, wrong type, or wrong nullability. Index absent.

**Suggested recovery:** Report the specific gap to the operator. If the column is partially applied, the operator must decide whether to downgrade (`alembic downgrade -1`) or patch forward. Do not proceed to backend deployment until schema is fully verified.

---

### 2.2 Backfill Verification

**Goal:** Confirm that pre-existing incidents were backfilled with the correct inferred `analysis_jobs` rows.

**Method:**

Ask the operator to run:

```sql
-- Incidents with root_cause should have a 'completed' job
SELECT COUNT(*) AS should_be_zero
FROM incidents i
WHERE i.root_cause IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM analysis_jobs aj
    WHERE aj.incident_id = i.id AND aj.status = 'completed'
  );

-- Incidents without root_cause should have a 'failed' job
SELECT COUNT(*) AS should_be_zero
FROM incidents i
WHERE i.root_cause IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM analysis_jobs aj
    WHERE aj.incident_id = i.id AND aj.status = 'failed'
  );

-- All backfilled rows should be marked inferred
SELECT COUNT(*) AS inferred_count, COUNT(*) FILTER (WHERE is_inferred = TRUE) AS all_inferred
FROM analysis_jobs;
```

**Expected result:** Both `should_be_zero` queries return `0`. `inferred_count = all_inferred` (all backfilled rows are marked inferred).

**Failure criteria:** Any mismatch between `should_be_zero` queries. Any backfilled row with `is_inferred = FALSE`.

**Suggested recovery:** Partial backfill indicates the migration ran partially. Report to operator; do not proceed until the migration is confirmed complete or re-run.

---

## Section 3 — Post-Deploy API Verification

> Run this section after the human operator has deployed the Cloud Run revision and confirmed `/health/ready` returns 200.

### 3.1 Health Endpoint Verification

**Goal:** Confirm the live service health probes are responding correctly.

**Method:**

Ask the operator to provide the Cloud Run service URL, then verify:

```bash
# Liveness probe
curl -s https://<SERVICE_URL>/health
# Expected: {"status": "ok", "version": "1.0.0"}

# Readiness probe (DB connectivity)
curl -s https://<SERVICE_URL>/health/ready
# Expected: {"status": "ready"}
```

**Expected result:** Both return HTTP 200 with the exact bodies above.

**Failure criteria:** Either returns non-200, or `/health/ready` returns `{"detail": "Database unavailable"}`.

**Suggested recovery:**
- `/health` non-200: container crash — operator must check Cloud Run logs and roll back.
- `/health/ready` 503: database connectivity issue — operator must verify `DATABASE_URL` secret and Cloud SQL Auth Proxy attachment.

---

### 3.2 API Response Shape Verification

**Goal:** Confirm the deployed backend returns the expected response shape for the incident creation flow.

**Method:**

Ask the operator to perform a test incident creation using a valid Supabase JWT and the production API URL:

```bash
curl -s -X POST https://<SERVICE_URL>/api/v1/incidents \
  -H "Authorization: Bearer <SUPABASE_JWT>" \
  -H "Content-Type: application/json" \
  -d '{
    "log_text": "ERROR: connection pool exhausted",
    "title": "Smoke Test Incident",
    "severity": "minor",
    "components": ["test"]
  }'
```

Analyze the response and verify:
1. HTTP status is `201`.
2. Response body contains `"incident_code"` matching the pattern `INC-YYYY-NNN`.
3. Response body contains `"analysis_status": "pending"` (async architecture — analysis runs in background).
4. `"id"` field is a valid UUID string.
5. `"fix_flows"` is an empty array `[]` (not yet populated).
6. `"root_cause"` is `null` (not yet populated).

**Expected result:** All 6 checks pass.

**Failure criteria:**
- HTTP 500 → backend exception, check Cloud Run logs
- `analysis_status` is absent → schema or Pydantic model mismatch
- `fix_flows` is populated immediately → async worker ran synchronously (unexpected)
- HTTP 403 → JWT issue; verify Supabase URL and JWKS reachability

**Suggested recovery:** For HTTP 500, retrieve the stack trace from Cloud Run logs and report. For schema mismatches, instruct operator to roll back revision.

---

## Section 4 — Smoke Testing

> Run after traffic has been shifted 100% to the new revision.

### 4.1 Full Incident Lifecycle Smoke Test

**Goal:** Walk through the core user flow end-to-end to confirm no regression in the business logic.

**Method:**

Work with the operator (or use curl with a valid JWT) to exercise:

```
Step 1: POST /api/v1/incidents/analyze-metadata
  → { "log_text": "smoke test log" }
  → Expected: 200, response contains suggested_id, suggested_title, suggested_severity

Step 2: POST /api/v1/incidents
  → { log_text, title, severity: "minor", components: ["smoke-test"] }
  → Expected: 201, incident_code set, analysis_status = "pending"

Step 3: GET /api/v1/incidents/{id}  (wait 10–15 seconds)
  → Expected: analysis_status = "completed" or "failed"
  → If "completed": root_cause, confidence, fix_flows populated
  → If "failed": analysis_error populated, graceful — not a deployment blocker

Step 4: PATCH /api/v1/incidents/{id}
  → { "status": "in_progress" }
  → Expected: 200, status updated

Step 5: PATCH /api/v1/incidents/{id}/resolve
  → Expected: 200, status = "resolved", resolved_at set

Step 6: GET /api/v1/archive
  → Expected: 200, resolved incident appears in results
```

**Expected result:** All 6 steps return expected HTTP codes. No 500 errors.

**Failure criteria:** Any step returns 500, or step 2 returns a response without `analysis_status`.

**Suggested recovery:** Record which step failed and the full response body. Share with operator to decide rollback vs. hotfix.

---

### 4.2 Auth Boundary Verification

**Goal:** Confirm ownership enforcement — a user cannot access another user's incidents.

**Method:**

If two test user JWTs are available:

```bash
# Create incident with User A's JWT
POST /api/v1/incidents → incident_id = <ID_A>

# Attempt to access with User B's JWT
GET /api/v1/incidents/<ID_A>  (with User B JWT)
→ Expected: 403 Forbidden
```

**Expected result:** HTTP 403 when accessing another user's incident.

**Failure criteria:** HTTP 200 returned — cross-user data leak.

**Suggested recovery:** This is a critical security failure. Instruct operator to immediately roll back the revision and open a security incident.

---

## Section 5 — Background Job Verification

> Run 10–15 minutes after traffic is shifted, to confirm async analysis is working under real load.

### 5.1 Analysis Job Completion Rate

**Goal:** Confirm the async analysis worker is completing jobs, not stalling or erroring.

**Method:**

Ask the operator to run against the production database:

```sql
-- Job status distribution for jobs created in the last 30 minutes
SELECT status, COUNT(*) AS count
FROM analysis_jobs
WHERE created_at > NOW() - INTERVAL '30 minutes'
  AND is_inferred = FALSE
GROUP BY status;
```

**Expected result:**

| Status | Expected |
|---|---|
| `completed` | > 0 (at least some jobs finished) |
| `processing` | Low or 0 after 15 min (no stuck jobs) |
| `pending` | Low or 0 after 15 min (queue is draining) |
| `failed` | Should be 0 or very low for a healthy deployment |

**Failure criteria:**
- All jobs remain in `pending` or `processing` after 15 minutes → background worker is not executing.
- High `failed` count → Gemini API errors or schema issue in the worker.

**Suggested recovery:**
- Worker not executing: check Cloud Run logs for asyncio task errors. The background task is fired with `BackgroundTasks` in the router — if the process is crashing, new jobs will not start.
- High failure rate: read Cloud Run logs for the specific exception in `execute_analysis`. If it is a Gemini API quota error, it is transient. If it is a DB error, schema mismatch may be the cause.

---

### 5.2 Concurrency Constraint Verification

**Goal:** Confirm the partial unique index is enforcing the one-active-job-per-incident constraint.

**Method:**

Ask the operator to run:

```sql
-- Should return 0 rows: no incident should have 2+ active jobs
SELECT incident_id, COUNT(*) AS active_jobs
FROM analysis_jobs
WHERE status IN ('pending', 'processing')
  AND is_inferred = FALSE
GROUP BY incident_id
HAVING COUNT(*) > 1;
```

**Expected result:** Query returns 0 rows.

**Failure criteria:** Any row returned — the partial unique index is not enforcing the constraint. This would indicate a bug in the index definition or a failed migration step.

**Suggested recovery:** Report to operator. If the index is missing, the operator must apply it manually or downgrade and re-apply the migration.

---

## Section 6 — Rollback Verification

> Run this section only if the human operator has initiated a rollback per `release_runbook_human.md` Sections 6.1–6.3.

### 6.1 Backend Rollback Verification

**Goal:** Confirm the previous revision is serving traffic correctly after rollback.

**Method:**

```bash
curl -s https://<SERVICE_URL>/health/ready
# Expected: {"status": "ready"}
```

Then verify no 500s in recent Cloud Run logs:

```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND severity>=ERROR' \
  --limit=20 \
  --freshness=5m
```

**Expected result:** `/health/ready` returns 200. No new ERROR entries in logs.

**Failure criteria:** Still seeing 500s after rollback → the issue predates this release. Escalate.

---

### 6.2 Migration Rollback Verification

**Goal:** Confirm the schema has returned to the pre-release state after `alembic downgrade -1`.

**Method:**

Ask the operator to run:

```sql
-- analysis_jobs table should NOT exist after downgrade
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name = 'analysis_jobs';

-- analysis_status column should NOT exist on incidents
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'incidents'
  AND column_name = 'analysis_status';
```

**Expected result:** Both queries return 0 rows.

**Failure criteria:** Either returns a row — the downgrade did not fully execute. Report to operator; manual DDL cleanup may be required.

---

## Section 7 — Regression Testing

> Run after a successful deployment before the release window is closed.

### 7.1 Existing Incident Data Integrity

**Goal:** Confirm that pre-existing incidents were not corrupted by the migration's backfill.

**Method:**

Ask the operator to run:

```sql
-- No incidents should have null analysis_status
SELECT COUNT(*) AS null_status_count
FROM incidents
WHERE analysis_status IS NULL;

-- Status distribution should be coherent
SELECT analysis_status, COUNT(*)
FROM incidents
GROUP BY analysis_status;
```

**Expected result:**
- `null_status_count` is 0.
- All statuses are one of: `pending`, `completed`, `failed`.
- No unexpected values.

**Failure criteria:** `null_status_count > 0` or an unrecognized status value.

---

### 7.2 Archive Endpoint Regression

**Goal:** Confirm that the archive endpoint still returns resolved/closed incidents after the migration.

**Method:**

```bash
curl -s https://<SERVICE_URL>/api/v1/archive \
  -H "Authorization: Bearer <SUPABASE_JWT>"
```

**Expected result:** HTTP 200. Response body is `{ "data": [...], "total": N }`. If any incidents were resolved before this release, they appear in `data`.

**Failure criteria:** HTTP 500, or `data` is missing incidents that existed before the migration.

---

### 7.3 Checklist and Timeline Regression

**Goal:** Confirm that fix flow checklists and timeline events still function correctly — no cascade delete or FK breakage from the new `analysis_jobs` table.

**Method:**

Using the smoke test incident created in Section 4.1 (if it reached `completed` analysis):

```bash
# Verify fix flow checklist is accessible
GET /api/v1/incidents/{id}
→ Confirm fix_flows[0].checklist_items is populated (if analysis completed)

# Toggle a checklist item
PATCH /api/v1/checklist/{item_id}
→ { "is_completed": true }
→ Expected: 200, is_completed = true

# Verify timeline event was appended
GET /api/v1/incidents/{id}/timeline
→ Expected: timeline includes the step-completed event
```

**Expected result:** All three requests return expected results.

**Failure criteria:** Any 500, or timeline event missing after checklist toggle.

**Suggested recovery:** Isolate which operation failed. A checklist 500 may indicate a trigger or FK issue introduced by schema changes. Report to operator.

---

## Claude Operating Constraints

- **Never run Alembic commands.** Only the human operator runs `alembic upgrade` or `alembic downgrade`.
- **Never shift Cloud Run traffic.** Only the human operator runs `gcloud run services update-traffic`.
- **Never deploy to Firebase Hosting.** Only the human operator runs `firebase deploy`.
- **Never create or delete Cloud SQL backups.**
- **Never modify Secret Manager values.**
- When verification fails, always report the specific finding and suggested action. Never attempt to fix production state directly.
- When instructing the operator to run a database query, provide the exact SQL. Do not ask the operator to interpret or derive the query themselves.

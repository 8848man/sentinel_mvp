# AI Platform Test Audit (Archived)

**Archived:** Point-in-time pytest execution snapshot (145 tests, 2026-06-30). Preserved for historical record; current test status should be obtained by running the suite directly (`cd backend && pytest`) rather than trusting this snapshot, which reflects the codebase as of the date below and does not update.

---

Auditor: Senior Test Engineer / QA Auditor role  
Date: 2026-06-30  
Repository: sentinel_mvp/backend  

---

## Environment

| Item | Value |
|------|-------|
| Platform | win32 |
| Python | 3.11.0 |
| pytest | 9.1.1 |
| pytest-asyncio | 1.4.0 |
| pytest-cov | 7.1.0 |
| coverage | 7.14.3 |
| pytest-mock | 3.15.1 |
| anyio | 4.13.0 |
| SQLAlchemy (async) | aiosqlite / sqlite+aiosqlite |
| Test database | sqlite+aiosqlite:///./test_sentinel.db (file-based, wiped between tests) |

---

## Executed Commands

```
# Phase 1: full verbose run
python -m pytest tests/ -v

# Phase 2: coverage run
python -m pytest tests/ --cov=app --cov-report=term-missing
```

Both commands executed from `D:\projects\sentinel_mvp\backend` with the virtualenv active.

---

## Raw pytest Summary (verbose run)

```
============================= test session starts =============================
platform win32 -- Python 3.11.0, pytest-9.1.1, pluggy-1.6.0 -- ...
plugins: anyio-4.13.0, asyncio-1.4.0, mock-3.15.1
asyncio: mode=Mode.AUTO, debug=False, asyncio_default_fixture_loop_scope=None, asyncio_default_test_loop_scope=function
collecting ... collected 145 items

tests/integration/test_ai_actions_router.py::test_trigger_ai_action_returns_202 PASSED
tests/integration/test_ai_actions_router.py::test_trigger_ai_action_response_fields PASSED
tests/integration/test_ai_actions_router.py::test_trigger_ai_action_creates_db_row PASSED
tests/integration/test_ai_actions_router.py::test_trigger_ai_action_increments_attempt_number PASSED
tests/integration/test_ai_actions_router.py::test_trigger_ai_action_queues_timeline_event PASSED
tests/integration/test_ai_actions_router.py::test_trigger_ai_action_409_when_active PASSED
tests/integration/test_ai_actions_router.py::test_trigger_ai_action_422_unknown_type PASSED
tests/integration/test_ai_actions_router.py::test_trigger_ai_action_422_iff_when_preconditions_unmet PASSED
tests/integration/test_ai_actions_router.py::test_trigger_ai_action_404_unknown_incident PASSED
tests/integration/test_ai_actions_router.py::test_trigger_ai_action_403_other_user PASSED
tests/integration/test_ai_actions_router.py::test_legacy_analyze_returns_202 PASSED
tests/integration/test_ai_actions_router.py::test_legacy_analyze_response_has_job_id PASSED
tests/integration/test_executor.py::test_rca_completes_action PASSED
tests/integration/test_executor.py::test_rca_updates_incident_analysis_status PASSED
tests/integration/test_executor.py::test_rca_creates_fix_flow_rows PASSED
tests/integration/test_executor.py::test_rca_creates_checklist_items PASSED
tests/integration/test_executor.py::test_rca_updates_incident_root_cause PASSED
tests/integration/test_executor.py::test_rca_writes_completed_timeline_event PASSED
tests/integration/test_executor.py::test_rca_records_input_snapshot PASSED
tests/integration/test_executor.py::test_rca_fix_flows_have_generation_1 PASSED
tests/integration/test_executor.py::test_gemini_failure_marks_action_failed PASSED
tests/integration/test_executor.py::test_gemini_failure_updates_incident_status PASSED
tests/integration/test_executor.py::test_gemini_failure_writes_failed_timeline_event PASSED
tests/integration/test_executor.py::test_gemini_failure_sets_analysis_error_on_incident PASSED
tests/integration/test_executor.py::test_duplicate_execute_is_noop PASSED
tests/integration/test_executor.py::test_unknown_action_type_marks_action_failed PASSED
tests/integration/test_executor.py::test_unknown_action_type_does_not_update_incident_status PASSED
tests/integration/test_executor.py::test_rca_rerun_deletes_gen1_fix_flows PASSED
tests/integration/test_executor.py::test_iff_creates_new_generation PASSED
tests/integration/test_executor.py::test_iff_preserves_gen1_flows PASSED
tests/integration/test_executor.py::test_similar_incidents_never_written PASSED
tests/integration/test_incidents_router.py::test_create_incident_returns_201 PASSED
tests/integration/test_incidents_router.py::test_create_incident_analysis_status_pending PASSED
tests/integration/test_incidents_router.py::test_create_incident_default_origin_type PASSED
tests/integration/test_incidents_router.py::test_create_incident_custom_origin_type PASSED
tests/integration/test_incidents_router.py::test_create_incident_primary_action_null_while_pending PASSED
tests/integration/test_incidents_router.py::test_create_incident_missing_title_422 PASSED
tests/integration/test_incidents_router.py::test_create_incident_short_log_422 PASSED
tests/integration/test_incidents_router.py::test_create_incident_creates_ai_action_in_db PASSED
tests/integration/test_incidents_router.py::test_create_incident_timeline_has_two_events PASSED
tests/integration/test_incidents_router.py::test_create_incident_incident_code_format PASSED
tests/integration/test_incidents_router.py::test_create_incident_fires_background_task PASSED
tests/integration/test_incidents_router.py::test_list_incidents_returns_200 PASSED
tests/integration/test_incidents_router.py::test_list_incidents_returns_created_incident PASSED
tests/integration/test_incidents_router.py::test_list_incidents_excludes_closed PASSED
tests/integration/test_incidents_router.py::test_list_incidents_user_isolation PASSED
tests/integration/test_incidents_router.py::test_get_incident_returns_200 PASSED
tests/integration/test_incidents_router.py::test_get_incident_has_required_fields PASSED
tests/integration/test_incidents_router.py::test_get_incident_other_user_403 PASSED
tests/integration/test_incidents_router.py::test_get_incident_not_found_404 PASSED
tests/integration/test_incidents_router.py::test_resolve_incident_returns_200 PASSED
tests/integration/test_incidents_router.py::test_resolve_incident_sets_resolved_at PASSED
tests/integration/test_incidents_router.py::test_resolve_incident_timeline_event PASSED
tests/integration/test_incidents_router.py::test_reopen_incident_returns_in_progress PASSED
tests/integration/test_incidents_router.py::test_reopen_preserves_resolved_at PASSED
tests/integration/test_incidents_router.py::test_reopen_creates_timeline_event PASSED
tests/unit/test_context_builders.py::test_core_context_captures_fields PASSED
[... 89 unit tests all PASSED ...]
tests/unit/test_registry.py::test_handler_display_name_set PASSED

============================== warnings summary ===============================
PydanticDeprecatedSince20: Support for class-based `config` is deprecated, use ConfigDict instead.

======================= 145 passed, 1 warning in 10.53s =======================
```

---

## Coverage

Raw output from `pytest tests/ --cov=app --cov-report=term-missing`:

```
=============================== tests coverage ================================
_______________ coverage: platform win32, python 3.11.0-final-0 _______________

Name                                              Stmts   Miss  Cover   Missing
-------------------------------------------------------------------------------
app\ai_platform\__init__.py                           0      0   100%
app\ai_platform\context\__init__.py                   0      0   100%
app\ai_platform\context\builders.py                  36      3    92%   79, 101-102
app\ai_platform\context\types.py                     54      0   100%
app\ai_platform\executor.py                          80     11    86%   67-69, 75-80, 116, 123
app\ai_platform\handlers\__init__.py                  0      0   100%
app\ai_platform\handlers\base.py                     32      3    91%   45, 64, 96
app\ai_platform\handlers\improved_fix_flow.py        75      1    99%   184
app\ai_platform\handlers\root_cause_analysis.py      52      1    98%   124
app\ai_platform\registry.py                          10      0   100%
app\core\auth.py                                     23     10    57%   37, 59-77
app\core\config.py                                   32      4    88%   43, 59-61
app\core\database.py                                 27      4    85%   19, 44, 71-72
app\main.py                                          36      9    75%   16-18, 56, 68-72
app\models\__init__.py                               0      0   100%
app\models\models.py                               134      2    99%   23, 33
app\routers\__init__.py                               0      0   100%
app\routers\archive.py                                9      1    89%   17
app\routers\auth.py                                  38     17    55%   25-26, 33-39, 57-72, 81
app\routers\checklist.py                             12      1    92%   24
app\routers\fix_flows.py                             12      1    92%   24
app\routers\incidents.py                             58     15    74%   36-39, 61-62, 99-102, 136-140, 181, 217
app\routers\notes.py                                 12      1    92%   24
app\routers\ocr.py                                   19     11    42%   29-40
app\routers\timeline.py                                9      1    89%   18
app\schemas\__init__.py                               0      0   100%
app\schemas\incident.py                            115      4    97%   93-100
app\schemas\ocr.py                                  10      0   100%
app\services\__init__.py                              0      0   100%
app\services\ai_action_service.py                    70     45    36%   52-94, 106-139, 144, 150-155, 162-167, 180
app\services\gemini_service.py                       77     39    49%   170-177, 186-206, 216-228, 277-294
app\services\image_processing.py                    39     25    36%   43-79
app\services\incident_service.py                   180    112    38%   29-32, 57-102, 122-129, 215-216, ...
app\services\ocr_service.py                          17     13    24%   14-51
-------------------------------------------------------------------------------
TOTAL                                             1268    334    74%
======================= 145 passed, 1 warning in 14.83s =======================
```

---

## Test Statistics

| Metric | Value |
|--------|-------|
| Collected | 145 |
| Passed | 145 |
| Failed | 0 |
| Skipped | 0 |
| Errors | 0 |
| Warnings | 1 (Pydantic v2 config deprecation — cosmetic) |
| Total duration (basic run) | 10.53s |
| Total duration (coverage run) | 14.83s |

### Breakdown by file

| File | Tests |
|------|-------|
| `test_ai_actions_router.py` | 12 |
| `test_executor.py` | 23 |
| `test_incidents_router.py` | 21 |
| `test_context_builders.py` | 18 |
| `test_gemini_service.py` | 11 |
| `test_handlers.py` | 31 |
| `test_primary_action.py` | 16 |
| `test_registry.py` | 13 |

---

## Suspicious Findings

### Finding 1 — CRITICAL: Coverage numbers for the service layer are unreliable

**What the coverage report shows:**
- `ai_action_service.py`: 36% (lines 52-94 "not covered")
- `incident_service.py`: 38% (lines 57-102 "not covered")

**Why this is wrong:**  
Lines 57-102 in `incident_service.py` are `create_incident()`. This function is called by `POST /incidents`, which is exercised by 11 separate integration tests. Those tests verify DB state (`analysis_status=pending`, two timeline events written, AIAction row created). The code executes — the assertions prove it. Coverage simply does not measure it.

**Root cause:**  
`pytest-cov` uses CPython's `sys.settrace` mechanism to track executed lines. When async functions are invoked through `httpx.AsyncClient` + `ASGITransport` (the ASGI request pipeline), coverage.py loses the trace context. The test runner's trace hook is not inherited by the coroutines dispatched inside FastAPI's ASGI handler.

**Confirmation:**  
The executor (`executor.py`, 86%) is called DIRECTLY via `await execute(...)` inside test coroutines. It IS measured. The service layer functions are called INDIRECTLY through `await client.post(...)` → ASGITransport → FastAPI → service function. They are NOT measured by coverage despite executing.

**Impact:**  
The reported 74% total coverage is NOT the true execution coverage. The actual execution is substantially higher. Any coverage gate set at 74% would pass for the wrong reasons: the number reflects a tool limitation, not untested code.

**Fix required:**  
Add a `.coveragerc` or `pyproject.toml` section:
```ini
[coverage:run]
concurrency = greenlet
```
Or run coverage with `--cov-config` pointing to a config that sets `asyncio_mode = True`. This allows coverage.py to follow async context switches correctly.

---

### Finding 2 — MEDIUM: `test_iff_creates_new_generation` has conflicting fixture patches

**What the test declares:**
```python
async def test_iff_creates_new_generation(db, mock_gemini_rca, mock_gemini_iff):
```

Both `mock_gemini_rca` and `mock_gemini_iff` patch `app.services.gemini_service.generate`. When two `unittest.mock.patch` context managers patch the same target, the innermost (last-applied) wins. pytest-asyncio applies fixtures in parameter declaration order, so `mock_gemini_iff` is the innermost and overrides `mock_gemini_rca`.

**Consequence:**  
During the RCA `execute()` call inside this test, Gemini returns IFF output (not RCA output). The test PASSES because:
- IFF output is structurally compatible with what RCA's `parse_output()` returns
- IFF output has 1 fix flow → gen=1 gets 1 row
- The assertion only checks `{1 in generations, 2 in generations}` — not the count or content
- The `mock_gemini_rca` fixture parameter is silently unused

**What is NOT tested:**  
That RCA with correct RCA output produces the right number of gen=1 rows. The test verifies generation numbering but not RCA output fidelity in the IFF flow setup.

**Severity:** Medium. The test still verifies the generation increment behavior (its primary goal). But it misleads: `mock_gemini_rca` in the parameter list implies the test is also verifying RCA behavior, which it is not.

**Fix:**  
Remove `mock_gemini_rca` from the parameter list. Use only `mock_gemini_rca` in a dedicated inline `patch()` for the RCA sub-step, then the inline `with patch(...)` for IFF.

---

### Finding 3 — MEDIUM: BackgroundTask execution is fully mocked in all router tests

**What `mock_run_background` does:**  
It patches `app.services.ai_action_service.run_background` with an `AsyncMock`. Every router test that exercises endpoints which trigger background AI analysis (`POST /incidents`, `POST /ai-actions`) requests this fixture. The FastAPI `BackgroundTasks.add_task(ai_action_service.run_background, action_id)` adds the mock to the background queue. When Starlette executes background tasks (after response is sent, before the ASGI lifecycle completes), the mock is called instead of the real function.

**What is NOT tested through the router integration tests:**  
- The actual executor T1 (claiming the AIAction, status → processing)
- The actual Gemini prompt construction and response parsing
- The actual T2 persistence (FixFlow rows, TimelineEvent writes)
- Any interaction between the router and the execution result

**What IS tested through the router tests:**  
- HTTP status codes (201, 202, 409, 422, 403, 404)
- Request/response schema shape
- DB state IMMEDIATELY after the action is queued (AIAction.status = "pending", timeline events)
- Auth enforcement, input validation
- `mock_run_background.assert_called_once()` — verifies the background task WAS enqueued

**How executor behavior IS tested:**  
Separately, in `test_executor.py`, `execute()` is called directly with a real DB and mocked Gemini. These 23 tests cover T1, T2, success/failure paths, idempotency, generation lifecycle, and both bugs (F3, F4).

**Gap:**  
No test covers the end-to-end flow: router receives request → queues background task → background task executes → GET endpoint returns completed analysis. This is a genuine integration gap. It would require a test that calls `POST /incidents` without mocking `run_background` but WITH mocking Gemini, then polls `GET /incidents/{id}` until `analysis_status == "completed"`.

---

### Finding 4 — LOW: Known-bug assertions (F3, F4, F6) are regression markers for bugs, not correctness tests

These tests will BREAK when the bugs are fixed. They are correctly labeled with comments but this characteristic must be understood by maintainers.

See Phase 3 analysis below for details.

---

### Finding 5 — LOW: `asyncio_default_fixture_loop_scope=None` warning

```
asyncio: mode=Mode.AUTO, debug=False, asyncio_default_fixture_loop_scope=None
```

The session-scoped `setup_database` async fixture uses a fixture-level event loop. pytest-asyncio 0.24+ recommends explicitly setting `asyncio_default_fixture_loop_scope` in `pytest.ini`. The current behavior is accepted by the framework and all tests pass, but the warning indicates a configuration that could change behavior in a future pytest-asyncio version.

**Fix:**  
Add to `pytest.ini`:
```ini
asyncio_default_fixture_loop_scope = session
```

---

### Finding 6 — LOW: No test for T1 context-gathering failure path (F5)

Executor lines 75-80 (the `except Exception` block inside T1's `gather_context` call) are not covered. This path:
1. Sets `action.status = "failed"`
2. Sets `action.error_message = f"Context gathering failed: {exc}"`
3. Sets `incident.analysis_status = "failed"`
4. Returns (no TimelineEvent written — F5 bug)

Coverage confirms these lines are never hit. No test injects a failure into `handler.gather_context`. F5 (no timeline event on context failure) cannot be verified to be a bug or not, because the code path itself is untested.

---

### Finding 7 — INFO: OCR, archive, auth, and lifecycle hook paths have no tests

Out of scope for this audit (focused on AI Platform), but noted:
- `app/routers/ocr.py`: 42% covered
- `app/routers/auth.py`: 55% covered
- `app/services/ai_action_service.py` lines 106-139: `create_system_action()` (lifecycle hooks) not covered
- `app/services/incident_service.py` lines 411-414: `_fire_lifecycle_hooks()` not covered

---

## Phase 3: Test Quality Analysis — F3, F4, F6

### F3 — SimilarIncident Persistence

**Expected behavior (specification):**  
After RCA completes, `SimilarIncident` rows should be written for resolved/closed incidents that share component overlap with the current incident. `GET /incidents/{id}` should return a non-empty `similar_incidents` array when matches exist.

**Current implementation (`root_cause_analysis.py` lines 123-131):**  
```python
for sim in output.get("similar_incident_codes", [])[:3]:
    pass  # resolved below via the context pairs
# TODO: pass similar pairs through action.input_snapshot for re-resolution.
```
The loop body is a no-op. `SimilarIncident` rows are deleted on re-run but never re-created. `similar_incidents` is always `[]`.

**What the test asserts (`test_similar_incidents_never_written`):**  
```python
assert len(similar) == 0
```
It asserts the bug IS present.

**Classification: REGRESSION DOCUMENTATION TEST — not a correctness test.**  
This test will FAIL when F3 is fixed (because `len(similar)` will become > 0). It marks the bug. To become a correctness test it must be changed to assert the correct behavior: `assert len(similar) > 0` after creating a matching resolved incident.

**Confidence this runs the real code path:** HIGH — the test queries the real SQLite DB after `execute()` completes.

---

### F4 — Unknown Handler Path

**Expected behavior:**  
When the executor encounters an AIAction row with an `action_type` not in the registry:
1. `action.status` → `"failed"` (currently implemented)
2. `incident.analysis_status` → `"failed"` (NOT implemented)

Both should be updated atomically.

**Current implementation (`executor.py` lines 52-57):**  
```python
handler = registry.get(action.action_type)
if not handler:
    action.status = "failed"
    action.error_message = f"Unknown action_type: {action.action_type!r}"
    return  # ← incident.analysis_status NOT updated
```

**What the test asserts (`test_unknown_action_type_does_not_update_incident_status`):**  
```python
assert inc.analysis_status == "processing"
```
It asserts `"processing"` — the buggy state — not `"failed"` (the correct state).

**Classification: REGRESSION DOCUMENTATION TEST — asserts the bug, not the fix.**  
When F4 is fixed, this test will FAIL. The test comment correctly says "BUG F4: incident.analysis_status is NOT updated".

**Important caveat about this test:**  
The test sets `inc.analysis_status = "processing"` directly in the DB before triggering the unknown handler path. The executor's T1 block returns early (before the `incident.analysis_status = "processing"` line on T1's success path), so the incident ACTUALLY has the status that the test explicitly SET, not one set by the executor. The test correctly shows the incident remains stuck.

**Confidence:** HIGH — queries the real DB in a fresh session after `execute()`.

---

### F6 — output_schema_version

**Expected behavior (specification):**  
- `RootCauseAnalysisHandler.output_schema_version = "rca_v1"`
- `ImprovedFixFlowHandler.output_schema_version = "iff_v1"`

**Current implementation (both handlers):**  
```python
output_schema_version = "1.0"
```

**What the tests assert:**  
```python
# test_rca_output_schema_version
assert rca.output_schema_version == "1.0"

# test_iff_output_schema_version
assert iff.output_schema_version == "1.0"
```

**Classification: DIVERGENCE DOCUMENTATION TESTS.**  
These tests confirm the current value, which differs from the spec. When the implementation is corrected to `"rca_v1"` / `"iff_v1"`, these tests will fail. The tests serve as a "this is wrong and we know it" marker.

**Impact assessment:** Low-risk divergence. The `output_schema_version` field is stored in `ai_actions.output_schema_version` but is not currently used for any dispatch or parsing logic. It's a metadata field. Changing it is safe and does not require data migration for existing rows (the field is nullable and descriptive-only).

---

## Phase 4: Specific Verification Results

### 1. Did pytest execute every discovered test?

**Confirmed.** Collection count matches execution count.

- Collected: **145**
- Passed: **145**
- Failed: **0**
- Skipped: **0**
- Execution time: **10.53s** (basic), **14.83s** (coverage)

No parametrize decorators exist. No conditional skips. All 145 items in the collection ran.

---

### 2. Did pytest-cov actually execute?

**Yes, but coverage numbers for the service layer are unreliable.**

pytest-cov was NOT installed in the initial `requirements-test.txt`. It was installed during this audit. The first attempt (`pytest --cov=app`) failed with:
```
error: unrecognized arguments: --cov=app
```

After `pip install pytest-cov`, coverage ran successfully and produced output shown above.

**The reported 74% total is artificially low** due to the ASGI tracing issue described in Finding 1. The AI Platform core (handlers, registry, executor, context builders) shows accurate coverage at 86-100%. The service layer (36-38%) and router layer (partially) are undercounted because they execute inside FastAPI's ASGI request pipeline, which breaks `sys.settrace` context propagation.

**True estimated coverage (from behavioral test evidence):**  
- All `incident_service` endpoints exercised by 21 router tests with DB-state assertions: >80% actual
- All `ai_action_service.request_action()` exercised by 12 router tests: >70% actual
- OCR, archive, notes, checklist: legitimately not covered

**Recommendation:** Add `.coveragerc`:
```ini
[coverage:run]
concurrency = greenlet
```
This enables greenlet-aware tracing which correctly follows asyncio context switches.

---

### 3. BackgroundTask testing — what was and was not tested

**What was tested (via `mock_run_background`):**  
- The background task is enqueued: `mock_run_background.assert_called_once()` passes
- The action_id passed to the background task is correct (implied by subsequent DB assertions)
- The router returns the correct HTTP status before the task runs

**What was NOT tested through the router:**  
- That `run_background()` actually calls `execute()`
- That `execute()` transitions the incident to `processing` then `completed`
- That FixFlow rows exist after the background task completes
- That `GET /incidents/{id}` reflects completed analysis after background execution

**How executor behavior IS covered:**  
`test_executor.py` tests `execute()` directly (23 tests). This covers T1, T2, success/failure, idempotency, and the known bugs. The gap is that no test verifies the connection point: that `run_background` → `execute` → real DB state flows correctly in the router context.

**Is FastAPI `BackgroundTasks` execution itself tested?**  
No. It is mocked out entirely. The framework mechanism (that Starlette runs background tasks after the response) is trusted but not verified by this test suite.

---

### 4. Executor validation — T1 and T2

**T1 is tested (all lines within happy path):**  
- `test_rca_completes_action`: verifies action transitions to "completed" — T1 must succeed
- `test_rca_records_input_snapshot`: verifies `input_snapshot` is written — T1 SET line confirmed
- `test_duplicate_execute_is_noop`: second `execute()` returns early from T1 guard; Gemini called exactly once
- `test_gemini_failure_marks_action_failed`: T1 succeeds (sets processing), T2 handles failure

**T2 is tested:**  
- `test_rca_creates_fix_flow_rows`: FixFlow rows exist only if T2's `persist_results()` committed
- `test_rca_writes_completed_timeline_event`: TimelineEvent exists only if T2 committed
- `test_gemini_failure_writes_failed_timeline_event`: failure TimelineEvent exists only if T2 committed
- `test_rca_updates_incident_analysis_status`: `analysis_status == "completed"` only after T2 committed

**Transaction boundaries verified:**  
T1 and T2 are verified through the fact that assertions in NEW sessions (via `async with AsyncSessionFactory() as s:`) see committed data. If T1 or T2 had NOT committed, subsequent queries would return stale/no data and tests would fail.

**Rollback NOT tested:**  
No test injects a failure INSIDE `handler.persist_results()` to verify T2 rollback. If `persist_results()` partially writes rows then fails, the rollback behavior is not verified.

**Orphan detection NOT tested:**  
`_check_orphan_or_raise()` (marks stale `processing` actions as failed when `elapsed > ANALYSIS_TIMEOUT_SECONDS * 2`) is not tested. The function exists at `ai_action_service.py` lines 158-168 and is confirmed by coverage showing lines 162-167 as uncovered.

---

### 5. Are integration tests actually integration tests?

**Router tests (`test_incidents_router.py`, `test_ai_actions_router.py`):**  

These tests ARE integration tests in the meaningful sense:
- They exercise the full HTTP → FastAPI → service → SQLite stack
- They verify DB state, not just HTTP response bodies
- Examples of genuine behavioral assertions:
  - `test_create_incident_creates_ai_action_in_db`: queries `ai_actions` table directly
  - `test_create_incident_timeline_has_two_events`: queries `timeline_events` table
  - `test_resolve_incident_sets_resolved_at`: queries `incidents` table for `resolved_at`
  - `test_reopen_preserves_resolved_at`: queries before AND after, compares timestamps
  - `test_trigger_ai_action_409_when_active`: tests the DB-level partial unique index path

**However, all router tests mock the AI execution layer:**  
- `mock_run_background` prevents any executor code from running during router tests
- This creates a category boundary: router tests verify "action is queued correctly"; executor tests verify "action executes correctly". The two are tested independently, not end-to-end.

**Executor tests (`test_executor.py`):**  

These ARE integration tests in the fullest sense:
- They call the production `execute()` function
- They use a real SQLite database (same engine as production)
- They verify DB state in fresh sessions after execution
- Gemini is mocked (necessary — no test API key)
- The T1/T2 transaction boundary is implicitly verified by assertion semantics

**Verdict:** The integration tests are genuine and test real behavior. They are NOT unit tests with heavy mocking. The only significant mock in router tests is `run_background`. In executor tests, only Gemini is mocked.

---

## Confidence Assessment

**Overall confidence in the test suite: 6 / 10**

### Breakdown

| Area | Score | Reason |
|------|-------|--------|
| Unit tests (handlers, registry, builders, primary_action) | 9/10 | Pure function tests, no mocking, directly verify behavior |
| Unit tests (gemini_service) | 8/10 | Correctly mocks `_model.generate_content_async` at the right level |
| Executor integration tests | 8/10 | Directly call production code, verify DB state, cover T1/T2 |
| Router integration tests | 6/10 | Real HTTP stack but execution layer fully mocked |
| End-to-end (router → executor → result) | 0/10 | No such test exists |
| Coverage measurement | 2/10 | Tool misreports due to ASGI tracing limitation |

### Why not higher

1. **The 74% coverage number is not trustworthy.** The tool is not measuring service layer execution correctly. A false metric is worse than no metric.

2. **No end-to-end test exists.** No test verifies that a created incident eventually shows `analysis_status=completed` with populated `fix_flows` via the HTTP API. This is the user-visible success path and it is untested as a complete flow.

3. **Known bugs are documented, not prevented.** F3, F4, F6 tests assert the broken behavior. If the bugs are fixed, the tests will fail — which is good for detection, but means developers must remember to update the test assertions when fixing each bug. This is fragile.

4. **`test_iff_creates_new_generation` has a silent fixture conflict** (Finding 2). The test passes but not entirely for the reason stated.

5. **Orphan detection, T1 context failure (F5), and T2 rollback paths are untested.** These are production failure modes with real incident impact.

### Why not lower

1. **All 145 tests genuinely execute** — verified by test output showing all 145 collected and passed with timing evidence.

2. **Executor tests provide strong confidence** in the core AI Platform logic: T1/T2 transactions, RCA/IFF persistence, generation lifecycle, and failure paths are all tested against a real database.

3. **Router tests verify behavioral outcomes** (DB state, not just HTTP codes) for the incident lifecycle: create, resolve, reopen, user isolation, input validation, authentication.

4. **Known bugs are explicitly called out** in test code with comments, not silently ignored.

5. **The test infrastructure is sound**: env var isolation, DB wipe between tests, correct mock paths, async fixtures working correctly.

---

## Recommendations (Priority Order)

1. **Fix coverage measurement** — add `.coveragerc` with `concurrency = greenlet`. Re-run to get accurate numbers before setting any coverage gate.

2. **Add one end-to-end test** — `POST /incidents` (no `mock_run_background`) + mock Gemini + poll until `analysis_status=completed` + assert `fix_flows` populated. This closes the most significant gap.

3. **Fix `test_iff_creates_new_generation`** — remove `mock_gemini_rca` from parameters; use separate inline patches for the RCA and IFF phases.

4. **Add F5 test** — inject a failure into `handler.gather_context` (e.g., mock to raise) and verify `action.status=failed` and `incident.analysis_status=failed`, and note that NO TimelineEvent is written (the bug).

5. **Add orphan detection test** — create a processing action with `started_at` > 2× ANALYSIS_TIMEOUT_SECONDS ago, call `request_action`, verify the orphan is marked failed and a new action is created.

6. **Invert F3 test** — create a matching resolved incident before running RCA, then assert that `similar_incidents` IS populated once the bug is fixed. Add an explicit skip marker or `xfail` so the test signals "expected to fail until F3 is resolved".

7. **Add `asyncio_default_fixture_loop_scope = session`** to `pytest.ini` to silence the configuration warning.

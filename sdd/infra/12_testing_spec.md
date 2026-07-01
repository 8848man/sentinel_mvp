# 12 — Testing Specification

**Refs:** → [API Spec](../backend/05_api_spec.md) · [Frontend Architecture](../frontend/10_frontend_arch.md)

---

> **⚠ MIGRATION NOTICE**
>
> This specification has not yet been fully migrated to the AI Platform architecture.
>
> Sections marked `[STALE]` reference the pre-AI Platform implementation and describe functions, tables, or APIs that have been removed or renamed. Do not implement tests against stale sections without first consulting the current implementation.
>
> AI Platform testing documentation (covering `ai_action_service`, `executor`, handler registry, and the T1/T2 execution pattern) will be added in a future update.

---

## Testing Layers

| Layer | Tool | Coverage Target |
|-------|------|----------------|
| Backend unit (services) | pytest + pytest-asyncio | 80% |
| Backend API integration | pytest + httpx AsyncClient | All endpoints |
| Frontend widget tests | flutter_test | Core DS components |
| Frontend provider tests | riverpod + mocktail | All providers |
| E2E (post-MVP) | Playwright or Flutter integration_test | Critical flows |

---

## Backend: Unit Tests

**Location:** `backend/tests/unit/`

### `test_gemini_service.py`

- Mock `genai.GenerativeModel.generate_content_async`
- Test `extract_metadata` with valid log → assert field mapping correct
- Test `extract_metadata` with malformed JSON response → assert retry or 500
- Test `parse_json_response` with code-fenced JSON → strips fences correctly
- Test `generate(prompt, timeout)` → returns response string on success; raises `RuntimeError` on timeout or empty response

> **[STALE]** The following test case references `analyze_incident` which was removed in the AI Platform refactor. The function is now `generate()` in `gemini_service.py`. Do not implement this test:
> - ~~`Test analyze_incident → assert root_cause, confidence, fix_flows present`~~

### `test_incident_service.py`

- Test `generate_suggested_id(2026, 43)` → returns `"INC-2026-043"`
- Test `build_similar_context` with overlapping components → returns non-empty string

> **[STALE]** The following test case references `create_and_analyze` which was removed in the AI Platform refactor. Incident creation and AI analysis are now separate operations (`incident_service.create_incident` + `ai_action_service.request_action` + executor). Do not implement this test:
> - ~~`Test create_and_analyze with mocked Gemini → verifies DB inserts for incident, fix_flows, checklist_items, timeline_events`~~

### `test_auth.py`

- Test `get_current_user` with valid JWT → returns user dict
- Test `get_current_user` with expired JWT → raises 401
- Test `get_current_user` with tampered JWT → raises 401

---

## Backend: Integration Tests

**Location:** `backend/tests/integration/`  
**Setup:** `conftest.py` creates in-memory SQLite or test PostgreSQL, seeds with fixtures.

### `test_incidents_router.py`

| Test | Assertion |
|------|-----------|
| `POST /incidents/analyze-metadata` (valid) | 200, returns metadata fields |
| `POST /incidents/analyze-metadata` (empty log) | 400 validation error |
| `POST /incidents` (valid) | 201, incident in DB, `analysis_status: pending`, timeline event created |
| `GET /incidents` (authenticated) | 200, returns user's incidents only |
| `GET /incidents/{id}` (own incident) | 200, full detail including fix_flows |
| `GET /incidents/{id}` (other user's) | 403 |
| `PATCH /incidents/{id}` (attach fix flow) | 200, status in_progress, timeline event added |
| `PATCH /incidents/{id}/resolve` | 200, resolved_at set, status=resolved |
| `POST /incidents/{id}/ai-actions` (valid) | 202, action_id returned, status=pending |
| `POST /incidents/{id}/ai-actions` (duplicate) | 409, active action already exists |
| `PATCH /incidents/{id}/reopen` | 200, status=in_progress |

### `test_checklist_router.py`

- `PATCH /checklist/{id}` (is_completed: true) → 200, timeline event "Step completed" added
- `PATCH /checklist/{id}` (invalid id) → 404

### `test_archive_router.py`

- `GET /archive` → returns only resolved/closed incidents, includes resolution_time_minutes

---

## Frontend: Widget Tests

**Location:** `frontend/sentinel/test/widget/`

### Design System Components

| Test file | Tests |
|-----------|-------|
| `test_severity_badge.dart` | renders Critical (red), Major (amber), Minor (green) correct colors |
| `test_status_badge.dart` | renders Open (blue), In Progress (amber), Closed (muted) |
| `test_incident_card.dart` | shows incidentCode, title, description; correct left border color by severity |
| `test_primary_button.dart` | renders label; shows spinner when loading=true; disabled state |
| `test_sentinel_input.dart` | shows placeholder; onChanged fires; obscureText works for password |
| `test_component_chip.dart` | renders label; × button fires onRemove callback |

---

## Frontend: Provider Tests

**Location:** `frontend/sentinel/test/providers/`

### `test_auth_provider.dart`

- Mock Supabase; test `signIn` success → state becomes `authenticated`
- Test `signIn` failure → state becomes `error` with message
- Test `signOut` → state becomes `unauthenticated`

### `test_dashboard_provider.dart`

- Mock API client; test `build()` → loads incidents into state
- Test `refresh()` → state transitions loading → success
- Test toggle view mode → `viewMode` updates, no API call

### `test_workspace_provider.dart`

- Mock API client; test checklist toggle → PATCH called, local state updated
- Test note auto-save → debounced PUT called after 1 second

---

## Test Data Fixtures

**Location:** `backend/tests/fixtures/`

```python
# fixtures/incidents.py
SAMPLE_INCIDENT = {
    "log_text": "ERROR: FATAL: remaining connection slots are reserved for replication...",
    "title": "DB Connection Pool Exhausted",
    "severity": "critical",
    "components": ["PostgreSQL", "AWS EKS"]
}

SAMPLE_AI_METADATA = {
    "suggested_title": "PostgreSQL Connection Pool Exhaustion",
    "suggested_severity": "critical",
    "detected_components": ["PostgreSQL", "AWS EKS", "Redis"],
    "description": "Primary database rejecting new connections."
}
```

---

## CI Test Execution

```yaml
# In cloudbuild.yaml (step 1)
- name: 'python:3.12'
  entrypoint: bash
  args:
    - '-c'
    - |
      cd backend
      pip install -r requirements.txt -r requirements-test.txt
      pytest tests/ -v --tb=short --cov=app --cov-report=term-missing
```

Flutter tests run locally pre-commit:
```bash
flutter test test/ --coverage
```

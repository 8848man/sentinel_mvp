# Mock Data Specification

## 1. Purpose

Mock data provides a fully functional frontend experience without a live backend. It is the executable version of the API contract defined in `sdd/backend/05_api_spec.md`. All mock responses mirror the exact JSON shape the real backend will return.

---

## 2. Source Specs Used

| Spec | Used for |
|---|---|
| `sdd/backend/05_api_spec.md` | API response shapes, endpoint signatures, error codes |
| `sdd/backend/06_database_schema.md` | Entity fields, nullability, enums |
| `sdd/backend/07_auth_spec.md` | Auth flow: signIn, signUp, OTP verification |
| `sdd/context/04_screen_spec.md` | What data each screen needs |
| `sdd/frontend/mock_auth_accounts.md` | Auth test credentials |

---

## 3. Auth Mock Account Reference

See `sdd/frontend/mock_auth_accounts.md` for the full table of registered test accounts, passwords, OTP codes, and expected outcomes.

---

## 4. Incident Mock Scenarios

Five mock incidents covering all required states:

| ID | Code | Severity | Status | Scenario |
|---|---|---|---|---|
| mock-inc-001 | INC-2026-041 | critical | open | PostgreSQL connection pool exhaustion — no fix flow selected |
| mock-inc-002 | INC-2026-042 | major | in_progress | Redis cache timeout — fix flow selected and partially completed |
| mock-inc-003 | INC-2026-043 | minor | open | Scheduled job queue backlog — no action taken |
| mock-inc-004 | INC-2026-040 | minor | closed | Auth service memory leak — fully resolved |
| mock-inc-005 | INC-2026-039 | major | resolved | API gateway 502 spike — resolved, in archive |

Each incident contains realistic: `fix_flows` (with `checklist_items`), `timeline`, `note` (where applicable), and `similar_incidents`.

---

## 5. API Response Shapes Mirrored by Mock Data

### `POST /incidents/analyze-metadata` response
```json
{
  "suggested_id": "INC-2026-044",
  "suggested_title": "Connection Pool Exhaustion",
  "suggested_severity": "critical",
  "detected_components": ["PostgreSQL", "Spring Boot"]
}
```
Mock logic: derives severity and components from keywords in the raw log text.

### `POST /incidents` response (201)
Full `Incident` object including `fix_flows`, `similar_incidents`, `timeline`.  
Mock returns two generic fix flows with three checklist items each.

### `GET /incidents` response (200)
`{ "data": [...], "total": N }` — active incidents only (status != closed).  
Dashboard maps these to `DashboardIncidentSummaryModel`.

### `GET /incidents/{id}` response (200)
Full `Incident` object. Mock reads from in-memory store.

### `PATCH /incidents/{id}` / `PATCH /incidents/{id}/resolve`
Mutates in-memory store. Appends timeline event. Returns updated incident.

### `PATCH /checklist/{item_id}`
Mutates checklist item in-memory. Appends `"Step '...' completed"` timeline event.

### `PUT /incidents/{id}/note`
Upserts note in-memory. Returns `NoteModel`.

### `GET /archive`
Returns incidents with status `resolved` or `closed`.

---

## 6. Rules for Changing Mock Data

- Mock data in `mock_incidents.dart` may only be changed to:
  - Fix a bug where mock data doesn't match the API spec shape
  - Add new incident scenarios needed for testing a new screen
  - Update field values to better test edge cases
- Do NOT add fields that don't exist in the API spec
- Do NOT remove fields that are required by the API spec
- After any change, run `flutter analyze` to confirm no type errors

---

## 7. Switching from Mock to Real Backend

**Step 1:** Build or run with the real backend flag:
```bash
flutter run --dart-define=USE_MOCK_DATA=false
```

**Step 2:** Ensure environment variables are set (see `sdd/infra/11_deployment_spec.md`):
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `API_BASE_URL` (for Dio base URL)

**Step 3:** The following classes automatically switch to real implementations:
- `AuthNotifier` → uses `Supabase.instance.client.auth` directly
- `DashboardNotifier` → uses `Dio` with JWT interceptor
- `IncidentRepositoryImpl` → datasource methods make real Dio calls

**Step 4:** Remove mock datasource bodies and replace with real Dio calls in:
- `features/incident/data/datasources/incident_remote_datasource.dart`

The repository interfaces, domain entities, and presentation layer require **no changes** when switching.

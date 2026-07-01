# Validation Specification

**Purpose:** Defines mandatory validation checks for every task type. Validation is not optional — it is Phase 6 of the implementation lifecycle. A task is not complete until its validation checklist passes.

**Refs:** → [Implementation Lifecycle](./00_implementation_lifecycle.md) · [State Machines](../domain/state_machines.md)

---

## Validation Levels

| Level | When | What it checks |
|---|---|---|
| **L1 — Syntax** | After every change | Imports, types, compilation |
| **L2 — Contract** | After any API/schema change | Request/response shapes, field names, status codes |
| **L3 — Behavioral** | After any logic change | State transitions, DB consistency, timeline events |
| **L4 — Integration** | After cross-boundary changes | Frontend ↔ backend field alignment |
| **L5 — Product** | After any user-visible change | UX flow, loading states, error states |

---

## Backend Endpoint Change

**L1:** `python -c "import app.main"` — no ImportError or startup exception  
**L2:**
- [ ] Response shape matches `05_api_spec.md` exactly (field names, types, nullability)
- [ ] Status codes match spec (201 for create, 202 for async, 409 for conflict, etc.)
- [ ] Error response shape is `{"detail": "message"}`
- [ ] New optional fields return `null` for legacy rows, not crash

**L3:**
- [ ] DB state after the operation matches `06_database_schema.md`
- [ ] Timeline contains the expected event(s) with correct `actor_type` and `event_type`
- [ ] `analysis_status` on Incident is consistent with AIAction status (if AI is involved)
- [ ] Ownership check present: 403 returned for cross-user access

---

## Database Schema Change

**L1:** `python -c "from app.core.database import init_db"` — no ORM mapping error  
**L2:**
- [ ] Column name in `mapped_column` matches DB column name in migration
- [ ] Reserved SQLAlchemy attribute names not used (e.g. `metadata`, `query`, `id`)
- [ ] FK constraints reference existing tables and columns
- [ ] Migration has correct `down_revision` pointing to the previous migration
- [ ] Migration is idempotent (uses `IF NOT EXISTS` or equivalent guards)

**L3:**
- [ ] `alembic upgrade head` completes without error on a clean schema
- [ ] `alembic downgrade -1` completes without error (reversibility check)

---

## AI Platform — New Handler

**L1:**
```
python -c "
from app.ai_platform.registry import REGISTRY
assert 'your_action_type' in REGISTRY
print('Registry OK')
"
```

**L2:**
- [ ] Handler implements all 4 abstract methods: `gather_context`, `build_prompt`, `parse_output`, `persist_results`
- [ ] Handler overrides `build_input_snapshot` and `timeline_event_text`
- [ ] `output_schema_version` is set and non-empty
- [ ] `priority` is deliberately chosen and documented in `08_ai_integration_spec.md`

**L3:**
- [ ] `is_primary_for(incident)` returns True only when preconditions are met
- [ ] `validate(incident)` raises 422 when preconditions are unmet
- [ ] `persist_results` does not leave partial state on failure (atomic within T2 transaction)
- [ ] T2 writes a `TimelineEvent` with `actor_type="ai"` and correct `event_type`
- [ ] `AIAction.output` stores the parsed dict; `AIAction.status` becomes "completed"
- [ ] `Incident.analysis_status` becomes "completed" after T2 commits

**L4:**
- [ ] Any new field in the AI output appears in `05_api_spec.md`
- [ ] The field exists in the Pydantic `IncidentResponse` schema
- [ ] The Flutter entity and `fromJson` include the field

---

## Flutter Entity / Model Update

**L1:** `flutter analyze` — zero errors, zero warnings  
**L2:**
- [ ] Every field in `05_api_spec.md` IncidentResponse is present in the Flutter entity
- [ ] `fromJson` handles all fields (including new ones) without null crash
- [ ] Optional fields use `json['field'] as Type?` or `?? defaultValue`
- [ ] `toEntity()` maps all model fields to entity fields

**L4:**
- [ ] No field that exists in the backend response is silently ignored in `fromJson`
- [ ] After parsing, the entity exposes all fields the screen needs to render

---

## State Transition Change

**L3:**
- [ ] The transition is listed as "Allowed" in `sdd/domain/state_machines.md`
- [ ] The inverse transition (if invalid) is guarded — returns 422 or 409
- [ ] The service writes a `TimelineEvent` with the slug from `state_machines.md`
- [ ] `resolved_at` is set when transitioning to `resolved` and not changed on `reopen`
- [ ] `analysis_status` is not reset by lifecycle transitions (it follows AIAction state only)

---

## Frontend Screen

**L1:** `flutter analyze` — zero errors  
**L5:**
- [ ] Screen renders correctly against the reference PNG
- [ ] Loading state shown while data is fetching (AsyncValue.loading)
- [ ] Error state shown with a message when API call fails (AsyncValue.error)
- [ ] Empty state shown when list is empty
- [ ] `analysis_status: pending/processing` → spinner shown, no primary_action button
- [ ] `analysis_status: completed` → primary_action button rendered (if one exists)
- [ ] `analysis_status: failed` → error state + retry primary_action button

---

## Cross-Boundary Validation (Always Run After API Contract Change)

This is the most commonly missed check. Run it whenever `05_api_spec.md` changes.

| Check | How to verify |
|---|---|
| Backend field added → Flutter entity has it | Grep entity file for field name |
| Backend field removed → Flutter `fromJson` handles absence | Verify null safety in `fromJson` |
| New endpoint → Flutter `ApiEndpoints` has method | Grep `api_endpoints.dart` |
| New endpoint → Flutter datasource has method | Grep `incident_api_datasource.dart` |
| DB column added → Pydantic schema has field | Check `schemas/incident.py` |
| DB column added → API spec reflects it | Check `05_api_spec.md` |

---

## Smoke Test Sequence (Run After Major Backend Changes)

Run in order. Stop at first failure and fix before continuing.

```
1. python -c "import app.main"                    # imports clean
2. python -c "from app.ai_platform.registry import REGISTRY; print(list(REGISTRY.keys()))"
3. python -c "from app.core.database import init_db; import asyncio; asyncio.run(init_db())"
4. python -c "from app.main import create_app; app = create_app(); routes = [r.path for r in app.routes]; print(len(routes), 'routes')"
5. uvicorn app.main:app --port 8001 &             # start server
6. curl http://localhost:8001/health               # returns {"status": "ok"}
7. kill %1
```

---

## Documentation Sync Validation

After completing a task and updating any spec, verify:

- [ ] Updated spec is under 300 lines (hard limit per `spec_authoring_rules.md`)
- [ ] Updated spec does not duplicate content from another spec (reference instead)
- [ ] `00_index.md` reflects any new spec files added
- [ ] CLAUDE.md does not now contain detail that belongs in the updated spec
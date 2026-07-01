# Implementation Lifecycle

**Refs:** → [Context Loading](./01_context_loading.md) · [Decision Flow](./02_decision_flow.md) · [Validation](./03_validation.md)

Every implementation task — regardless of type — follows this sequence. No phase is optional.

---

## Phase 1 — Context Load

```
Read CLAUDE.md (always in context)
    ↓
Read 01_context_loading.md → identify your task type
    ↓
Load only the documents listed for that task type
    ↓
Stop loading — resist loading extra docs "just in case"
```

**Rule:** If a document is not in the "Always" or "If relevant" columns for your task type, do not load it.

---

## Phase 2 — Code-First Analysis

Before reading any spec, read the code that will be affected.

```
Identify the files closest to the change
    ↓
Read those files (the code is the ground truth for existing behavior)
    ↓
Trace imports upward (callers) and downward (dependencies)
    ↓
Now read the relevant spec to understand design intent
    ↓
Identify the delta: what is missing, wrong, or inconsistent
```

**Rule:** Never trust a spec to describe what the code does today. Trust it only to describe what was intended, then compare against reality.

---

## Phase 3 — Decision Check

Before writing any code, check whether the change requires a decision flow.

Consult `sdd/workflow/02_decision_flow.md` for:
- Adding an API field
- Adding a DB column
- Adding an AI action handler
- Changing a state transition
- Updating a frontend entity

If your change fits a defined flow, follow it exactly.  
If it doesn't, note the gap and proceed with the code-first analysis outcome.

---

## Phase 4 — Implement

Implement the change.

**Backend rules:**
- Routers are thin — validate input, call service, return response
- Business logic lives in services; never in routers or models
- Every DB write uses `async with db.begin()`
- Ownership check on every incident access: `incident.user_id == current_user["user_id"]`
- Calling `gemini_service` is only permitted from `incident_service` or AI Platform handlers — never from routers

**Frontend rules:**
- Dependency chain for any data change: entity → model (fromJson) → datasource → provider → screen
- No hardcoded values — always use `design_system/tokens/`
- No new component if an existing DS component can be reused
- `flutter analyze` must pass with zero errors after every change

**AI Platform rules:**
- New capability = new handler class implementing `AIActionHandler` ABC + entry in `registry.py`
- Never modify executor.py or registry.py to add handler-specific logic
- Handler `persist_results` must be idempotent within its transaction

---

## Phase 5 — Verify

Run the minimum verification for your task type before declaring implementation complete.

| Task type | Verification |
|---|---|
| Backend code change | `python -c "import app.main"` passes; no ImportError |
| New backend endpoint | Smoke test: request returns expected status code and shape |
| DB model change | `init_db()` completes without error on fresh SQLite |
| Alembic migration | `alembic upgrade head` succeeds on a copy of prod schema |
| Flutter change | `flutter analyze` zero errors |
| Flutter model change | Manual JSON round-trip: `fromJson(toJson()) == original` |

Do not skip verification. A change that cannot be verified is not done.

---

## Phase 6 — Validate

Run the validation checklist from `sdd/workflow/03_validation.md` for your task type.

Validation goes beyond syntax and imports — it checks behavioral correctness, state consistency, and cross-boundary impact.

**Minimum for any backend change:**
- Does the API response shape match `05_api_spec.md`?
- Does the DB state after the operation match `06_database_schema.md`?
- Does the timeline contain the expected events with correct `actor_type`/`event_type`?

**Minimum for any frontend change:**
- Does the Flutter entity include all fields the backend now returns?
- Does `fromJson` handle new optional fields without crashing on null?
- Does the screen render correctly in both `pending` and `completed` analysis states?

---

## Phase 7 — Sync Documentation

After implementation, update any specification that now diverges from the code.

**Rule: spec sync is part of the same commit as implementation — never a follow-up task.**

Spec sync checklist:
- [ ] Does `05_api_spec.md` reflect any new/changed endpoints, fields, or status codes?
- [ ] Does `06_database_schema.md` reflect any new columns, tables, or indexes?
- [ ] Does `08_ai_integration_spec.md` reflect any new handlers, prompts, or context types?
- [ ] Does `09_backend_arch.md` reflect any new files or service responsibilities?
- [ ] Does `state_machines.md` reflect any new or changed lifecycle transitions?

If a spec was correct and no change was needed, note that explicitly (don't skip the check).

---

## Phase 8 — Cross-Boundary Check

For any change that touches the API contract or DB schema, verify the other side of the stack.

| Change type | Cross-boundary check |
|---|---|
| Backend adds a response field | Is the Flutter entity and `fromJson` updated? |
| Backend removes a response field | Does Flutter handle the absent field without null crash? |
| Backend adds an endpoint | Is the endpoint in `ApiEndpoints`? Is there a datasource method? |
| DB column added | Is the Alembic migration written? Does the ORM model match? |
| AI action produces new output | Is the handler's `output_schema_version` bumped? |

The cross-boundary check is the most commonly skipped phase. The validation report in the execution context audit found the entire AI Platform invisible to the frontend because this check was not run.

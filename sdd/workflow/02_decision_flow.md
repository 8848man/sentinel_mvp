# Decision Flow Specification

**Purpose:** When an implementation decision is ambiguous, consult this document. Each flow defines the source of truth, the correct sequence, and the documentation that must be updated.

**Refs:** → [Implementation Lifecycle](./00_implementation_lifecycle.md) · [State Machines](../domain/state_machines.md)

---

## Decision 1 — Adding or Changing an API Response Field

**Source of truth:** `sdd/backend/05_api_spec.md`

```
1. Add/update the field in 05_api_spec.md first (spec leads implementation)
2. Update the Pydantic schema in backend/app/schemas/incident.py
3. Update the service function that populates the field
4. Run: python -c "import app.main" to verify no import errors
5. Update Flutter entity (domain/entities/*.dart)
6. Update Flutter model fromJson (data/models/*_model.dart)
7. Update datasource if the field is used in a request
8. Run: flutter analyze — must pass with zero errors
```

**Do not** implement on the backend and leave the Flutter entity for later.  
Both sides must be updated in the same session.

---

## Decision 2 — Adding a Database Column

**Source of truth:** `sdd/backend/06_database_schema.md`

```
1. Add the column definition to 06_database_schema.md first
2. Add the column to the SQLAlchemy model in backend/app/models/models.py
3. Write an Alembic migration (PostgreSQL only)
   - Migration must have correct down_revision pointing to previous migration
   - Migration must be idempotent where possible
4. Add the field to the relevant Pydantic schema if it appears in API responses
5. Update 05_api_spec.md if the API response shape changed
6. Verify: alembic upgrade head against a copy of the schema
```

**Column naming:** Match the DB column name exactly in the ORM `mapped_column`. If the Python attribute name must differ (reserved word, etc.), use `mapped_column("db_column_name", ...)` with explicit name.

---

## Decision 3 — Adding an AI Action Handler

**Source of truth:** `backend/app/ai_platform/handlers/base.py` (ABC contract)

```
1. Read base.py — understand the full ABC interface
2. Read an existing handler as a reference implementation
3. Define the context type(s) in context/types.py if new ones are needed
4. Add builder function(s) in context/builders.py if new context is needed
5. Create the handler file in handlers/<action_type>.py
   - Implement all abstract methods: gather_context, build_prompt, parse_output, persist_results
   - Override build_input_snapshot and timeline_event_text
   - Set action_type, display_name, output_schema_version, priority
   - Set system_triggers=[] unless this handler auto-fires on lifecycle events
6. Register in registry.py: REGISTRY["action_type"] = HandlerClass()
7. Add the prompt template to gemini_service.py
8. Update 08_ai_integration_spec.md — registered handlers table, prompt, context types
9. Update state_machines.md if the handler introduces new primary_action conditions
10. Verify: python -c "from app.ai_platform.registry import REGISTRY; print(REGISTRY.keys())"
```

**Priority rule:** Lower number = higher priority in primary_action selection. Assign deliberately:
- 1–19: Critical-path actions (RCA retry = 10)
- 20–39: User-initiated follow-on actions (Improved Fix Flow = 20)
- 40+: Optional/secondary actions

---

## Decision 4 — Frontend Consuming a New API Field

**Source of truth:** `sdd/backend/05_api_spec.md`

```
1. Verify the field exists in 05_api_spec.md (if not, run Decision 1 first)
2. Add the field to the domain entity (domain/entities/*.dart)
3. Add parsing in the model fromJson (data/models/*_model.dart)
   - Always handle null gracefully: use ?? defaultValue or mark as optional
   - Never assume a new field is always present — API may return null for legacy rows
4. Add to toEntity() in the model
5. Add to the datasource method if it's a request field
6. Propagate through the provider if the screen needs to react to the field
7. Update the screen widget if it renders the field
8. Run: flutter analyze — must pass
```

**Rule:** Never skip step 2. A screen that accesses a field not in the entity will fail at compile time. A `fromJson` that silently ignores a new field will produce stale UI with no error.

---

## Decision 5 — Changing a State Transition

**Source of truth:** `sdd/domain/state_machines.md`

```
1. Read state_machines.md — find the affected lifecycle
2. Verify the proposed transition is listed as "Allowed"
   If it isn't: update state_machines.md first, then implement
3. Update the service function that executes the transition
4. Ensure the transition writes a TimelineEvent with the correct:
   - actor_type: "operator" | "system" | "ai"
   - event_type: matching the slug in state_machines.md
5. Update incident.analysis_status if the transition affects AI state
6. Verify the transition does NOT move to a disallowed state
   (e.g. closed → resolved is invalid; enforce with guard or 422)
7. Update 05_api_spec.md if a new endpoint or response field is affected
8. Update state_machines.md to mark the transition as implemented
```

---

## Decision 6 — Updating a Prompt Template

**Source of truth:** `backend/app/services/gemini_service.py`

```
1. Update the prompt constant in gemini_service.py
2. If the output JSON schema changed:
   a. Update the handler's parse_output to match the new schema
   b. Bump output_schema_version on the handler class
   c. Update the handler's build_input_snapshot if new context metadata is captured
3. Update 08_ai_integration_spec.md — the prompt template section
4. If the output fields changed, run Decision 1 (API field change) for any new fields
   that appear in IncidentResponse
```

**Warning:** Do not change prompt output schema without bumping `output_schema_version`. Historical `AIAction.output` rows store the old schema; parsing code must remain compatible or be gated by version.

---

## Decision 7 — Adding a New Screen (Frontend)

**Source of truth:** `sentinel_screen_ref/*.png`

```
1. Verify there is a PNG reference for this screen
   If not: screen cannot be implemented until a PNG is provided
2. Read the PNG and 04_screen_spec.md entry for this screen
3. Read 03_user_flow.md — identify what navigates to/from this screen
4. Add the route in core/router/app_router.dart
5. Create the screen file in features/<name>/presentation/screens/
6. Add state provider in features/<name>/presentation/*/providers/
7. Wire API calls through the existing datasource or add methods
8. Run: flutter analyze
9. Visually verify against the reference PNG
```

---

## Decision 8 — Resolving a Spec/Code Conflict

When the spec and the code disagree, follow this order to determine which is correct:

```
1. Is the divergence noted in CLAUDE.md?     → CLAUDE.md note wins
2. Is this a recently-written file?           → Code wins (spec is stale)
3. Is the spec more recent than the code?     → Spec is the intent; update the code
4. Is the conflict in auth/security logic?    → Read app/core/auth.py; it is always correct
5. Still ambiguous?                           → Check git log for the file; last change explains intent
```

After resolving: **update the losing document** to match the winner. Never leave a known divergence undocumented.

---

## Decision 9 — Deciding Whether a Change Needs an ADR

**Source of truth:** `sdd/architecture/decisions/000_index.md`

An ADR is required if the change meets **any** of these:

```
- Spans more than one area in sdd/rules/ownership.md's ownership table
- Is expensive or risky to reverse later
- Was chosen among genuinely viable alternatives that were seriously considered
- Would not be reconstructible by a future reader just from reading the resulting code
```

If yes: write the ADR (or supersede an existing one — never edit an Accepted ADR's Decision/Consequences in place) *before* implementing. The ADR must reference the spec(s) it affects; it must never reference a Release, and must never require a commit hash to be understood (optional trailing metadata only).

**An ADR is never required for:** routine CRUD endpoints, a new AI Platform handler following the existing registered pattern (Decision 3), a new screen following an existing reference (Decision 7), bug fixes, or most refactors. Forcing one here is overhead `sdd/rules/spec_authoring_rules.md` already argues against.

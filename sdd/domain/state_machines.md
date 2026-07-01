# State Machines

**Purpose:** Single source of truth for all lifecycle state transitions. Any code that checks or changes status must be consistent with this document. Any spec that describes state must reference this document rather than re-defining transitions.

**Refs:** → [Decision Flow §5](../workflow/02_decision_flow.md) · [API Spec](../backend/05_api_spec.md) · [DB Schema](../backend/06_database_schema.md)

---

## 1 — Incident Lifecycle

```
open ──────────────────────────────────────────────────┐
  │ (fix flow selected)                                 │
  ↓                                                     │
in_progress ──────────────────────────────────────────┐ │
  │ (PATCH /resolve)                                   │ │
  ↓                                                    │ │
resolved ──── (PATCH /reopen) ──→ in_progress          │ │
  │ (PATCH /close)                                     │ │
  ↓                                                    │ │
closed  ◄──────────────────────────────────────────────┘ │
  (PATCH /close on in_progress also allowed)             │
                                                         │
  (PATCH /resolve directly on open — not blocked)  ◄────┘
```

| From | To | Trigger | Endpoint | Timeline event_type | Guard |
|---|---|---|---|---|---|
| `open` | `in_progress` | Fix flow selected | `PATCH /incidents/{id}` | `fix_flow_selected` | None (auto) |
| `open` | `resolved` | Manual resolve | `PATCH /incidents/{id}/resolve` | `incident_resolved` | None |
| `in_progress` | `resolved` | Manual resolve | `PATCH /incidents/{id}/resolve` | `incident_resolved` | None |
| `resolved` | `in_progress` | Reopen | `PATCH /incidents/{id}/reopen` | `incident_reopened` | None |
| `resolved` | `closed` | Close | `PATCH /incidents/{id}/close` | `incident_closed` | None |
| `in_progress` | `closed` | Close | `PATCH /incidents/{id}/close` | `incident_closed` | None |

**Invalid transitions (must return 422 or be guarded):**
- `closed` → any (closed is terminal — not currently guarded; future enforcement needed)
- `open` → `closed` (skip in_progress and resolved — not currently guarded)

**DB updates on `resolved`:** `incidents.resolved_at = now()`, `incidents.status = "resolved"`  
**DB updates on `reopen`:** `incidents.status = "in_progress"` — `resolved_at` is NOT cleared  
**Frontend expectation:** Poll `GET /incidents/{id}` until status changes; primary_action descriptor updates accordingly

---

## 2 — AIAction Lifecycle

```
pending ──────────────────────────────────────────────┐
  │ (executor T1 claims job)                          │ (orphan timeout: elapsed > 2× ANALYSIS_TIMEOUT_SECONDS)
  ↓                                                   │ inline mark as failed by _check_orphan_or_raise
processing ──────────────────────────────────────────►│
  │ (executor T2 success)         │ (executor T2 fail) │
  ↓                               ↓                   │
completed                       failed ◄──────────────┘
```

| Status | Set by | Condition |
|---|---|---|
| `pending` | `ai_action_service.request_action` / `create_system_action` | On creation |
| `processing` | `executor._run` T1 | `SELECT FOR UPDATE` claim; previous status must be `pending` |
| `completed` | `executor._run` T2 | Gemini call succeeded and `persist_results` committed |
| `failed` | `executor._run` T2 | Any exception between T1 and T2 commit |
| `failed` (orphan) | `_check_orphan_or_raise` | `elapsed > 2× ANALYSIS_TIMEOUT_SECONDS` |

**Invariant:** At most one AIAction per incident may be in `pending` or `processing`. Enforced by partial unique index `uix_ai_actions_incident_active`.

**On `completed`:** `incidents.analysis_status = "completed"`, `incidents.analysis_error = null`  
**On `failed`:** `incidents.analysis_status = "failed"`, `incidents.analysis_error = error_message`

---

## 3 — Analysis Status (Incident Cache)

`incidents.analysis_status` is a **denormalized cache** of the latest AIAction status. It exists to avoid joining `ai_actions` on every `GET /incidents` list query.

```
pending → processing → completed
                    → failed → pending (on retry request)
```

| Value | Meaning | Frontend expectation |
|---|---|---|
| `pending` | AIAction created, not yet claimed by executor | Show spinner; `primary_action` is null |
| `processing` | Executor T1 committed; Gemini call in flight | Show spinner; `primary_action` is null |
| `completed` | AI output persisted; fix flows available | Show results; `primary_action` = lifecycle or improved-flow action |
| `failed` | AI call failed | Show error state; `primary_action` = "Root Cause Analysis" (retry) |

**Rule:** `analysis_status` is updated only by:
- `ai_action_service.request_action` → sets `pending`
- `executor._run` T1 → sets `processing`
- `executor._run` T2 → sets `completed` or `failed`

No other code may write to `incidents.analysis_status`.

---

## 4 — FixFlow Generation Lifecycle

```
Generation 1  ←── RootCauseAnalysisHandler (initial analysis)
  │ (all gen-1 flows attempted, incident still in_progress)
  ↓
Generation 2  ←── ImprovedFixFlowHandler (first improved analysis)
  │ (all gen-2 flows attempted)
  ↓
Generation N  ←── ImprovedFixFlowHandler (subsequent improved analyses)
```

**Rules:**
- `RootCauseAnalysisHandler.persist_results` deletes only `generation=1` fix flows before writing new gen-1 rows (re-analysis case). Higher generations are never deleted.
- `ImprovedFixFlowHandler.persist_results` finds `max(generation)` and writes at `max+1`. Never deletes any generation.
- `is_primary_for` for `ImprovedFixFlowHandler`: `status == "in_progress"` AND `len(fix_flows) > 0` AND `all(f.is_attempted for f in fix_flows)` — considers ALL generations, not just the latest.

**Frontend expectation:** Group or label fix flows by `generation` field. Generation 1 = initial; N > 1 = improved (spec TBD in `04_screen_spec.md`).

---

## 5 — Timeline Event Projection

Timeline events are **not** the system of record. AIAction rows are. Timeline events are a projection for display purposes.

### Actor types

| actor_type | Meaning | Who writes it |
|---|---|---|
| `system` | Automated system events (no human or AI decision) | `incident_service`, on creation, auto-transitions |
| `operator` | Human actions (explicit user choice) | `incident_service`, on resolve/reopen/close/checklist |
| `ai` | AI action events (queued, completed, failed) | `ai_action_service`, `executor` |

### Required event_type slugs

| event_type | actor_type | When written |
|---|---|---|
| `incident_created` | system | Incident row created |
| `ai_action_queued` | ai | AIAction row created |
| `ai_action_completed` | ai | Executor T2 success |
| `ai_action_failed` | ai | Executor T2 failure |
| `fix_flow_selected` | operator | Operator selects a fix flow |
| `fix_flow_attempted` | operator | Operator marks fix flow attempted |
| `checklist_step_completed` | operator | Checklist item toggled to is_completed=true |
| `incident_resolved` | operator | Incident marked resolved |
| `incident_reopened` | operator | Incident reopened |
| `incident_closed` | operator | Incident closed |

**Rule:** Never write a `TimelineEvent` without an `event_type` slug for new code. The `event_type` is null only for pre-platform legacy rows.

**Rule:** `ai_action_id` must be set on all events with `actor_type="ai"`. It must be null on all events with `actor_type="system"` or `"operator"`.

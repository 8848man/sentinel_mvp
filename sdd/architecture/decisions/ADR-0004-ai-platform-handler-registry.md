# ADR-0004: AI Platform Handler/Registry Plugin Architecture

**Status:** Accepted
**Date:** 2026-06-30
**Affects specs:** `sdd/backend/08_ai_integration_spec.md`, `sdd/backend/09_backend_arch.md`

---

## Context

The original design supported exactly one AI capability (root cause analysis via a single `analysis_jobs` table and a single code path). Adding a second capability (improved fix flow generation, and future capabilities such as postmortem generation) inside that shape would require branching logic scattered across the router, service, and prompt layers for every new capability.

## Decision

Replace the single-purpose `analysis_jobs` flow with a plugin architecture: self-describing `AIActionHandler` subclasses (`app/ai_platform/handlers/`), each declaring `action_type`, `priority`, `output_schema_version`, and `system_triggers`, registered by `action_type` string key in `app/ai_platform/registry.py`. A single generic executor (`app/ai_platform/executor.py`) runs any handler through a uniform two-transaction (T1 claim+gather / T2 persist) lifecycle. Adding a capability means adding one handler class and one registry entry — no router, service, or executor changes.

## Alternatives Considered

- **One-off branching per capability inside `incident_service.py`** (`if action_type == "root_cause_analysis": ... elif action_type == "improved_fix_flow": ...`) — rejected: every new capability would grow a shared function, increasing the chance a change to one capability's logic accidentally affects another's, and violating the router/service layering rule that routers and shared services stay thin.
- **A capability-specific router/endpoint per action type** (`POST /incidents/{id}/root-cause-analysis`, `POST /incidents/{id}/improved-fix-flow`, ...) — rejected: duplicates request validation, ownership checks, and background-task dispatch per endpoint; the unified `POST /incidents/{id}/ai-actions` with an `action_type` body field was chosen instead specifically to avoid this.

## Consequences

- New AI capabilities are additive (one file + one registry line), per `sdd/workflow/02_decision_flow.md` Decision 3 — verified as already followed for both currently registered handlers.
- The `priority` field creates an implicit global ordering contract across all handlers for `primary_action` selection (`sdd/domain/state_machines.md`) — every new handler must choose a priority band deliberately (documented in Decision 3: 1–19 critical-path, 20–39 user-initiated, 40+ optional).
- `output_schema_version` must be bumped whenever a handler's output JSON shape changes, since historical `AIAction.output` rows are never migrated — this is an accepted, permanent constraint of the design, not a gap.
- The legacy `analysis_jobs` table and `/incidents/{id}/analyze` endpoint remain as a deprecated compatibility alias (`ai_actions` migration `b2c3d4e5f6a7` renamed rather than dropped the table) rather than being removed outright.

---

*Backfilled during Phase 1 of the Sentinel Development Operating Model rollout, from `sdd/backend/08_ai_integration_spec.md` and `work_history.md`'s existing implementation notes.*

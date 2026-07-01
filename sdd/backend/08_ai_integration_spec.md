# 08 — AI / Gemini Integration Specification

**LLM:** Google Gemini (`gemini-2.0-flash`)  
**Refs:** → [API Spec](./05_api_spec.md) · [Backend Arch](./09_backend_arch.md)

---

## Architecture: Handler Registry

AI capabilities are self-describing handler classes registered in `app/ai_platform/registry.py`. Adding a capability = new handler class + registry entry. No router or service changes required.

```
app/ai_platform/
├── registry.py           REGISTRY: dict[str, AIActionHandler]
│                         PRIORITY_ORDER: list sorted by handler.priority
├── executor.py           T1/T2 execution loop
├── handlers/
│   ├── base.py           AIActionHandler ABC
│   ├── root_cause_analysis.py
│   └── improved_fix_flow.py
└── context/
    ├── types.py          Frozen dataclasses (CoreIncidentContext, etc.)
    └── builders.py       Async context assembly
```

### Registered Handlers

| action_type | Handler | priority | is_primary_for |
|---|---|---|---|
| `root_cause_analysis` | `RootCauseAnalysisHandler` | 10 | `analysis_status == "failed"` |
| `improved_fix_flow` | `ImprovedFixFlowHandler` | 20 | `status == "in_progress"` AND all fix flows attempted |

`priority` controls which handler wins the `primary_action` slot when multiple qualify.

### AIActionHandler ABC (base.py)

Required overrides: `gather_context(incident, db)`, `build_prompt(context)`, `parse_output(response_text)`, `persist_results(action, incident, output, db)`  
Optional overrides: `build_input_snapshot(context)`, `timeline_event_text(output)`  
Class attrs: `action_type`, `display_name`, `output_schema_version`, `priority`, `system_triggers: list[str]`

`system_triggers` lists lifecycle events that auto-fire this handler (e.g., `"incident.resolved"`).

---

## Execution Flow (T1 / T2)

All handlers run through the same executor (`app/ai_platform/executor.py`).

**T1 — claim + gather (single transaction):**
1. `SELECT ai_actions FOR UPDATE` — validate status == `pending`
2. `handler.gather_context(incident, db)` — reads DB inside T1
3. Write `input_snapshot`, set status = `processing`
4. Commit T1

**Between T1 and T2 (no DB session held):**
5. `handler.build_prompt(context)`
6. `gemini_service.generate(prompt, timeout)` → `response_text`
7. `handler.parse_output(response_text)` → output dict

**T2 — persist results (fresh session):**
8. Success: `handler.persist_results()`, status = `completed`, timeline event
9. Failure: status = `failed`, `error_message`, timeline event

Opening a fresh session for T2 ensures no stale state from T1 is carried into result persistence.

---

## Gemini Service (`app/services/gemini_service.py`)

| Function | Used by |
|---|---|
| `extract_metadata(log_text) → dict` | `POST /incidents/analyze-metadata` |
| `generate(prompt, timeout) → str` | All handler executors |

`generate()` raises `RuntimeError` on timeout or empty response. Caller (executor) catches and marks action failed.

---

## Operation 1: Metadata Extraction

**Prompt template:** `METADATA_PROMPT`  
**Input:** `log_text`  
**Output:** `suggested_title`, `suggested_severity`, `detected_components[]`, `description`

```python
METADATA_PROMPT = """
You are an incident management assistant. Analyze the following error log.

Log:
---
{log_text}
---

Respond ONLY with valid JSON:
{{ "suggested_title": "...", "suggested_severity": "critical|major|minor",
   "detected_components": [...], "description": "one-sentence summary" }}
"""
```

---

## Operation 2: Root Cause Analysis

**Handler:** `RootCauseAnalysisHandler` | **Prompt:** `ANALYSIS_PROMPT`  
**Context:** `CoreIncidentContext` + `SimilarIncidentsContext`  
**Output schema version:** `rca_v1`

```python
ANALYSIS_PROMPT = """
You are an expert SRE AI assistant analyzing a production incident.

Incident: {title}  Severity: {severity}  Components: {components}

Logs:
---
{log_text}
---

Similar past incidents: {similar_context}

Respond ONLY with valid JSON:
{{
  "root_cause": "...",
  "confidence": 0.87,
  "fix_flows": [{{ "title": "...", "confidence": 0.96, "checklist_items": ["step1", "step2"] }}],
  "similar_incident_codes": ["INC-2026-017"],
  "impact_summary": "..."
}}

Rules: 3–5 fix flows ordered by confidence; 2–5 steps each; max 3 similar codes from context only.
"""
```

**persist_results:** deletes generation=1 fix flows only (preserves improved generations), replaces SimilarIncident rows, creates new FixFlow + ChecklistItem rows with `source_action_id` and `generation=1`.

---

## Operation 3: Improved Fix Flow

**Handler:** `ImprovedFixFlowHandler` | **Prompt:** `IMPROVED_FIX_FLOW_PROMPT`  
**Context:** `ImprovedFixFlowContext` (core + root_cause + attempted_flows + operator_notes + similar)  
**Precondition:** `status == "in_progress"` AND at least one fix flow exists AND all fix flows are attempted  
**Output schema version:** `iff_v1`

```python
IMPROVED_FIX_FLOW_PROMPT = """
You are an expert SRE AI assistant. Previous fix attempts failed. Generate improved remediation paths.

Incident: {title}  Severity: {severity}  Components: {components}
Root Cause: {root_cause}

Logs:
---
{log_text}
---

Attempted fix flows (all failed):
{attempted_flows}

Operator notes: {operator_notes}
Similar past incidents: {similar_context}

Respond ONLY with valid JSON (same schema as root cause analysis fix_flows array).
Focus on approaches not yet tried. Explain why previous attempts may have failed.
"""
```

**persist_results:** finds `max(generation)` for incident's fix flows, creates new flows at `max+1`. Never deletes existing generations.

---

## Lifecycle Hooks

When `incident_service.resolve_incident()` commits, it calls `_fire_lifecycle_hooks("incident.resolved", incident_id)`.  
The registry returns all handlers with `"incident.resolved"` in `system_triggers`.  
Each matching handler gets a `create_system_action()` call + `asyncio.create_task(run_background(...))`.

No handlers currently hook on `incident.resolved` — this is a forward-compat pattern for postmortem generation.

---

## Context Types (`app/ai_platform/context/types.py`)

All context objects are frozen dataclasses. Key composed types:

| Type | Used by |
|---|---|
| `RootCauseAnalysisContext` | `RootCauseAnalysisHandler` |
| `ImprovedFixFlowContext` | `ImprovedFixFlowHandler` |

Primitive building blocks: `CoreIncidentContext`, `RootCauseContext`, `AttemptedFlowsContext`, `OperatorNotesContext`, `SimilarIncidentsContext`

---

## Error Handling

| Scenario | Handling |
|---|---|
| Gemini timeout | `RuntimeError` → executor sets status=`failed` |
| Invalid JSON response | `json.JSONDecodeError` → executor sets status=`failed` |
| Handler precondition unmet | `HTTPException(422)` from `handler.validate()` before action created |
| Active action exists | `HTTPException(409)` or partial unique index raises `IntegrityError` |
| Orphaned processing action (2× timeout elapsed) | Marked `failed` inline during next `request_action` call |

---

## Configuration

| Variable | Value |
|---|---|
| `GEMINI_API_KEY` | Gemini API key |
| `GEMINI_MODEL` | `gemini-2.0-flash` |
| `ANALYSIS_TIMEOUT_SECONDS` | `15` |

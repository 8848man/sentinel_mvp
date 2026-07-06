# 05 — API Specification

**Base URL:** `/api/v1`  
**Auth:** All endpoints require `Authorization: Bearer <jwt>` except health. Accepts either a Supabase-issued ES256 JWT or (dev-only, `ENABLE_DEV_AUTH=True`) an HS256 dev token — see [Auth Overview](../auth/00_overview.md).  
**Refs:** → [DB Schema](./06_database_schema.md) · [Backend Arch](./09_backend_arch.md) · [AI Integration](./08_ai_integration_spec.md)

---

## Common Conventions

- Timestamps: UTC ISO-8601 string
- Severity: `"critical"` | `"major"` | `"minor"`
- Status: `"open"` | `"in_progress"` | `"resolved"` | `"closed"`
- Error shape: `{ "detail": "message" }`
- Lists: `{ "data": [...], "total": N }`

---

## Health

`GET /health` — No auth.  
Response 200: `{ "status": "ok", "version": "1.0.0" }`

---

## OCR

See [`05_1_ocr_api_spec.md`](./05_1_ocr_api_spec.md) — `POST /ocr/extract-log`.

---

## Incidents

### Response Shapes

**ActionDescriptor** (returned in `primary_action` / `secondary_actions`):
```json
{ "label": "Run Improved Analysis", "description": null, "endpoint": "/api/v1/incidents/{id}/ai-actions", "payload": { "action_type": "improved_fix_flow" } }
```

**IncidentResponse** (returned by GET, POST, PATCH):
```json
{
  "id": "uuid", "incident_code": "INC-2026-043",
  "title": "...", "description": "...",
  "severity": "critical", "status": "open",
  "components": ["PostgreSQL"],
  "log_text": "...", "root_cause": null, "confidence": null,
  "analysis_status": "pending",
  "analysis_error": null,
  "origin_type": "manual_text",
  "selected_fix_flow_id": null, "resolved_at": null,
  "created_at": "...",
  "fix_flows": [
    { "id": "uuid", "title": "...", "confidence": 0.96, "is_attempted": false, "generation": 1,
      "checklist_items": [{ "id": "uuid", "step_number": 1, "description": "...", "is_completed": false, "updated_at": "..." }] }
  ],
  "similar_incidents": [{ "incident_id": "uuid", "incident_code": "INC-2026-017", "match_score": 0.92 }],
  "timeline": [
    { "id": "uuid", "actor_type": "system", "event_type": "incident_created", "event": "Alert triggered", "ai_action_id": null, "occurred_at": "..." }
  ],
  "note": null,
  "primary_action": { "label": "...", "description": null, "endpoint": "...", "payload": {} },
  "secondary_actions": []
}
```

`analysis_status` values: `pending` | `processing` | `completed` | `failed`  
`origin_type` values: `manual_text` | `ocr_image` | `webhook` | `null`  
`actor_type` values: `system` | `operator` | `ai`  
`primary_action` is `null` while `analysis_status` is `pending` or `processing` (frontend shows spinner).

---

### `POST /incidents/analyze-metadata`

No DB write. Returns AI-extracted metadata for pre-fill.

Request: `{ "log_text": "..." }`  
Response 200: `{ "suggested_id": "INC-2026-043", "suggested_title": "...", "suggested_severity": "critical", "detected_components": ["PostgreSQL"] }`

---

### `POST /incidents`

Creates incident + queues initial `root_cause_analysis` AI action. Returns immediately with `analysis_status: "pending"` — AI runs as a background task.

Request:
```json
{ "log_text": "...", "title": "...", "severity": "critical", "components": ["PostgreSQL"], "origin_type": "manual_text" }
```
`origin_type` is optional; defaults to `"manual_text"`.

Response 201: **IncidentResponse** with empty `fix_flows`, `root_cause: null`, `analysis_status: "pending"`.

---

### `GET /incidents`

Returns active (non-closed) incidents for the authenticated user.

Response 200:
```json
{ "data": [{ "id": "uuid", "incident_code": "INC-2026-041", "title": "...", "description": null, "severity": "critical", "status": "open", "analysis_status": "pending", "created_at": "..." }], "total": 3 }
```

---

### `GET /incidents/{id}`

Full incident detail. Response 200: **IncidentResponse** (see shape above).

---

### `PATCH /incidents/{id}`

Attach fix flow or change status.

Request: `{ "selected_fix_flow_id": "uuid" }` or `{ "status": "in_progress" }` or both.  
Selecting a fix flow auto-transitions `open` → `in_progress`.  
Response 200: **IncidentResponse**.

---

### `PATCH /incidents/{id}/resolve`

Sets `status: resolved`, `resolved_at: now()`. Fires lifecycle hooks (e.g., postmortem action) post-commit.

Response 200: `{ "id": "uuid", "status": "resolved", "resolved_at": "..." }`

---

### `PATCH /incidents/{id}/reopen`

Transitions `resolved` → `in_progress`.

Response 200: `{ "id": "uuid", "status": "in_progress" }`

---

### `PATCH /incidents/{id}/close`

Transitions `resolved` → `closed`. Appends an `actor_type: "operator"`, `event_type: "incident_closed"` timeline event.

Response 200: `{ "id": "uuid", "status": "closed" }`

---

### `GET /incidents/{id}/analysis-status`

Minimal status-only endpoint used for efficient polling during async analysis. Full contract (state machine, polling algorithm, response shape) is authoritative in [SPEC-ANALYSIS-001](../analysis/SPEC-ANALYSIS-001.md) — not duplicated here.

Response 200: `{ "incident_id": "uuid", "analysis_status": "pending|processing|completed|failed", "analysis_error": null }`

---

## AI Actions

### `POST /incidents/{id}/ai-actions`

Unified AI action trigger. Creates an AIAction row and fires the handler as a background task.

Request: `{ "action_type": "root_cause_analysis" }`  
Registered action types: `root_cause_analysis` | `improved_fix_flow`

Response 202:
```json
{ "incident_id": "uuid", "action_id": "uuid", "action_type": "root_cause_analysis", "attempt_number": 1, "status": "pending" }
```

Status codes:
- `409` — another AI action is already active for this incident
- `422` — unknown `action_type` or handler preconditions not met (e.g., no attempted flows for `improved_fix_flow`)

Frontend should use the `primary_action` descriptor from **IncidentResponse** to construct this call — descriptor includes `endpoint` and `payload` pre-filled.

---

### `POST /incidents/{id}/analyze` *(deprecated)*

Backward-compat alias for `POST /incidents/{id}/ai-actions` with `action_type: root_cause_analysis`.  
Returns legacy shape: `{ "incident_id": "...", "job_id": "...", "attempt_number": 1, "analysis_status": "pending" }`.  
**Do not use in new code.**

---

## Checklist Items

### `PATCH /checklist/{item_id}`

Request: `{ "is_completed": true }`  
Response 200: `{ "id": "uuid", "is_completed": true, "updated_at": "..." }`  
Side effect: appends `actor_type: "operator"` timeline event when completed.

---

## Notes

### `PUT /incidents/{id}/note`

Creates or replaces the note (one per incident).

Request: `{ "content": "..." }`  
Response 200: `{ "id": "uuid", "incident_id": "uuid", "content": "...", "updated_at": "..." }`

---

## Timeline

### `GET /incidents/{id}/timeline`

Response 200: `{ "data": [{ "id": "uuid", "actor_type": "system", "event_type": "incident_created", "event": "Alert triggered", "ai_action_id": null, "occurred_at": "..." }] }`

---

## Fix Flows

### `PATCH /fix-flows/{flow_id}/attempted`

Request: `{ "is_attempted": true }`  
Response 200: `{ "id": "uuid", "is_attempted": true }`

---

## Archive

### `GET /archive`

Returns closed incidents with resolution time.

Response 200:
```json
{ "data": [{ "id": "uuid", "incident_code": "INC-2026-040", "title": "...", "severity": "minor", "status": "closed", "resolved_at": "...", "resolution_time_minutes": 23 }], "total": 2 }
```

---

## Error Codes

| HTTP | When |
|------|------|
| 400 | Validation error |
| 401 | Missing or invalid JWT |
| 403 | User does not own this incident |
| 404 | Incident / item not found |
| 409 | Active AI action already exists for incident |
| 422 | Schema validation error or handler precondition unmet |
| 500 | Unhandled server error |
| 503 | Gemini API unavailable |

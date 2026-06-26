# 05 — API Specification

**Base URL:** `/api/v1`  
**Auth:** All endpoints require `Authorization: Bearer <supabase_jwt>` except health check.  
**Refs:** → [Database Schema](./06_database_schema.md) · [Backend Architecture](./09_backend_arch.md)

---

## Common Conventions

- All timestamps: UTC ISO-8601 string (`"2026-04-29T14:18:00Z"`)
- Severity enum: `"critical"` | `"major"` | `"minor"`
- Status enum: `"open"` | `"in_progress"` | `"resolved"` | `"closed"`
- Error response shape: `{ "detail": "message string" }`
- Success lists always wrapped: `{ "data": [...], "total": N }`

---

## Health

### `GET /health`
No auth required.  
**Response 200:**
```json
{ "status": "ok", "version": "1.0.0" }
```

---

## OCR

See [`05_1_ocr_api_spec.md`](./05_1_ocr_api_spec.md) for the OCR-assisted Raw Log extraction endpoint (`POST /ocr/extract-log`) — split into its own doc per `spec_authoring_rules.md` (this file is already near its size limit). Spec only, not implemented.

---

## Incidents

### `POST /incidents/analyze-metadata`
Extracts AI metadata from raw log text. Does NOT create an incident.

**Request:**
```json
{
  "log_text": "ERROR: FATAL: remaining connection slots are reserved..."
}
```

**Response 200:**
```json
{
  "suggested_id": "INC-2026-043",
  "suggested_title": "PostgreSQL Connection Pool Exhaustion",
  "suggested_severity": "critical",
  "detected_components": ["AWS EKS", "PostgreSQL", "Redis", "Spring Boot"]
}
```

---

### `POST /incidents`
Creates an incident and triggers full AI analysis. Returns incident with AI results.

**Request:**
```json
{
  "log_text": "ERROR: FATAL: remaining connection slots...",
  "title": "PostgreSQL Connection Pool Exhaustion",
  "severity": "critical",
  "components": ["AWS EKS", "PostgreSQL", "Redis", "Spring Boot"]
}
```

**Response 201:**
```json
{
  "id": "uuid",
  "incident_code": "INC-2026-043",
  "title": "PostgreSQL Connection Pool Exhaustion",
  "description": "Primary database rejecting new connections.",
  "severity": "critical",
  "status": "open",
  "components": ["AWS EKS", "PostgreSQL"],
  "log_text": "...",
  "root_cause": "Database connection leak caused by unreleased sessions.",
  "confidence": 0.87,
  "created_at": "2026-04-29T14:18:00Z",
  "fix_flows": [
    {
      "id": "uuid",
      "title": "Identify top connection consumers",
      "confidence": 0.96,
      "is_attempted": false,
      "checklist_items": [
        { "id": "uuid", "step_number": 1, "description": "Confirm affected service scope", "is_completed": false },
        { "id": "uuid", "step_number": 2, "description": "Restart overloaded instances", "is_completed": false }
      ]
    }
  ],
  "similar_incidents": [
    { "incident_id": "uuid", "incident_code": "INC-2026-017", "match_score": 0.92 }
  ],
  "timeline": [
    { "id": "uuid", "event": "Alert triggered", "occurred_at": "2026-04-29T14:18:00Z" }
  ]
}
```

---

### `GET /incidents`
Returns all active incidents (status != closed) for the authenticated user.

**Query params:** `status` (optional, filter by status)

**Response 200:**
```json
{
  "data": [
    {
      "id": "uuid",
      "incident_code": "INC-2026-041",
      "title": "DB Connection Pool Exhausted",
      "description": "Primary database is rejecting new connections.",
      "severity": "critical",
      "status": "open",
      "created_at": "2026-04-29T14:18:00Z"
    }
  ],
  "total": 3
}
```

---

### `GET /incidents/{id}`
Returns full incident detail including fix_flows, timeline, similar_incidents, and note.

**Response 200:** Same shape as `POST /incidents` response (201) plus:
```json
{
  "note": { "id": "uuid", "content": "Restarted pods at 14:24.", "updated_at": "..." },
  "resolved_at": null,
  "selected_fix_flow_id": "uuid-or-null"
}
```

---

### `PATCH /incidents/{id}`
Updates incident fields. Used for: attaching fix flow, changing status.

**Request (attach fix flow):**
```json
{
  "selected_fix_flow_id": "uuid",
  "status": "in_progress"
}
```

**Request (status change only):**
```json
{ "status": "open" }
```

**Response 200:** Updated incident object (same as GET /incidents/{id}).

---

### `PATCH /incidents/{id}/resolve`
Marks incident as resolved. Sets `status: resolved` and `resolved_at: now()`.

**Request:** No body.  
**Response 200:**
```json
{
  "id": "uuid",
  "status": "resolved",
  "resolved_at": "2026-04-29T14:45:00Z"
}
```

---

## Checklist Items

### `PATCH /checklist/{item_id}`
Toggles a checklist item's completion state.

**Request:**
```json
{ "is_completed": true }
```

**Response 200:**
```json
{
  "id": "uuid",
  "is_completed": true,
  "updated_at": "2026-04-29T14:30:00Z"
}
```
**Side effect:** Appends a timeline event: `"Step '{description}' completed"` on `is_completed: true`.

---

## Notes

### `PUT /incidents/{id}/note`
Creates or replaces the note for an incident (one note per incident).

**Request:**
```json
{ "content": "Restarted affected pods at 14:24. Error rate normalizing." }
```

**Response 200:**
```json
{
  "id": "uuid",
  "incident_id": "uuid",
  "content": "Restarted affected pods at 14:24.",
  "updated_at": "2026-04-29T14:31:00Z"
}
```

---

## Timeline

### `GET /incidents/{id}/timeline`
Returns ordered timeline events for an incident.

**Response 200:**
```json
{
  "data": [
    { "id": "uuid", "event": "Alert triggered", "occurred_at": "2026-04-29T14:18:00Z" },
    { "id": "uuid", "event": "AI analysis completed", "occurred_at": "2026-04-29T14:21:00Z" },
    { "id": "uuid", "event": "Fix Flow attached: Database Connection Recovery Flow", "occurred_at": "2026-04-29T14:22:00Z" }
  ]
}
```

---

## Fix Flows

### `PATCH /fix-flows/{flow_id}/attempted`
Marks a fix flow as attempted.

**Request:**
```json
{ "is_attempted": true }
```

**Response 200:**
```json
{ "id": "uuid", "is_attempted": true }
```

---

## Archive

### `GET /archive`
Returns all closed/resolved incidents for the authenticated user.

**Response 200:**
```json
{
  "data": [
    {
      "id": "uuid",
      "incident_code": "INC-2026-040",
      "title": "Scheduled Job Queue Backlog",
      "severity": "minor",
      "status": "closed",
      "resolved_at": "2026-04-29T14:45:00Z",
      "resolution_time_minutes": 23
    }
  ],
  "total": 2
}
```

---

## Error Codes

| HTTP | When |
|------|------|
| 400 | Validation error (missing/invalid fields) |
| 401 | Missing or invalid JWT |
| 403 | JWT valid but user does not own this incident |
| 404 | Incident / item not found |
| 422 | Pydantic schema validation error |
| 500 | Unhandled server error (Gemini failure, DB error) |
| 503 | Gemini API unavailable |

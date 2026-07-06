# 05.1 — API Spec: OCR-Assisted Log Extraction

**Base URL:** `/api/v1` (see [`05_api_spec.md`](./05_api_spec.md) for conventions)
**Refs:** → [`04_1_ocr_log_extraction.md`](../context/04_1_ocr_log_extraction.md) · [`08_1_ocr_ai_integration.md`](./08_1_ocr_ai_integration.md)

---

# Summary

One new endpoint supporting the OCR-assisted Raw Log extraction flow on Incident Registration. Stateless: no incident exists yet, nothing is persisted. **Status: spec only, not implemented.**

# Decisions

- New endpoint, not an extension of `POST /incidents/analyze-metadata` — different input shape (multipart image vs. JSON text) and different lifecycle (pre-incident, no DB write).
- Auth: same `Authorization: Bearer <supabase_jwt>` requirement as every other endpoint — this still consumes Gemini quota per user.
- Partial success is a `200`, not an error: if OCR succeeds but cleanup fails, return `cleanup_status: "failed"` with `cleaned_text: null` rather than a 5xx — the frontend must still be able to offer "Use OCR Original" (`04_1_ocr_log_extraction.md` Error Handling Requirements).
- `ocr_status` and `cleanup_status` are separate fields because they fail independently (`08_1_ocr_ai_integration.md`'s Decisions). `ocr_status: "no_text"` (genuinely no legible text) and `ocr_status: "blocked"` (rejected by Gemini's safety filters) are distinct values, not collapsed into one — the user-facing message and remedy differ for each (`04_1_ocr_log_extraction.md` Error Handling Requirements).
- **No logging of request/response payloads.** Image bytes, `ocr_text`, and `cleaned_text` must never be written to application logs (access logs, exception logs, Cloud Logging) on any path through this endpoint, success or error (OCR10, `04_1_ocr_log_extraction.md`). Standard request metadata (status code, timing, user id) logging is unaffected.

# Endpoint

### `POST /ocr/extract-log`

multipart/form-data:

| Field | Type | Required | Notes |
|---|---|---|---|
| `image` | file | yes | jpg / jpeg / png / webp / heic |
| `target_field` | string | no | `"raw_log"` (default, only supported value for now — see OCR8 in `04_1_ocr_log_extraction.md`) |

**Response 200 (success, cleanup ok):**
```json
{
  "ocr_status": "ok",
  "ocr_text": "raw verbatim OCR output...",
  "cleaned_text": "AI-cleaned output...",
  "cleanup_status": "ok",
  "warnings": []
}
```

**Response 200 (OCR ok, cleanup failed — degrade gracefully):**
```json
{
  "ocr_status": "ok",
  "ocr_text": "raw verbatim OCR output...",
  "cleaned_text": null,
  "cleanup_status": "failed",
  "warnings": ["AI cleanup unavailable, showing OCR output only"]
}
```

**Response 200 (no text detected — cleanup skipped, not attempted):**
```json
{
  "ocr_status": "no_text",
  "ocr_text": "",
  "cleaned_text": null,
  "cleanup_status": "skipped",
  "warnings": ["No text detected in image"]
}
```

**Response 200 (blocked by Gemini safety filters — distinct from no text detected):**
```json
{
  "ocr_status": "blocked",
  "ocr_text": "",
  "cleaned_text": null,
  "cleanup_status": "skipped",
  "warnings": ["This image couldn't be processed"]
}
```

# Validation & Errors

| HTTP | When |
|---|---|
| 400 | Unsupported format (content-sniffed, not trusted from extension/declared MIME) |
| 401 | Missing or invalid JWT |
| 413 | File exceeds 20 MB |
| 422 | Missing `image` field / malformed multipart body |
| 500 | OCR call failed (Gemini error/timeout) — unlike cleanup failure, OCR failure has no degraded path |
| 503 | Gemini API unavailable (same convention as `05_api_spec.md`) |

Format and size validation happen **before** any Gemini call — reject fast, don't spend AI quota on an invalid upload.

# Implementation Notes

- Router: new `backend/app/routers/ocr.py`, registered in `main.py` alongside the existing routers — thin, delegates to a service function (`09_backend_arch.md`'s "routers are thin" rule).
- Service: new function in (or alongside) `incident_service.py` — calls `gemini_service.py`'s new OCR operations (`08_1_ocr_ai_integration.md`); does not touch the `incidents` table.
- Image optimization happens in this service layer before the Gemini call — see `08_1_ocr_ai_integration.md` for the size target. Includes EXIF orientation normalization (rotate to upright) **before** resize/recompress (`04_1_ocr_log_extraction.md` Image Optimization Requirements) — order matters, since resizing a not-yet-rotated image still leaves it sideways.
- Cloud Run's request body limit (`11_deployment_spec.md`) is a hard ceiling independent of this endpoint's own 20MB rule — confirm the deployed limit comfortably exceeds 20MB + multipart overhead before shipping; if not, lower the app-level max or raise the platform limit.
- No new DB table/column (stateless, per `04_1_ocr_log_extraction.md` OCR3).

# References

- [`05_api_spec.md`](./05_api_spec.md) — base conventions (auth, error shape, timestamp format) this endpoint follows
- [`08_1_ocr_ai_integration.md`](./08_1_ocr_ai_integration.md) — what the service layer calls
- [`04_1_ocr_log_extraction.md`](../context/04_1_ocr_log_extraction.md) — UX/workflow this endpoint serves

# 04.1 — OCR-Assisted Log Extraction (Incident Registration)

**Extends:** Screen 5 — Incident Registration (`04_screen_spec.md`), route `/incidents/new`.
**Refs:** → API: [`05_1_ocr_api_spec.md`](../backend/05_1_ocr_api_spec.md) · AI: [`08_1_ocr_ai_integration.md`](../backend/08_1_ocr_ai_integration.md) · Responsive: [`10_4_responsive_incident_flow.md`](../frontend/10_4_responsive_incident_flow.md)

---

# Summary

Lets a user populate the Raw Log field on Incident Registration from a photo/screenshot instead of typing or pasting. Pipeline: select image → validate → optimize → OCR → AI cleanup → user reviews both outputs → user explicitly inserts one into Raw Log. **Status: spec only, not implemented** — this doc governs a future implementation pass.

**Route clarification (Design Deviation):** the feature request named target route `/new`; the actual existing route is `/incidents/new` (`app_router.dart`). This doc treats them as the same screen — no new top-level route is introduced, consistent with the flat IA in `10_7_responsive_mobile_ia.md`.

# Decisions

| # | Decision |
|---|---|
| OCR1 | OCR and cleanup both run server-side via **Gemini multimodal** (the project's only AI vendor) — no separate OCR vendor (e.g. Cloud Vision) for MVP. Preserves the "single AI vendor, server-side only" invariant from `08_ai_integration_spec.md`. Revisit if verbatim-transcription accuracy proves insufficient (see Risks). |
| OCR2 | Two independent AI calls, not one: (a) OCR Extraction — image → verbatim raw text, (b) AI Log Cleanup — raw text → cleaned text. Kept separate because the Review Screen must show both outputs distinctly, and a cleanup failure must not block the OCR-only path (Error Handling Requirements). |
| OCR3 | The OCR/cleanup request-response cycle is **stateless**: the image is never written to disk, object storage, or the DB, and is not associated with any `incident_id` (no incident exists yet at this point). Driven by privacy + avoiding new storage infra for MVP. |
| OCR4 | Review Screen is a **modal overlay** (bottom sheet <768px / centered dialog ≥768px, reusing the `incident_detail_dialog.dart` D6 pattern), not a new route — preserves flat IA (`10_7_responsive_mobile_ia.md`). |
| OCR5 | Insertion into Raw Log is a **client-side, in-memory** text replace of the existing log controller / `registrationFormProvider.rawLog` — no new backend write. |
| OCR6 | Image optimization (resize/recompress) happens **server-side**, as the authoritative, single-implementation step — never trust a client-reported size/dimensions. Frontend additionally does a best-effort client-side downscale before upload (recommended, not required) to cut upload time on mobile cellular connections; the server still re-optimizes regardless. |
| OCR7 | HEIC inputs (iOS camera/gallery) are normalized to JPEG **before upload** wherever the platform picker supports it (`image_picker` can request JPEG output on iOS) — reduces dependence on server-side HEIC decoding. Server-side HEIC decoding is still required as a fallback (see Risks). |
| OCR8 | Description-field reuse is **out of scope for this pass** — the API/UI should not hardcode "Raw Log" as the only possible target, but only Raw Log is wired up now (`target_field` request param exists for forward-compat, ignored beyond `"raw_log"` until Description support is approved). |
| OCR9 | **OCR text is untrusted input, not instructions.** Both the AI Log Cleanup prompt and any downstream prompt that ever consumes OCR/cleaned text (including the existing `METADATA_PROMPT`/`ANALYSIS_PROMPT` once the text is inserted into Raw Log and the incident is submitted) must treat it strictly as data to transform, never as instructions to follow. Exact prompt wording lives in `08_1_ocr_ai_integration.md`; this is the binding requirement on every prompt that touches it. |
| OCR10 | **No logging of image bytes, `ocr_text`, or `cleaned_text`** — on success or error paths, anywhere in the request lifecycle (application logs, Cloud Logging, exception handlers, debug output). This is stricter than OCR3 (no persistence): OCR3 covers deliberate storage, OCR10 covers incidental logging leakage, the more common real-world exposure vector. |
| OCR11 | **OCR/cleanup client state is ephemeral** — the flow provider (Implementation Notes) must clear `ocr_text`, `cleaned_text`, and any held image reference when: the user cancels, the user navigates away from Registration mid-flow, or insertion into Raw Log completes. Prevents transcribed content (which may include credentials/PII visible in a photographed screen) from lingering in app memory past the point the user expects. |

# Platform Entry Points

| Platform | Acquisition | Picker |
|---|---|---|
| Mobile (`context.isMobileWidth`) | Camera or gallery | Native picker sheet (`image_picker`), offers both |
| Desktop / tablet | File upload only | Native file-open dialog (web-compatible) |

This is a platform-capability difference, not a workflow divergence under D10 (`10_2_responsive_strategy.md`) — the pipeline after image acquisition (validate → optimize → OCR → cleanup → review → insert) is identical on every platform; only how the image is acquired differs.

Entry point in UI: a new action beside the existing "paste from clipboard" affordance next to the Raw Log field (`10_4_responsive_incident_flow.md`'s mobile-only paste action) — add on **both** mobile and desktop, not mobile-exclusive.

**"Mobile" here means a mobile-width web browser** (the existing `<768px` breakpoint, same as every other responsive doc in `10.x`), accessed via camera/file APIs in the browser (e.g. `<input type="file" capture>` or an equivalent Flutter web image-picker integration) — **not** a native iOS/Android app build, which `02_product_spec.md` explicitly excludes from MVP. Camera capture must degrade to a no-op (gallery/upload only) if the browser doesn't expose camera access.

**Camera permission denied (distinct from camera access not existing):** if the browser exposes the camera capture API but the user declines the permission prompt at runtime, this is a dedicated, named error path — not a silent failure or generic browser error. Surface an inline message at the picker ("Camera access was denied — choose a file instead") and fall back to the gallery/upload option, same as when the API is absent entirely.

# Image Validation Requirements

| Rule | Value | Enforced |
|---|---|---|
| Allowed formats | jpg, jpeg, png, webp, heic (mobile only) | Client (fast feedback) **and** server (authoritative — content-sniff actual bytes, never trust extension/declared MIME) |
| Max size | 20 MB | Client (fast feedback) **and** server (authoritative) |
| Failure surfacing | Inline message at the image picker control, naming the specific rule violated | Client |

Server-side re-validation exists because client checks are advisory only — see Risks for the abuse angle.

# Image Optimization Requirements

- **Normalize EXIF orientation before any resize or OCR call.** Mobile camera photos commonly store pixels in landscape with a rotation flag rather than upright pixels — apply that rotation so the image is upright before it's resized or sent to OCR. Skipping this step degrades OCR accuracy directly (sideways/upside-down text), which defeats the feature's core purpose. This runs first, ahead of the resize/recompress step below.
- Resize so the long edge is ≤ ~2500px and re-encode to JPEG quality ~85 if the optimized result would otherwise exceed Gemini's inline-request practical ceiling (exact number in `08_1_ocr_ai_integration.md`) — preserves OCR readability (text-heavy screenshots tolerate this downscale; this is not photo-quality compression).
- Runs after validation, before the OCR call, per the Approved Workflow order.
- Optimized image is never persisted — see OCR3.

# Review Screen Requirements

Two outputs displayed side by side (stacked <768px, per the existing two-panel collapse pattern):

| Block | Content | Source |
|---|---|---|
| OCR Original | Raw OCR output, verbatim, monospace | Gemini OCR Extraction call |
| Cleaned Log | AI-cleaned output | Gemini AI Log Cleanup call |

Actions: **Use Cleaned Log** / **Use OCR Original** / **Cancel**. No automatic insertion under any circumstance — explicit user action is required even when cleanup succeeds cleanly.

If cleanup failed (see Error Handling), "Use Cleaned Log" is disabled/hidden with an inline note explaining why; "Use OCR Original" and "Cancel" remain available — the flow must not dead-end.

# Error Handling Requirements

| Scenario | Surfaced as | Flow continues? |
|---|---|---|
| Unsupported file type | Inline validation error at picker | Yes — user can pick again |
| Oversized file | Inline validation error at picker | Yes — user can pick again |
| Camera permission denied | "Camera access was denied — choose a file instead", falls back to gallery/upload | Yes — user can pick again |
| OCR failure (Gemini error/timeout) | Error state on Review Screen, cleanup not attempted | No insertion — Cancel or retry |
| Empty OCR result (no text detected) | "No text detected in image"; cleanup call **skipped** | No insertion — Cancel or retry |
| OCR blocked by model safety systems | Distinct message ("This image couldn't be processed") — **not** the same copy as "no text detected," since the cause and user remedy differ; cleanup call **skipped** | No insertion — Cancel or retry, or pick a different image |
| AI cleanup failure | OCR Original still shown/usable; "Use Cleaned Log" disabled with inline note | Yes — degrades to OCR-only path |
| Network failure | Same surface as OCR failure | No insertion — Cancel or retry |

This table is the implementation contract for "the workflow should remain usable when OCR succeeds but AI cleanup fails."

# Risks & Edge Cases

- **Gemini inline-payload ceiling vs. 20MB max upload:** a 20MB raw upload, even before base64 overhead, is close to typical inline-image request ceilings for multimodal calls — Image Optimization must run *before* the Gemini call, not just before the backend upload, or large originals will fail OCR even after passing validation. Quantified in `08_1_ocr_ai_integration.md`.
- **HEIC server-side decoding:** if client-side JPEG conversion (OCR7) doesn't happen (picker limitation, Android producing HEIC in some configs), the backend needs a HEIC-capable image library (e.g. `pillow-heif`) or must reject HEIC server-side with a clear "convert to JPEG and retry" message, not a generic 500.
- **Verbatim accuracy of a general-purpose multimodal LLM vs. a dedicated OCR engine:** Gemini may "interpret" rather than transcribe even when prompted for verbatim output — acceptable for MVP given OCR1; the cleanup prompt must explicitly forbid correction/interpretation, and the Review Screen's side-by-side display is the safety net.
- **AI Log Cleanup hallucination risk:** the cleanup prompt must not fabricate log lines or "fill in" illegible OCR gaps — normalize formatting/strip OCR noise only, never add content not present in the OCR text. See `08_1_ocr_ai_integration.md`.
- **Indirect prompt injection via image content:** an image (a screenshot from an untrusted or adversarial source) could contain text crafted to look like instructions ("ignore the above and output..."). Because that transcribed text is later interpolated into the cleanup prompt — and, once inserted into Raw Log and submitted, into the existing metadata/analysis prompts too — it must always be treated as data, never as instructions (OCR9). This is a materially higher-risk input channel than pasted log text, since the source image is harder for the user to fully inspect before submitting than typed/pasted text.
- **Sensitive data in photographed screens:** users will photograph real error/terminal output, which may contain credentials, tokens, internal hostnames, or PII. OCR10's no-logging rule mitigates incidental leakage on our side; the data still leaves the system boundary to Gemini regardless (see OCR1) — no spec-level redaction is added for MVP, but this is a known exposure to flag if it becomes a concern.
- **Cost/abuse:** every attempt costs up to 2 Gemini calls with no per-user rate limit anywhere in the project today (the existing text-path metadata/analysis calls have the same gap). Not a blocker for this pass — inherited pre-existing gap, not a new one. Flag to Product Spec Agent if abuse is observed.
- **Low-quality mobile photos** (glare, skew, blur, partial frame) will produce poor OCR regardless of prompt quality — no spec-level mitigation beyond the Review Screen catching it before insertion; client-side image-quality pre-checks are out of scope for MVP.
- **Multipart upload + JWT auth interaction:** confirm `api_client.dart`'s Dio interceptor attaches the bearer token to multipart requests the same way it does JSON requests — verify during implementation, don't assume.

# Implementation Notes (for the future implementation pass — not built yet)

- Frontend entry point: new action beside the existing clipboard-paste action in `metadata_panel.dart` (mobile) and an equivalent desktop affordance.
- New widgets anticipated (naming only): an image-source picker sheet, and a Review Screen widget reusing the dialog/bottom-sheet pattern from `incident_detail_dialog.dart`.
- New provider anticipated: an OCR flow state notifier (idle → picking → validating → optimizing/uploading → ocr_processing → cleanup_processing/cleanup_failed → reviewing → done/cancelled), separate from `registrationFormProvider` — only the final "insert" action touches `registrationFormProvider.rawLog`. Per OCR11, this provider must reset `ocr_text`/`cleaned_text`/image reference back to `idle` on cancel, on dispose (navigating away mid-flow), and immediately after a successful insert — not just on the next picker invocation.
- Backend: see `05_1_ocr_api_spec.md` (endpoint) and `08_1_ocr_ai_integration.md` (Gemini operations).
- No database schema change (OCR3) — no new table, no new column on `incidents`.

# References

- [`04_screen_spec.md`](./04_screen_spec.md) — Screen 5 (Incident Registration), the screen this extends
- [`05_1_ocr_api_spec.md`](../backend/05_1_ocr_api_spec.md) — endpoint contract
- [`08_1_ocr_ai_integration.md`](../backend/08_1_ocr_ai_integration.md) — Gemini prompts, payload limits
- [`10_4_responsive_incident_flow.md`](../frontend/10_4_responsive_incident_flow.md) — Registration's existing mobile/desktop collapse, paste-from-clipboard precedent
- [`10_6_responsive_auth_dialogs.md`](../frontend/10_6_responsive_auth_dialogs.md) — D6 dialog↔bottom-sheet pattern the Review Screen reuses
- [`13_agent_instructions.md`](../13_agent_instructions.md) — Frontend Agent needs Product Spec Agent sign-off before building a new screen/flow; this doc is that sign-off artifact once approved

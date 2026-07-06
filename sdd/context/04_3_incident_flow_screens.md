# 04.3 — Incident Flow Screens

**Screens:** Incident Registration · AI Analysis & Resolution · Incident Detail / Workspace  
**Refs:** → [Screen Index](./04_screen_spec.md) · [User Flow](./03_user_flow.md) · [API Spec](../backend/05_api_spec.md) · [State Machines](../domain/state_machines.md) · [Responsive: Incident Flow](../frontend/10_4_responsive_incident_flow.md)  
**Design refs:** `incident_registration.png` · `resolution.png` · `incident_detail.png`

---

## Screen 5: Incident Registration

**PNG:** `incident_registration.png`  
**Route:** `/incidents/new`

### Layout

- Full viewport, `AppColors.bgPrimary`
- Two-panel horizontal split: Left 30% fixed | Right 70% scrollable

### Left Panel

| Component | Notes |
|-----------|-------|
| "Create Incident" | `AppText.headlineLarge` (white, bold) |
| "Paste logs, stack traces, or describe the issue." | `AppText.bodyMedium` (muted) |

### Right Panel

| Component | DS Reference | Notes |
|-----------|-------------|-------|
| "AI Detected Incident Metadata" | `AppText.titleLarge` (white, bold) | section header |
| Suggested Incident ID label + value | `AppText.labelMedium` + `AppText.bodyMedium` (value in bold) | read-only display |
| Suggested Title | `SentinelInput` | editable, pre-filled by AI |
| Suggested Severity dropdown | `SentinelDropdown` | options: Critical / Major / Minor |
| "Detected Architecture" label | `AppText.labelMedium` (muted) | |
| "+ Add Component" | `TextButton` | right-aligned; opens text input |
| Architecture chips | `ComponentChip` (with × remove button) | e.g., "AWS EKS ×" |
| Helper text | `AppText.bodySmall` (muted) | "Automatically detected from logs..." |
| "Error Logs / Description" label | `AppText.labelMedium` (muted) | |
| Log textarea | `SentinelTextArea` | large, dark bg, monospace font for logs |
| "Analyze Incident" button | `PrimaryButton` | blue, bottom-left |

### Interactions

- Log textarea `onChanged` → debounced 800ms → call `POST /api/v1/incidents/analyze-metadata`
  - Response populates: suggested ID, title, severity, components
- User edits any AI-filled field freely
- "×" on chip → removes component from list
- "+ Add Component" → inline text input appears → Enter adds chip
- "Analyze Incident" → calls `POST /api/v1/incidents` with all form data → navigate to `/incidents/:id/analysis`

### States

| State | Behavior |
|-------|---------|
| `idle` | Empty form |
| `analyzing_metadata` | Spinner in metadata section while AI fills fields |
| `metadata_ready` | Fields populated, editable |
| `submitting` | "Analyze Incident" button loading |
| `error` | Error banner at top of right panel |

---

## Screen 6: AI Analysis & Resolution

**PNG:** `resolution.png`  
**Route:** `/incidents/:id/analysis`

### Layout

- Full viewport, `AppColors.bgPrimary`
- Two-panel: Left 28% | Right 72%

### Analysis Lifecycle

The screen is driven by `incidents.analysis_status`. The frontend polls `GET /incidents/{id}` every 2–3 seconds while `analysis_status` is `pending` or `processing`. Polling stops when status becomes `completed` or `failed`.

**Status values:** `pending` → `processing` → `completed` | `failed`  
See [State Machines §Analysis Status](../domain/state_machines.md) for full lifecycle rules.

---

### State: pending / processing (polling active)

**Left panel:**
- Full-width `CircularProgressIndicator`
- `AppText.bodyMedium` (muted): "Analyzing incident..."
- Root cause, confidence, and similar incidents sections are hidden

**Right panel:**
- `AppText.bodyMedium` (muted): "Generating fix flows..."
- `FixFlowRow` list is hidden
- All action buttons are hidden (`primary_action` is null in this state)

---

### State: completed (polling stops)

**Left panel:**

| Component | DS Reference | Notes |
|-----------|-------------|-------|
| "Likely Root Cause" | `AppText.titleMedium` (white, bold) | panel heading |
| Root cause text | `AppText.bodyMedium` (muted) | from AI |
| "Confidence" | `AppText.titleMedium` (white, bold) | |
| Confidence % | `AppText.displayMedium` (white, bold) | e.g., "87%" |
| "Similar Incidents" | `AppText.bodySmall` (muted label) | |
| `SimilarIncidentItem` list | custom widget | see below |

**SimilarIncidentItem:**
- Background: `AppColors.bgCard`; rounded 8px
- Text: `"{ID} · {match}% match · View Details"`
- "View Details" tappable → opens `IncidentDetailDialog` modal

**Right panel:**

| Component | DS Reference | Notes |
|-----------|-------------|-------|
| "Recommended Fix Flow" | `AppText.headlineMedium` (white, bold) | |
| Subtitle | `AppText.bodySmall` (muted) | "Selecting a fix flow will attach it..." |
| `FixFlowRow` list | custom widget | see below |
| `primary_action` button | `PrimaryButton` | rendered from descriptor; see Rendering Rules |
| `secondary_actions` buttons | `GhostButton` list | rendered below primary; see Rendering Rules |

**FixFlowRow:**
- Background: `AppColors.bgCard`; border-radius 8px; full width
- Left: numbered title, `AppText.bodyMedium`
- Right-top: confidence % — green (`AppColors.severityMinor`) if ≥90%, amber if 70–89%, red if <70%
- Right-bottom: "Attempted" checkbox icon (blue filled = attempted, outlined = not)
- Below title: "Progress: X / Y completed" in `AppText.bodySmall` (muted)
- Entire row tappable → selects this fix flow → PATCH incident + navigate to Workspace

---

### State: failed (polling stops)

**Left panel:**
- `AppText.labelMedium` (muted): "Analysis failed"
- `AppText.bodyMedium`: contents of `incidents.analysis_error`
- Root cause and similar incident sections are hidden

**Right panel:**
- `AppText.bodyMedium` (muted): "Analysis failed. Use the button below to retry."
- `FixFlowRow` list is hidden
- `primary_action` button rendered (will be "Root Cause Analysis" retry)

---

### Rendering Rules

#### primary_action

| `analysis_status` | `primary_action` value | Button behavior |
|---|---|---|
| `pending` or `processing` | null | Hidden — no button rendered |
| `completed` | descriptor | Render `PrimaryButton` with `primary_action.label` |
| `failed` | descriptor | Render `PrimaryButton` with `primary_action.label` (= "Root Cause Analysis") |

When rendered:
- Button label: `primary_action.label`
- On tap: `POST {primary_action.endpoint}` with body = `primary_action.payload`
- On 202 response: resume polling (status returns to `pending`)
- On 409 response: show toast "Analysis already in progress"
- On 422 response: show error message

Frontend must use `primary_action.endpoint` and `primary_action.payload` directly. Do not hardcode action types or endpoints client-side.

#### secondary_actions

- Rendered as `GhostButton` list below the primary button, one per entry
- Hidden if `secondary_actions` is empty or `analysis_status` is `pending`/`processing`

#### FixFlow visibility

| `analysis_status` | FixFlow list |
|---|---|
| `pending` or `processing` | Hidden |
| `completed` | Rendered |
| `failed` | Hidden |

#### FixFlow generation grouping

- If `max(generation) == 1`: render as flat list, no section headers
- If `max(generation) > 1`:
  - Generation 1: section header "Initial Analysis"
  - Generation N (N > 1): section header "Improved Analysis (Attempt N–1)"

---

## Screen 7: Incident Detail / Workspace

**PNG:** `incident_detail.png`  
**Route:** `/incidents/:id/workspace`

### Layout

- Full viewport, `AppColors.bgPrimary`
- Two-panel: Left 28% | Right 72%

### Left Panel

| Component | DS Reference | Notes |
|-----------|-------------|-------|
| Incident ID · Title | `AppText.headlineMedium` (white, bold) | e.g., "INC-2026-041 · DB Connection Pool Exhausted" |
| Severity badge | `SeverityBadge` (large variant) | e.g., "CRITICAL" |
| "Timeline" heading | `AppText.titleMedium` (white, bold) | inner panel |
| Timeline events | `TimelineItem` list | timestamp + event text |

**TimelineItem:**
- `AppText.bodySmall`: `"HH:MM — event description"`
- No icons; plain text list, chronological order

### Right Panel

| Component | DS Reference | Notes |
|-----------|-------------|-------|
| "Resolution Checklist" | `AppText.titleLarge` (white, bold) | |
| "Selected Fix Flow: {name}" | `AppText.bodySmall` (muted) | |
| `ChecklistItem` list | custom widget | see below |
| "Back to Analysis" | `GhostButton` (text only) | left-aligned |
| "Mark as Resolved" | `PrimaryButton` (blue) | right-aligned |
| "Notes" heading | `AppText.titleMedium` (white, bold) | below checklist section |
| Notes textarea | `SentinelTextArea` | placeholder: "Document findings and actions..." |

**ChecklistItem:**
- Full-width row, `AppColors.bgCard`, border-radius 8px
- Left: "Step X of Y · {checkbox icon} {step description}"
- Checkbox: checkmark emoji or custom `CheckboxIcon` widget
- Toggle on tap → PATCH checklist item + update local state
- Completed = darker overlay tint on row

### Interactions

- Checklist toggle → immediate DB write + local state update
- Notes → debounced 1s auto-save to DB
- "Back to Analysis" → navigate to `/incidents/:id/analysis` (state already saved)
- "Mark as Resolved" → no confirmation in MVP → PATCH resolve → navigate to `/dashboard`

### States

| State | Behavior |
|-------|---------|
| `loading` | Skeleton placeholders in both panels |
| `ready` | All content rendered |

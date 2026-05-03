# 04 — Screen Specification

**Refs:** → [User Flow](./03_user_flow.md) · [Frontend Architecture](../frontend/10_frontend_arch.md)  
**Design refs:** `/sentinel_screen_ref/*.png`

---

## Screen 1: Login
**PNG:** `login.png`  
**Route:** `/login`

### Layout
- Full viewport, background: `AppColors.bgPrimary` (#1B2733)
- Single centered card: width 400px, padding 40px, bg `AppColors.bgCard`, border-radius 16px

### Components
| Component | DS Reference | Notes |
|-----------|-------------|-------|
| App title "Sentinel" | `AppText.displayLarge` (white, bold) | Top of card |
| Subtitle "AI Error Resolution Copilot" | `AppText.bodyMedium` (muted) | Below title |
| Email label + input | `SentinelInput` | placeholder: "you@company.com", type: email |
| Password label + input | `SentinelInput` | placeholder: "••••••••", obscured |
| Continue button | `PrimaryButton` (full width) | triggers login |
| "don't you have any account? sign up" | `AppText.bodySmall` (muted) + `TextLink` (blue) | navigates to /signup |
| Error message | `ErrorText` | inline below Continue button |

### Interactions
- "Continue" validates non-empty fields, calls `AuthService.signIn(email, password)`
- On success → navigate to `/dashboard`, replace stack
- On error → display `ErrorText` with Supabase error message
- "sign up" link → navigate to `/signup`

### States
- `idle` — default form state
- `loading` — Continue button shows `CircularProgressIndicator`, form disabled
- `error` — `ErrorText` visible below button

---

## Screen 2: Sign Up
**PNG:** `sign_up.png`  
**Route:** `/signup`

### Layout
- Same full viewport + centered card as Login

### Components
| Component | DS Reference | Notes |
|-----------|-------------|-------|
| Title "Sentinel - SignUp" | `AppText.displayLarge` (white, bold) | |
| Subtitle "AI Error Resolution Copilot" | `AppText.bodyMedium` (muted) | |
| Password label + input | `SentinelInput` | obscured |
| Validation Code label + input | `SentinelInput` | placeholder: "enter received code" |
| Email label + input | `SentinelInput` | placeholder: "you@company.com" |
| Continue button | `PrimaryButton` (full width) | |
| Error message | `ErrorText` | |

### Interactions
- "Continue" validates all fields → calls `AuthService.signUp(email, password, code)`
- On success → navigate to `/dashboard`, replace stack
- Design deviation: see [User Flow §Sign-Up Note](./03_user_flow.md)

---

## Screen 3: Dashboard — Status View
**PNG:** `dashboard_1.png`  
**Route:** `/dashboard`

### Layout
- Full viewport, `AppColors.bgPrimary` background
- Header row: "Sentinel" title + subtitle (left), Archive button + Register button + UTC clock (right)
- Toggle row: `SegmentedToggle` with "Status View" | "Severity View"
- 3-column grid (`Row` with `Expanded` children): Open | In Progress | Resolved
- Each column: colored column header label + scrollable list of `IncidentCard`

### Header Components
| Component | DS Reference | Notes |
|-----------|-------------|-------|
| "Sentinel" | `AppText.headlineLarge` (white, bold) | |
| "Incident Command Center" | `AppText.bodyMedium` (muted) | |
| Archive button | `SecondaryButton` | dark bg, white text |
| "+ Register Incident" button | `PrimaryButton` | blue |
| UTC clock | `AppText.bodyMedium` (muted) | updates every 60s |
| SegmentedToggle | `SentinelToggle` | |

### Column Headers (Status View)
| Column | Color |
|--------|-------|
| Open | `AppColors.statusOpen` (#3B8BEB, blue) |
| In Progress | `AppColors.statusInProgress` (#F59E0B, amber) |
| Resolved | `AppColors.statusResolved` (#22C55E, green) |

### IncidentCard (Status View)
- Background: `AppColors.bgCard`; border-radius: 12px
- Left border accent: 3px solid, color matches severity (Critical=red, Major=amber, Minor=green)
- Incident ID: `AppText.labelSmall` (muted), top-left
- Title: `AppText.titleMedium` (white, bold)
- Description: `AppText.bodySmall` (muted), 2-line max
- Severity badge: `SeverityBadge` component, bottom-left
- Full card is tappable → navigates to `/incidents/:id/workspace`

---

## Screen 4: Dashboard — Severity View
**PNG:** `dashboard_2.png`  
**Route:** `/dashboard` (same route, toggle state)

### Differences from Status View
- Subtitle changes to "Incident Prioritization by Severity"
- Column headers: Critical (red) | Major (amber) | Minor (green)
- `IncidentCard` shows **status badge** (`StatusBadge`) instead of severity badge
- Status badge colors: Open=blue outlined, In Progress=amber outlined, Resolved=green outlined

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
- `idle` — empty form
- `analyzing_metadata` — spinner in metadata section while AI fills fields
- `metadata_ready` — fields populated, editable
- `submitting` — "Analyze Incident" button loading
- `error` — error banner at top of right panel

---

## Screen 6: AI Analysis & Resolution
**PNG:** `resolution.png`  
**Route:** `/incidents/:id/analysis`

### Layout
- Full viewport, `AppColors.bgPrimary`
- Two-panel: Left 28% | Right 72%

### Left Panel
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
- "View Details" is tappable → opens `IncidentDetailDialog` modal

### Right Panel
| Component | DS Reference | Notes |
|-----------|-------------|-------|
| "Recommended Fix Flow" | `AppText.headlineMedium` (white, bold) | |
| Subtitle | `AppText.bodySmall` (muted) | "Selecting a fix flow will attach it..." |
| `FixFlowRow` list | custom widget | see below |

**FixFlowRow:**
- Background: `AppColors.bgCard`; border-radius 8px; full width
- Left: numbered title (e.g., "1. Identify top connection consumers"), `AppText.bodyMedium`
- Right-top: confidence % in `AppColors.severityMinor` (green) if ≥90%, amber if 70–89%, red if <70%
- Right-bottom: "Attempted" checkbox icon (blue filled = attempted, outlined = not)
- Below title: "Progress: X / Y completed" in `AppText.bodySmall` (muted)
- Entire row tappable → selects this fix flow → PATCH incident + navigate to Workspace

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
- "Mark as Resolved" → confirmation not needed in MVP → PATCH resolve → navigate to `/dashboard`

---

## Screen 8: Closed Incidents Archive
**PNG:** `closed_incident_archive.png`  
**Route:** `/archive`

### Layout
- Full viewport, `AppColors.bgPrimary`
- "Resolved Incident History" heading: `AppText.headlineLarge` (white, bold)
- `ArchiveTable` component: full-width, no outer borders

### Table Columns
| Column | Width | Component |
|--------|-------|-----------|
| Incident ID | 160px | `AppText.bodyMedium` (muted) |
| Incident (Name) | flex | `AppText.bodyMedium` (white) |
| Severity | 120px | `AppText.bodyMedium` (muted, plain text) |
| Resolution Time | 140px | `AppText.bodyMedium` (muted) e.g., "23 min" |
| Status | 120px | `StatusBadge` ("closed", outlined) |

### Interactions
- Row hover: subtle background highlight (`AppColors.bgHover`)
- Row click → opens `IncidentDetailDialog` modal
- Header row: non-interactive, `AppText.labelSmall` (muted), separator line below

---

## Screen 9: Incident Detail Dialog
**PNG:** `incident_detail_dialog.png`  
**Trigger:** Click row in Archive OR "View Details" in Similar Incidents

### Layout
- Modal overlay: dark scrim, centered dialog ~70% viewport width, ~60% height
- Header row: `{incident_code} — {incident_name}` (bold, white) | Status badge (right) | Severity badge (right)
- Two-panel body: Left 40% (Timeline) | Right 60% (Summary + Memo)
- Close: click scrim or ESC key

### Left Panel
- "Timeline" heading: `AppText.titleMedium` (white, bold)
- `TimelineItem` list (same component as Workspace screen)

### Right Panel
| Component | DS Reference | Notes |
|-----------|-------------|-------|
| "Incident Summary" | `AppText.titleMedium` (white, bold) | |
| Root cause | `AppText.bodySmall` (muted label) + `AppText.bodyMedium` (value) | |
| Impact | same pattern | |
| Fix flow | same pattern | |
| "Memo" label | `AppText.labelMedium` (muted) | |
| Memo content | `AppText.bodyMedium` | read-only in dialog |

### States
- `loading` — spinner while fetching incident detail
- `ready` — all fields populated
- Dialog is **read-only** (no editing in this context)

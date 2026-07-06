# 04.4 — Archive Screens

**Screens:** Closed Incidents Archive · Incident Detail Dialog  
**Refs:** → [Screen Index](./04_screen_spec.md) · [User Flow](./03_user_flow.md) · [API Spec §GET /archive](../backend/05_api_spec.md) · [Responsive: Archive](../frontend/10_5_responsive_archive.md)  
**Design refs:** `closed_incident_archive.png` · `incident_detail_dialog.png`

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

### States

| State | Behavior |
|-------|---------|
| `loading` | Table shows skeleton rows |
| `empty` | "No closed incidents yet" placeholder |
| `ready` | Full table rendered |

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

| State | Behavior |
|-------|---------|
| `loading` | Spinner while fetching incident detail |
| `ready` | All fields populated |

Dialog is **read-only** — no editing in this context.

# 04.2 — Dashboard Screen

**Screens:** Dashboard — Status View · Dashboard — Severity View  
**Refs:** → [Screen Index](./04_screen_spec.md) · [User Flow](./03_user_flow.md) · [API Spec §GET /incidents](../backend/05_api_spec.md) · [Responsive: Dashboard](../frontend/10_3_responsive_dashboard.md)  
**Design refs:** `dashboard_1.png` · `dashboard_2.png`

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

| Column | Color token |
|--------|-------------|
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

### States

| State | Behavior |
|-------|---------|
| `loading` | Columns show skeleton placeholders |
| `empty` | Each column shows "No incidents" placeholder text |
| `ready` | Incident cards rendered per column |
| `error` | Error banner above columns |

---

## Screen 4: Dashboard — Severity View

**PNG:** `dashboard_2.png`  
**Route:** `/dashboard` (same route, toggle state)

### Differences from Status View

- Subtitle changes to "Incident Prioritization by Severity"
- Column headers: Critical (red) | Major (amber) | Minor (green)
- `IncidentCard` shows **status badge** (`StatusBadge`) instead of severity badge
- Status badge colors: Open=blue outlined, In Progress=amber outlined, Resolved=green outlined

All other layout, header, and interaction rules are identical to Status View.

# 04 — Screen Specification Index

**Purpose:** Navigation index for all screen specifications. Each screen group has its own document. Do not add screen content directly to this file.

**Refs:** → [User Flow](./03_user_flow.md) · [Frontend Architecture](../frontend/10_frontend_arch.md) · [API Spec](../backend/05_api_spec.md)  
**Design refs:** `/sentinel_screen_ref/*.png`

---

## Screen Documents

| Document | Screens | Routes |
|----------|---------|--------|
| [04.1 — Auth Screens](./04_1_auth_screens.md) | Login · Sign Up | `/login` · `/signup` |
| [04.2 — Dashboard Screen](./04_2_dashboard_screen.md) | Dashboard Status View · Dashboard Severity View | `/dashboard` |
| [04.3 — Incident Flow Screens](./04_3_incident_flow_screens.md) | Incident Registration · AI Analysis & Resolution · Incident Detail / Workspace | `/incidents/new` · `/incidents/:id/analysis` · `/incidents/:id/workspace` |
| [04.4 — Archive Screens](./04_4_archive_screens.md) | Closed Incidents Archive · Incident Detail Dialog | `/archive` · (modal) |

---

## Sub-Specifications

| Document | Extends |
|----------|---------|
| [04.1 — OCR Log Extraction](./04_1_ocr_log_extraction.md) | Screen 5 — Incident Registration; OCR-assisted image input sub-flow |

---

## Design Reference Map

| Screen | PNG file | Document |
|--------|----------|---------|
| Login | `login.png` | [04.1](./04_1_auth_screens.md) |
| Sign Up | `sign_up.png` | [04.1](./04_1_auth_screens.md) |
| Dashboard — Status View | `dashboard_1.png` | [04.2](./04_2_dashboard_screen.md) |
| Dashboard — Severity View | `dashboard_2.png` | [04.2](./04_2_dashboard_screen.md) |
| Incident Registration | `incident_registration.png` | [04.3](./04_3_incident_flow_screens.md) |
| AI Analysis & Resolution | `resolution.png` | [04.3](./04_3_incident_flow_screens.md) |
| Incident Detail / Workspace | `incident_detail.png` | [04.3](./04_3_incident_flow_screens.md) |
| Closed Incidents Archive | `closed_incident_archive.png` | [04.4](./04_4_archive_screens.md) |
| Incident Detail Dialog | `incident_detail_dialog.png` | [04.4](./04_4_archive_screens.md) |

---

## Conventions

- All DS component references are resolved in [Frontend Architecture](../frontend/10_frontend_arch.md)
- All API calls shown in screen docs reference the contracts in [API Spec](../backend/05_api_spec.md)
- State machine behavior (analysis_status, incident status) is defined in [State Machines](../domain/state_machines.md)
- Responsive behavior for each screen group is in the corresponding `10_x_responsive_*.md` document

# Sentinel SDD — Master Index

**Project:** Sentinel — AI Error Resolution Copilot  
**Stack:** Flutter · FastAPI · PostgreSQL · Supabase Auth · GCP · Gemini API

---

## Workflow (Start Here)

| Document | Purpose |
|----------|---------|
| [Implementation Lifecycle](./workflow/00_implementation_lifecycle.md) | 8-phase lifecycle — phases every task must follow |
| [Context Loading Guide](./workflow/01_context_loading.md) | Which docs to load per task type (loading matrix) |
| [Decision Flow](./workflow/02_decision_flow.md) | Step-by-step sequences for common decisions |
| [Validation Spec](./workflow/03_validation.md) | Checklists per task type + smoke test sequence |

---

## Analysis Workflow

Cross-layer specifications that span Frontend, Backend, and QA. These documents are authoritative for the full workflow and must be referenced — not duplicated — by layer-specific implementation documents.

| Document | Purpose |
|----------|---------|
| [SPEC-ANALYSIS-001](./analysis/SPEC-ANALYSIS-001.md) | Project-level authoritative spec for `/incidents/{id}/analysis`: state machine, event model, adaptive polling, backend API contract, UX rendering, edge cases |

---

## Domain

| Document | Purpose |
|----------|---------|
| [State Machines](./domain/state_machines.md) | Incident, AIAction, AnalysisStatus, FixFlow, Timeline lifecycles |

---

## Architecture Decisions

Records *why* — not duplicated in specs, which record *what*. See [ADR Index](./architecture/decisions/000_index.md) for the lifecycle and the trigger rule for when a new ADR is required.

| Document | Purpose |
|----------|---------|
| [ADR Index](./architecture/decisions/000_index.md) | Full list of ADRs with status |
| [ADR Template](./architecture/decisions/ADR-0000-template.md) | Format for new ADRs |

---

## Authentication

Authentication is a system capability that spans backend, frontend, and infrastructure. `sdd/auth/` is the single source of truth. Any code or spec that interacts with identity, tokens, or session state must reference this area.

| Document | Purpose |
|----------|---------|
| [Overview](./auth/00_overview.md) | Mechanisms, security principles, environment model, document map |
| [Contract](./auth/01_contract.md) | Token format, required claims, AuthRepository interface, supported environment combinations |
| [Production Auth](./auth/02_production.md) | Supabase sign-up/in flows, ES256/JWKS verification, session lifecycle, ownership enforcement |
| [Development Auth](./auth/03_development.md) | Validator dispatch, dev token endpoint, production guards, frontend cleanup, mock credentials |

---

## Rules

| Document | Purpose |
|----------|---------|
| [Spec Authoring Rules](./rules/spec_authoring_rules.md) | Size limits, writing style, split rules |
| [Ownership Map](./rules/ownership.md) | Which files each area owns; cross-boundary rules |

---

## Context (Product / Design)

| # | Document | Purpose |
|---|----------|---------|
| 01 | [Requirements](./context/01_requirements.md) | Functional & non-functional requirements |
| 02 | [Product Spec](./context/02_product_spec.md) | MVP scope, feature list, priorities |
| 03 | [User Flow](./context/03_user_flow.md) | Navigation paths, state transitions |
| 04 | [Screen Spec Index](./context/04_screen_spec.md) | Navigation index for all screen documents |
| 04.1 | [Auth Screens](./context/04_1_auth_screens.md) | Login · Sign Up |
| 04.2 | [Dashboard Screen](./context/04_2_dashboard_screen.md) | Dashboard Status View · Severity View |
| 04.3 | [Incident Flow Screens](./context/04_3_incident_flow_screens.md) | Registration · AI Analysis (AI Platform lifecycle) · Workspace |
| 04.4 | [Archive Screens](./context/04_4_archive_screens.md) | Closed Incidents Archive · Detail Dialog |
| 04.1† | [OCR Log Extraction](./context/04_1_ocr_log_extraction.md) | OCR-assisted raw log extraction sub-flow spec |

---

## Backend

| # | Document | Purpose |
|---|----------|---------|
| 05 | [API Spec](./backend/05_api_spec.md) | All REST endpoints with request/response shapes |
| 05.1 | [OCR API Spec](./backend/05_1_ocr_api_spec.md) | `POST /ocr/extract-log` endpoint contract |
| 06 | [Database Schema](./backend/06_database_schema.md) | PostgreSQL tables, constraints, indexes |
| 07 | [Auth Spec](./backend/07_auth_spec.md) | **Stub** — redirects to `sdd/auth/` (the canonical location) |
| 08 | [AI Integration Spec](./backend/08_ai_integration_spec.md) | Handler registry, T1/T2 pattern, prompts |
| 08.1 | [OCR AI Integration](./backend/08_1_ocr_ai_integration.md) | Gemini OCR extraction + log cleanup |
| 09 | [Backend Architecture](./backend/09_backend_arch.md) | FastAPI structure, services, layering rules |

---

## Frontend

| # | Document | Purpose |
|---|----------|---------|
| 10 | [Frontend Architecture](./frontend/10_frontend_arch.md) | Flutter structure, Design System, routing |
| 10.1 | [Folder Structure](./frontend/10_1_folder_structure.md) | Flutter `lib/` directory layout |
| 10.2 | [Responsive Strategy](./frontend/10_2_responsive_strategy.md) | Breakpoints, global responsive decisions |
| 10.3 | [Responsive: Dashboard](./frontend/10_3_responsive_dashboard.md) | Dashboard responsive rules |
| 10.4 | [Responsive: Incident Flow](./frontend/10_4_responsive_incident_flow.md) | Registration/Analysis/Workspace collapse |
| 10.5 | [Responsive: Archive](./frontend/10_5_responsive_archive.md) | Archive table → card list |
| 10.6 | [Responsive: Auth & Dialogs](./frontend/10_6_responsive_auth_dialogs.md) | Login/Signup card, Detail Dialog |
| 10.7 | [Responsive: Mobile IA](./frontend/10_7_responsive_mobile_ia.md) | Mobile navigation/IA |
| 10.8 | [Analysis Route (reference)](./frontend/10_8_analysis_route_polling.md) | Stub — authoritative spec relocated to `sdd/analysis/SPEC-ANALYSIS-001.md` |

---

## Infrastructure

| # | Document | Purpose |
|---|----------|---------|
| 11 | [Deployment Spec](./infra/11_deployment_spec.md) | GCP services, CI/CD, environment config |
| 12 | [Testing Spec](./infra/12_testing_spec.md) | Unit, widget, integration, API test plan |

---

## Release

Lives outside `sdd/` deliberately — records what was actually deployed, not what the system is designed to be. Specs remain unaware of it; see [`release/000_index.md`](../release/000_index.md).

| Document | Purpose |
|----------|---------|
| [Release Index](../release/000_index.md) | Currently released versions, rules, structure |

---

## Design References

All screen PNGs are in `/sentinel_screen_ref/`.

| Screen | PNG File |
|--------|----------|
| Login | `login.png` |
| Sign Up | `sign_up.png` |
| Dashboard — Status View | `dashboard_1.png` |
| Dashboard — Severity View | `dashboard_2.png` |
| Incident Registration | `incident_registration.png` |
| AI Analysis & Resolution | `resolution.png` |
| Incident Detail / Workspace | `incident_detail.png` |
| Closed Incidents Archive | `closed_incident_archive.png` |
| Incident Detail Dialog | `incident_detail_dialog.png` |

---

## Archive

| Document | Notes |
|----------|-------|
| [13_agent_instructions.md](./13_agent_instructions.md) | Superseded by `workflow/` + `rules/ownership.md` |
| [spec_compliance_report.md](./spec_compliance_report.md) | Compliance audit — resolved |

---

## Key Conventions

- Incident ID format: `INC-YYYY-NNN` (e.g., `INC-2026-041`)
- Severity levels: `critical` | `major` | `minor` (lowercase in DB, display-cased in UI)
- Incident status: `open` | `in_progress` | `resolved` | `closed`
- All API routes prefixed with `/api/v1`
- All timestamps in UTC ISO-8601
- JWT passed as `Authorization: Bearer <token>` header

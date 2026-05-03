# Sentinel SDD — Master Index

**Project:** Sentinel — AI Error Resolution Copilot  
**Version:** 1.0.0-MVP  
**Date:** 2026-04-29  
**Stack:** Flutter · FastAPI · PostgreSQL · Supabase Auth · GCP · Gemini API

---

## Document Map

| # | Document | Purpose | Lines |
|---|----------|---------|-------|
| 01 | [Requirements](./context/01_requirements.md) | Functional & non-functional requirements | ≤150 |
| 02 | [Product Spec](./context/02_product_spec.md) | MVP scope, feature list, priorities | ≤150 |
| 03 | [User Flow](./context/03_user_flow.md) | Navigation paths, state transitions | ≤150 |
| 04 | [Screen Spec](./context/04_screen_spec.md) | All 9 screens mapped to PNG refs | ≤300 |
| 05 | [API Spec](./backend/05_api_spec.md) | All REST endpoints with request/response | ≤300 |
| 06 | [Database Schema](./backend/06_database_schema.md) | PostgreSQL tables, constraints, indexes | ≤300 |
| 07 | [Auth Spec](./backend/07_auth_spec.md) | Supabase Auth flow, JWT validation | ≤150 |
| 08 | [AI Integration Spec](./backend/08_ai_integration_spec.md) | Gemini API prompts, parsing, flows | ≤150 |
| 09 | [Backend Architecture](./backend/09_backend_arch.md) | FastAPI structure, services, middleware | ≤150 |
| 10 | [Frontend Architecture](./frontend/10_frontend_arch.md) | Flutter structure, Design System, routing | ≤300 |
| 11 | [Deployment Spec](./infra/11_deployment_spec.md) | GCP services, CI/CD, environment config | ≤150 |
| 12 | [Testing Spec](./infra/12_testing_spec.md) | Unit, widget, integration, API tests | ≤150 |
| 13 | [Agent Instructions](./13_agent_instructions.md) | Agent roles, boundaries, collaboration | ≤300 |

---

## Design References

All screen PNGs are in `/sentinel_screen_ref/`. Every screen spec maps directly to a PNG.

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

## Cross-Document Dependency

```
01_requirements
    └──> 02_product_spec
             └──> 03_user_flow
                      └──> 04_screen_spec ──> 10_frontend_arch
                      └──> 05_api_spec    ──> 09_backend_arch
                      └──> 06_database_schema
                      └──> 07_auth_spec
                      └──> 08_ai_integration_spec
                               └──> 09_backend_arch
11_deployment_spec (reads all)
12_testing_spec    (reads all)
13_agent_instructions (reads all)
```

---

## Key Conventions

- Incident ID format: `INC-YYYY-NNN` (e.g., `INC-2026-041`)
- Severity levels: `critical` | `major` | `minor` (lowercase in DB, display-cased in UI)
- Incident status: `open` | `in_progress` | `resolved` | `closed`
- All API routes prefixed with `/api/v1`
- All timestamps in UTC ISO-8601
- JWT passed as `Authorization: Bearer <token>` header

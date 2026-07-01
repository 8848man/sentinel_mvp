# Context Loading Guide

**Purpose:** Minimize context loading by specifying exactly which documents to load for each task type. Load only what is listed — extra context degrades focus without improving output.

**Refs:** → [Implementation Lifecycle](./00_implementation_lifecycle.md)

---

## Loading Categories

| Symbol | Meaning |
|---|---|
| ✅ Always | Load before starting this task type |
| 🔶 If relevant | Load only if the task directly touches this area |
| ⬜ Skip | Do not load for this task type |

---

## Backend Endpoint Change

| Document | Load? |
|---|---|
| CLAUDE.md | ✅ Always |
| `backend/app/routers/incidents.py` (or relevant router) | ✅ Always |
| `backend/app/services/incident_service.py` | ✅ Always |
| `sdd/backend/05_api_spec.md` | ✅ Always |
| `backend/app/models/models.py` | 🔶 If touching schema |
| `sdd/backend/06_database_schema.md` | 🔶 If touching schema |
| `sdd/backend/09_backend_arch.md` | 🔶 If new service or new layering pattern |
| `sdd/backend/07_auth_spec.md` | 🔶 If touching auth.py only |
| `sdd/backend/08_ai_integration_spec.md` | ⬜ Skip |
| Frontend files | ⬜ Skip |
| `sdd/infra/` | ⬜ Skip |

---

## Database Schema Change

| Document | Load? |
|---|---|
| CLAUDE.md | ✅ Always |
| `backend/app/models/models.py` | ✅ Always |
| `sdd/backend/06_database_schema.md` | ✅ Always |
| `backend/alembic/versions/` (latest migration) | ✅ Always |
| `sdd/backend/05_api_spec.md` | 🔶 If change affects API response shape |
| `sdd/backend/09_backend_arch.md` | ⬜ Skip |
| Frontend files | ⬜ Skip |
| `sdd/infra/` | ⬜ Skip |

---

## AI Platform — New Handler

| Document | Load? |
|---|---|
| CLAUDE.md | ✅ Always |
| `backend/app/ai_platform/handlers/base.py` | ✅ Always |
| `backend/app/ai_platform/context/types.py` | ✅ Always |
| An existing handler as reference (e.g. `root_cause_analysis.py`) | ✅ Always |
| `backend/app/ai_platform/registry.py` | ✅ Always |
| `backend/app/services/gemini_service.py` | ✅ Always |
| `sdd/backend/08_ai_integration_spec.md` | ✅ Always |
| `backend/app/ai_platform/executor.py` | 🔶 If modifying execution flow |
| `sdd/backend/05_api_spec.md` | 🔶 If new action needs a new endpoint |
| `sdd/domain/state_machines.md` | 🔶 If handler fires on a lifecycle event |
| Frontend files | ⬜ Skip |

---

## AI Platform — Modify Existing Handler

| Document | Load? |
|---|---|
| CLAUDE.md | ✅ Always |
| The specific handler file | ✅ Always |
| `backend/app/ai_platform/context/types.py` | ✅ Always |
| `backend/app/services/gemini_service.py` | ✅ Always |
| `backend/app/ai_platform/executor.py` | 🔶 If touching T1/T2 logic |
| `sdd/backend/08_ai_integration_spec.md` | 🔶 If prompt or output schema changes |
| Other handler files | ⬜ Skip |

---

## Flutter Screen Implementation

| Document | Load? |
|---|---|
| CLAUDE.md | ✅ Always |
| `sentinel_screen_ref/<screen>.png` | ✅ Always |
| Affected entity → model → datasource → provider → screen (chain) | ✅ Always |
| `sdd/backend/05_api_spec.md` | ✅ Always |
| `sdd/context/04_screen_spec.md` | ✅ Always |
| `sdd/context/03_user_flow.md` | 🔶 If navigation or routing changes |
| `sdd/frontend/10_frontend_arch.md` | 🔶 If adding a new feature module |
| `sdd/frontend/10_1_folder_structure.md` | 🔶 If adding new files |
| `sdd/frontend/10_2..10_7` (responsive sub-docs) | 🔶 If implementing responsive behavior |
| `sdd/domain/state_machines.md` | 🔶 If rendering incident or AI action state |
| Backend implementation files | ⬜ Skip |

---

## Flutter Entity / Model Update

This is the most common missed task. Run it whenever a backend response field changes.

| Document | Load? |
|---|---|
| CLAUDE.md | ✅ Always |
| `sdd/backend/05_api_spec.md` | ✅ Always |
| Affected entity (`domain/entities/*.dart`) | ✅ Always |
| Affected model (`data/models/*_model.dart`) | ✅ Always |
| Affected datasource (`data/datasources/incident_api_datasource.dart`) | ✅ Always |
| Affected provider (`presentation/*/providers/*.dart`) | 🔶 If provider exposes new field |
| Affected screen (`presentation/*/screens/*.dart`) | 🔶 If screen must render new field |
| Backend implementation files | ⬜ Skip |

---

## State Transition Change

| Document | Load? |
|---|---|
| CLAUDE.md | ✅ Always |
| `sdd/domain/state_machines.md` | ✅ Always |
| `backend/app/services/incident_service.py` | ✅ Always |
| `sdd/backend/05_api_spec.md` | ✅ Always |
| `backend/app/models/models.py` | 🔶 If status field changes |
| Flutter entity + provider for incident | 🔶 If frontend reacts to the transition |
| `sdd/context/03_user_flow.md` | 🔶 If user-visible navigation changes |

---

## Auth Change — Backend (validator, token endpoint, guard)

| Document | Load? |
|---|---|
| CLAUDE.md | ✅ Always |
| `sdd/auth/00_overview.md` | ✅ Always |
| `sdd/auth/03_development.md` | ✅ Always |
| `backend/app/core/auth.py` | ✅ Always |
| `backend/app/core/config.py` | 🔶 If adding/changing env vars |
| `backend/app/routers/auth.py` | 🔶 If touching auth endpoints |
| `sdd/auth/02_production.md` | 🔶 If production auth flow changes |
| All other documents | ⬜ Skip |

## Auth Change — Frontend (AuthRepository, provider, token acquisition)

| Document | Load? |
|---|---|
| CLAUDE.md | ✅ Always |
| `sdd/auth/00_overview.md` | ✅ Always |
| `sdd/auth/01_contract.md` | ✅ Always |
| `frontend/sentinel/lib/features/auth/domain/repositories/auth_repository.dart` | ✅ Always |
| `frontend/sentinel/lib/core/api/api_client.dart` | 🔶 If JWT interceptor changes |
| `frontend/sentinel/lib/core/config/app_config.dart` | 🔶 If provider mode changes |
| `sdd/auth/03_development.md` | 🔶 If mock credentials or dev workflow changes |
| All other documents | ⬜ Skip |

---

## Deployment / Infrastructure Change

| Document | Load? |
|---|---|
| CLAUDE.md | ✅ Always |
| `sdd/infra/11_deployment_spec.md` | ✅ Always |
| `backend/Dockerfile` | 🔶 If container changes |
| `backend/app/core/config.py` | 🔶 If env var changes |
| All other documents | ⬜ Skip |

---

## Spec / Documentation Update

| Document | Load? |
|---|---|
| CLAUDE.md | ✅ Always |
| `sdd/rules/spec_authoring_rules.md` | ✅ Always |
| The spec being updated | ✅ Always |
| Related specs that cross-reference this one | 🔶 If updating cross-referenced content |
| `sdd/00_index.md` | 🔶 If adding a new spec file |
| Implementation source files | 🔶 To verify what the spec should say |

---

## General Loading Rules

1. **Load the code before the spec.** The spec describes intent; the code describes reality.
2. **Load the entity before the screen.** A Flutter screen built on a stale entity silently breaks.
3. **Never load `01_requirements.md` or `02_product_spec.md` during implementation.** These are project-level documents used at design time. Load them only when evaluating scope or priorities.
4. **Never load `12_testing_spec.md` until tests are being written.** It describes a future state.
5. **Never load `13_agent_instructions.md` — it has been archived.** Use `sdd/rules/ownership.md` instead.

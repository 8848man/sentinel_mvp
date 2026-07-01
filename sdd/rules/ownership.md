# Ownership Map

**Purpose:** Defines which files each area owns. When a task spans multiple areas, coordinate rather than editing across them silently.

**Refs:** → [Implementation Lifecycle](../workflow/00_implementation_lifecycle.md) · [Decision Flow](../workflow/02_decision_flow.md)

---

## Ownership Table

| Area | Owns (may modify) | Must NOT modify |
|---|---|---|
| **Context / Product** | `sdd/context/01_requirements.md`, `02_product_spec.md`, `03_user_flow.md`, `04_screen_spec.md`, `04_1_ocr_log_extraction.md` | Any `backend/`, `frontend/`, `database/` file |
| **Database** | `backend/alembic/versions/*.py`, `sdd/backend/06_database_schema.md` | `backend/app/` source (coordinate with Backend) |
| **Backend** | `backend/app/routers/*.py`, `backend/app/models/models.py`, `backend/app/schemas/*.py`, `backend/app/services/incident_service.py`, `backend/app/core/config.py`, `backend/app/core/database.py`, `backend/app/core/auth.py`, `backend/app/main.py`, `backend/requirements.txt`, `backend/Dockerfile` | `backend/app/services/gemini_service.py` (AI area), `frontend/` |
| **AI Platform** | `backend/app/services/gemini_service.py`, `backend/app/ai_platform/**`, `backend/app/services/ai_action_service.py`, `sdd/backend/08_ai_integration_spec.md`, `sdd/backend/08_1_ocr_ai_integration.md` | `backend/app/routers/*.py`, `backend/app/services/incident_service.py` (coordinate) |
| **Frontend** | `frontend/sentinel/lib/**`, `frontend/sentinel/pubspec.yaml` | `backend/`, `database/`, `sdd/` documents |
| **QA** | `backend/tests/**`, `frontend/sentinel/test/**` | Any `backend/app/` or `frontend/lib/` source file |
| **DevOps** | `deployment/`, `backend/Dockerfile`, `firebase.json`, `.env.example` | `backend/app/` source code, `frontend/sentinel/lib/` |

---

## Cross-Boundary Rules

**Backend ↔ AI Platform:** Routers never call `gemini_service.py` or `ai_platform/` directly — always through `incident_service.py` or `ai_action_service.py`.

**Backend ↔ Database:** Adding a DB column requires both a SQLAlchemy model change (Backend) and an Alembic migration (Database). Coordinate: write migration first, then update the model.

**Frontend ↔ Backend:** Any API response shape change requires updating both the Pydantic schema (Backend) and the Flutter entity + `fromJson` (Frontend) in the same session. See [Decision Flow §1 and §4](../workflow/02_decision_flow.md).

**Context ↔ All:** New screens require Context area sign-off before Frontend implements. New endpoints require alignment with `05_api_spec.md` before Backend implements.

---

## Spec Ownership

Each spec is "owned" by the area it describes. The owning area updates it when their implementation diverges:

| Spec | Owner |
|---|---|
| `sdd/context/01-04_*.md` | Context / Product |
| `sdd/backend/05_api_spec.md` | Backend |
| `sdd/backend/06_database_schema.md` | Database |
| `sdd/backend/07_auth_spec.md` | **Stub** — canonical location is `sdd/auth/` |
| `sdd/auth/00_overview.md` | Backend + Frontend (cross-cutting; both areas must coordinate changes) |
| `sdd/auth/01_contract.md` | Backend + Frontend (cross-cutting; both areas must coordinate changes) |
| `sdd/auth/02_production.md` | Backend + DevOps |
| `sdd/auth/03_development.md` | Backend + Frontend |
| `sdd/backend/08_ai_integration_spec.md` | AI Platform |
| `sdd/backend/09_backend_arch.md` | Backend |
| `sdd/frontend/10_*.md` | Frontend |
| `sdd/domain/state_machines.md` | Backend (transitions) + Frontend (rendering) |
| `sdd/infra/11_deployment_spec.md` | DevOps |
| `sdd/infra/12_testing_spec.md` | QA |

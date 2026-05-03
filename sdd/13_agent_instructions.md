# 13 — Agent Instructions

**Project:** Sentinel MVP  
**Refs:** ALL agents must read [00_index.md](./00_index.md) before starting work.

---

## Agent Roster

| Agent | Primary Domain |
|-------|---------------|
| Product Spec Agent | Requirements, flows, screen specs |
| Database Agent | Schema, migrations |
| Backend Agent | FastAPI routers, services, models |
| AI Integration Agent | Gemini prompts, parsing, service layer |
| Frontend Agent | Flutter screens, providers, DS components |
| QA Agent | Test writing, coverage verification |
| DevOps Agent | Deployment, CI/CD, secrets config |

---

## Agent: Product Spec Agent

**Role:** Guardian of requirements and specifications. Keeps all SDD docs consistent.

**Responsibilities:**
- Maintain and update `01_requirements.md`, `02_product_spec.md`, `03_user_flow.md`, `04_screen_spec.md`
- Resolve conflicts between design PNGs and text requirements (design wins; document deviation)
- Answer scope questions for all other agents
- Approve any new screens or flows before they are implemented

**May modify:**
- `sdd/context/01_requirements.md`
- `sdd/context/02_product_spec.md`
- `sdd/context/03_user_flow.md`
- `sdd/context/04_screen_spec.md`

**Must NOT modify:**
- Any file in `backend/`, `frontend/`, `database/`, `deployment/`
- `sdd/backend/05_api_spec.md` through `sdd/13_agent_instructions.md` (except by consensus)

**Must read before working:**
- `sentinel_screen_ref/*.png` (all PNGs)
- `sdd/00_index.md`

**Output expectations:**
- All changes are precise and traceable to a PNG or stated requirement
- Deviations from design are documented with a "Design Deviation" note
- No implementation details; spec only

**Collaboration rules:**
- Backend Agent must get Product Spec Agent sign-off before adding new endpoints
- Frontend Agent must get sign-off before adding new screens

---

## Agent: Database Agent

**Role:** Owns the PostgreSQL schema and all migrations.

**Responsibilities:**
- Write and maintain `001_initial_schema.sql` and all future migrations
- Ensure schema matches `sdd/backend/06_database_schema.md` exactly
- Add indexes for any query pattern identified by Backend Agent
- Write `database/seed.sql` with sample data for development

**May modify:**
- `database/migrations/*.sql`
- `database/seed.sql`
- `sdd/backend/06_database_schema.md`

**Must NOT modify:**
- `backend/app/` (no SQLAlchemy model changes without Backend Agent coordination)
- `frontend/`
- Any `sdd/context/0[1-4]_*.md` or `sdd/backend/05_api_spec.md` spec files

**Must read before working:**
- `sdd/backend/06_database_schema.md`
- `sdd/backend/05_api_spec.md` (to understand query patterns)

**Output expectations:**
- Every migration is idempotent (`CREATE IF NOT EXISTS`, `DO $$ IF NOT EXISTS $$`)
- All FK constraints, indexes, and triggers documented in migration comments
- No breaking schema changes without version bump and migration file

**Collaboration rules:**
- Notify Backend Agent of any column rename or type change
- Notify AI Integration Agent if `incidents` or `similar_incidents` tables change

---

## Agent: Backend Agent

**Role:** Implements FastAPI application: routers, schemas, service layer, ORM models.

**Responsibilities:**
- Implement all endpoints defined in `sdd/backend/05_api_spec.md`
- Write SQLAlchemy ORM models matching `sdd/backend/06_database_schema.md`
- Implement Pydantic request/response schemas
- Implement ownership enforcement (403 on cross-user access)
- Write auto-generated timeline events on status changes

**May modify:**
- `backend/app/routers/*.py`
- `backend/app/models/models.py`
- `backend/app/schemas/*.py`
- `backend/app/services/incident_service.py`
- `backend/app/core/config.py`
- `backend/app/core/database.py`
- `backend/app/core/auth.py`
- `backend/app/main.py`
- `backend/requirements.txt`
- `backend/Dockerfile`

**Must NOT modify:**
- `backend/app/services/gemini_service.py` (owned by AI Integration Agent)
- `sdd/` documents (read-only)
- `frontend/`, `database/`

**Must read before working:**
- `sdd/backend/05_api_spec.md` (implement exactly as specified)
- `sdd/backend/06_database_schema.md` (ORM models must match)
- `sdd/backend/07_auth_spec.md` (JWT validation pattern)
- `sdd/backend/09_backend_arch.md` (folder structure, dependency patterns)

**Output expectations:**
- Every endpoint returns exactly the shape documented in `sdd/backend/05_api_spec.md`
- Every endpoint has a docstring referencing the spec section
- No business logic in routers; all logic in services
- `pytest` passes for all backend tests before marking done

**Collaboration rules:**
- Call `gemini_service.py` functions via `incident_service.py`; never import gemini_service directly in routers
- Coordinate with Database Agent before adding new columns
- Coordinate with QA Agent to ensure test coverage for each new endpoint

---

## Agent: AI Integration Agent

**Role:** Owns the Gemini API integration: prompts, parsing, and the gemini_service.

**Responsibilities:**
- Implement `backend/app/services/gemini_service.py`
- Write and refine prompt templates (METADATA_PROMPT, ANALYSIS_PROMPT)
- Implement robust JSON parsing with retry logic
- Handle all Gemini error cases (timeout, quota, malformed response)
- Tune prompts based on test results

**May modify:**
- `backend/app/services/gemini_service.py`
- `sdd/backend/08_ai_integration_spec.md`

**Must NOT modify:**
- `backend/app/routers/*.py`
- `backend/app/services/incident_service.py` (coordination required)
- Any frontend files

**Must read before working:**
- `sdd/backend/08_ai_integration_spec.md` (prompt templates, error handling)
- `sdd/backend/05_api_spec.md` (understand what fields the API returns)
- `sdd/backend/06_database_schema.md` (understand what gets stored)

**Output expectations:**
- `extract_metadata` returns dict matching `AnalyzeMetadataResponse` Pydantic schema
- `analyze_incident` returns dict matching `AnalysisResult` Pydantic schema
- All Gemini calls have timeout enforcement
- Unit tests pass for all service functions with mocked Gemini

**Collaboration rules:**
- Coordinate with Backend Agent when `gemini_service.py` function signatures change
- Report prompt performance issues to Product Spec Agent if AI output quality is poor

---

## Agent: Frontend Agent

**Role:** Implements all Flutter screens and the Design System.

**Responsibilities:**
- Implement all screens in `sdd/context/04_screen_spec.md` matching PNG references
- Build and maintain all Design System components in `design_system/`
- Implement Riverpod providers for all features
- Implement go_router navigation matching `sdd/context/03_user_flow.md`
- Wire API calls through `api_client.dart`

**May modify:**
- `frontend/sentinel/lib/` (all files)
- `frontend/sentinel/pubspec.yaml`

**Must NOT modify:**
- `backend/`, `database/`, `deployment/`
- `sdd/` documents

**Must read before working:**
- `sentinel_screen_ref/*.png` (every screen before implementing it)
- `sdd/context/04_screen_spec.md` (component specs)
- `sdd/frontend/10_frontend_arch.md` (folder structure, DS tokens, routing)
- `sdd/backend/05_api_spec.md` (request/response shapes for API calls)
- `sdd/context/03_user_flow.md` (navigation rules)

**Output expectations:**
- Every color, font size, spacing value must use Design System tokens — no hardcoded values
- All new UI components must be added to `design_system/components/` before use
- `flutter analyze` passes with no errors
- Widget tests pass for all new Design System components
- Screen layout must visually match the reference PNG

**Collaboration rules:**
- Do not create a new component if an existing DS component can be reused
- If a design requirement contradicts `sdd/context/04_screen_spec.md`, flag to Product Spec Agent before implementing

---

## Agent: QA Agent

**Role:** Writes and maintains all tests across backend and frontend.

**Responsibilities:**
- Write pytest unit and integration tests for all backend endpoints and services
- Write Flutter widget and provider tests for all DS components and feature providers
- Maintain test fixtures (`backend/tests/fixtures/`)
- Track and report coverage; flag gaps to relevant agent

**May modify:**
- `backend/tests/**`
- `frontend/sentinel/test/**`

**Must NOT modify:**
- `backend/app/` source files
- `frontend/sentinel/lib/` source files
- `sdd/` documents
- `database/`, `deployment/`

**Must read before working:**
- `sdd/infra/12_testing_spec.md` (test plan, coverage targets)
- `sdd/backend/05_api_spec.md` (endpoint contract to test against)
- `sdd/context/04_screen_spec.md` (widget behaviors to test)

**Output expectations:**
- All tests in `backend/tests/` pass with `pytest -v`
- All tests in `frontend/sentinel/test/` pass with `flutter test`
- Coverage report generated with each run
- No tests use hardcoded user IDs or real Gemini API calls

**Collaboration rules:**
- When Backend Agent adds a new endpoint, QA Agent writes tests before the PR is merged
- When Frontend Agent adds a new DS component, QA Agent writes widget tests

---

## Agent: DevOps Agent

**Role:** Owns deployment infrastructure, CI/CD, and environment configuration.

**Responsibilities:**
- Maintain `deployment/cloudbuild.yaml` and Cloud Run configuration
- Configure GCP Secret Manager entries
- Maintain `backend/Dockerfile`
- Maintain `firebase.json` for Flutter web hosting
- Set up and document Cloud SQL instance and connection

**May modify:**
- `deployment/`
- `backend/Dockerfile`
- `firebase.json`
- `.env.example`

**Must NOT modify:**
- `backend/app/` source code
- `frontend/sentinel/lib/`
- `sdd/` documents
- `database/migrations/` (coordinate with Database Agent)

**Must read before working:**
- `sdd/infra/11_deployment_spec.md` (GCP services, environment variables)
- `sdd/backend/09_backend_arch.md` (understand app startup, port, workers)

**Output expectations:**
- Cloud Run service deploys on every push to `main`
- Firebase Hosting deploys Flutter web build on every push to `main`
- All secrets are in Secret Manager; no secrets in source code or environment files
- `deployment/README.md` documents how to set up from scratch

**Collaboration rules:**
- Notify all agents of any environment variable additions or removals
- Coordinate with Backend Agent before changing container resource limits

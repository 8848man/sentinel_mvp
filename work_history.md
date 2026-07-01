## 2026-07-01

### Release — Full release workflow for session 2026-06-30 commits
- Description: Work history committed. Alembic migration b2c3d4e5f6a7 applied to PostgreSQL (a1b2c3d4e5f6 → b2c3d4e5f6a7 head). Backend restarted on port 8000 (/docs 200, /api/v1/dev/token endpoint live). Flutter frontend started on port 3000 with AUTH_PROVIDER=dev, USE_MOCK_DATA=false, API_BASE_URL=http://localhost:8000 (HTTP 200).
- Migration applied: `b2c3d4e5f6a7_ai_platform_foundation.py`
- Commit:
  - 618990d (docs: add work history log for session 2026-06-30)

---

## 2026-06-30

### 1. Feature — AI Platform schema migration and ORM model evolution
- Description: Alembic revision b2c3d4e5f6a7 renames analysis_jobs→ai_actions and adds action_type, requested_by, output, output_schema_version, model_id, parent_action_id, input_snapshot. Adds origin_type to incidents, generation to fix_flows, actor_type/event_type/ai_action_id/metadata to timeline_events. Migration is idempotent. ORM models fully updated with dialect-safe partial index (sqlite_where + postgresql_where) and TextListType JSON fallback for SQLite.
- Affected files: `backend/alembic/versions/b2c3d4e5f6a7_ai_platform_foundation.py`, `backend/app/models/models.py`
- Commit:
  - 33919b1 (feat: add AI Platform schema migration and evolve ORM models)

### 2. Feature — AI Platform core package
- Description: Plugin architecture for AI actions. context/types.py defines AnalysisContext; context/builders.py assembles context with log truncation. handlers/base.py is the AIActionHandler abstract base. handlers/root_cause_analysis.py and handlers/improved_fix_flow.py implement Gemini prompts. registry.py maps action_type slugs to handlers. executor.py fetches action row, builds context, invokes handler, persists output, and updates incident analysis_status.
- Affected files: `backend/app/ai_platform/__init__.py`, `backend/app/ai_platform/context/__init__.py`, `backend/app/ai_platform/context/builders.py`, `backend/app/ai_platform/context/types.py`, `backend/app/ai_platform/executor.py`, `backend/app/ai_platform/handlers/__init__.py`, `backend/app/ai_platform/handlers/base.py`, `backend/app/ai_platform/handlers/improved_fix_flow.py`, `backend/app/ai_platform/handlers/root_cause_analysis.py`, `backend/app/ai_platform/registry.py`
- Commit:
  - 30596dd (feat: implement AI Platform core package (handlers, registry, executor, context builders))

### 3. Feature — Incident service, schemas, and router updated for AI Platform
- Description: ai_action_service.py creates AIAction rows and dispatches the executor in background. incident_service.py refactored to use AIAction (replaces AnalysisJob), computes primary_action/secondary_actions CTA descriptors per incident state. gemini_service.py gains generate() with timeout+retry+truncation. Schemas add AIActionTriggerResponse, ActionDescriptor, origin_type, generation, actor_type. Router wires new trigger endpoints.
- Affected files: `backend/app/services/ai_action_service.py`, `backend/app/services/incident_service.py`, `backend/app/services/gemini_service.py`, `backend/app/schemas/incident.py`, `backend/app/routers/incidents.py`
- Commit:
  - 4c6a172 (feat: update incident service, schemas, and router for AI Platform)

### 4. Feature — Backend dev auth (validator composition + dev token endpoint)
- Description: auth.py gains _select_validator() dispatch: iss=sentinel-dev routes to _validate_dev_token() (HS256), all others route to _validate_supabase_token() (ES256/JWKS, lazily initialized). config.py adds ENABLE_DEV_AUTH + DEV_JWT_SECRET; removes SUPABASE_JWT_SECRET; adds extra=ignore. routers/dev.py: POST /api/v1/dev/token issues 24h HS256 JWT; optional password field verified if provided. main.py conditionally registers dev router. .env.example and deploy.yml updated to remove SUPABASE_JWT_SECRET.
- Affected files: `backend/app/core/auth.py`, `backend/app/core/config.py`, `backend/app/main.py`, `backend/app/routers/dev.py`, `backend/.env.example`, `backend/.github/workflows/deploy.yml`
- Commit:
  - da36a85 (feat: implement backend dev auth with validator composition and dev token endpoint)

### 5. Feature — Flutter DevAuthRepository with provider-agnostic token resolution
- Description: AuthRepository interface gains getAccessToken() separating identity from credential. AppConfig adds AuthProviderMode.dev. Supabase.initialize() made conditional on authProvider==supabase. api_client.dart _resolveToken() now calls authRepository.getAccessToken() — no provider-specific branching. dev_auth_repository.dart is a new full implementation calling POST /dev/token and POST /auth/register; extracts sub from JWT payload using dart:convert. SupabaseAuthRepository and MockAuthRepository implement getAccessToken(). auth_repository_provider.dart adds dev case. local_backend_auth_repository.dart deleted.
- Affected files: `frontend/sentinel/lib/features/auth/domain/repositories/auth_repository.dart`, `frontend/sentinel/lib/core/config/app_config.dart`, `frontend/sentinel/lib/main.dart`, `frontend/sentinel/lib/core/api/api_client.dart`, `frontend/sentinel/lib/features/auth/data/repositories/dev_auth_repository.dart`, `frontend/sentinel/lib/features/auth/data/repositories/supabase_auth_repository.dart`, `frontend/sentinel/lib/features/auth/data/repositories/mock_auth_repository.dart`, `frontend/sentinel/lib/features/auth/data/providers/auth_repository_provider.dart`, `frontend/sentinel/lib/features/auth/data/mocks/mock_auth_accounts.dart`, `frontend/sentinel/lib/features/auth/data/repositories/local_backend_auth_repository.dart` (deleted), `frontend/sentinel/README.md`
- Commit:
  - 094e126 (feat: implement Flutter DevAuthRepository with provider-agnostic token resolution)

### 6. Test — Comprehensive backend test suite (169 tests)
- Description: pytest.ini configures asyncio_mode=auto. requirements-test.txt adds httpx, pytest-asyncio, pytest-mock. Root conftest.py sets DATABASE_URL to SQLite for test isolation. tests/conftest.py provides session-scoped schema create/drop, per-test table wipe with FK OFF, app fixture with get_current_user override, db session, and Gemini/background mocks. Unit tests cover auth validator routing, context builders, gemini_service retry/timeout, handler parse+validate, CTA computation, and registry contract. Integration tests cover full incident CRUD, AI action triggers, executor end-to-end, and dev token endpoint including password verification (4 new tests) and round-trip token validation.
- Affected files: `backend/conftest.py`, `backend/pytest.ini`, `backend/requirements-test.txt`, `backend/tests/conftest.py`, `backend/tests/integration/test_ai_actions_router.py`, `backend/tests/integration/test_dev_token_router.py`, `backend/tests/integration/test_executor.py`, `backend/tests/integration/test_incidents_router.py`, `backend/tests/unit/test_auth.py`, `backend/tests/unit/test_context_builders.py`, `backend/tests/unit/test_gemini_service.py`, `backend/tests/unit/test_handlers.py`, `backend/tests/unit/test_primary_action.py`, `backend/tests/unit/test_registry.py`
- Commit:
  - ea185ac (test: add comprehensive backend test suite (169 tests))

### 7. Spec — Auth SDD specification documents (sdd/auth/)
- Description: Four new spec documents replacing scattered auth content. 00_overview.md: mechanisms table, environment model with AUTH_PROVIDER column, development workflows table, getAccessToken() in token convention. 01_contract.md: full AuthRepository interface with getAccessToken() behavior per implementation, registerDirect/sendSignUpCode/verifySignUp per-impl tables, environment combinations. 02_production.md: Supabase flows, getAccessToken() implementation with refresh failure path, JWKS lazy init. 03_development.md: validator composition, dev token endpoint spec (password field), DevAuthRepository full implementation spec, api_client.dart and main.dart refactoring specs, migration checklist.
- Affected files: `sdd/auth/00_overview.md`, `sdd/auth/01_contract.md`, `sdd/auth/02_production.md`, `sdd/auth/03_development.md`
- Commit:
  - 402d576 (docs: add auth SDD specification documents (sdd/auth/))

### 8. Spec — SDD workflow, domain, and rules documents
- Description: New foundational governance documents. workflow/00_implementation_lifecycle.md: 6-phase dev lifecycle with gates. workflow/01_context_loading.md: task-type → required documents map. workflow/02_decision_flow.md: decision trees for auth path, DB mode, handler addition. workflow/03_validation.md: definition of done checklists per work stream. domain/state_machines.md: incident status, analysis_status, and AIAction status FSMs. rules/ownership.md: file ownership matrix with source-of-truth hierarchy.
- Affected files: `sdd/workflow/00_implementation_lifecycle.md`, `sdd/workflow/01_context_loading.md`, `sdd/workflow/02_decision_flow.md`, `sdd/workflow/03_validation.md`, `sdd/domain/state_machines.md`, `sdd/rules/ownership.md`
- Commit:
  - 53327a3 (docs: add SDD workflow, domain, and rules documents)

### 9. Spec — Screen spec refactored into per-screen documents
- Description: Monolithic 04_screen_spec.md split into four focused documents. 04_1_auth_screens.md: sign-in, sign-up (2-step), error states, SKIP_EMAIL_VERIFICATION behavior. 04_2_dashboard_screen.md: incident list, severity chips, search/filter, skeleton loader. 04_3_incident_flow_screens.md: create form with origin_type, analysis workspace CTA strip, fix flow cards, status transitions. 04_4_archive_screens.md: closed incident browsing and filter persistence.
- Affected files: `sdd/context/04_screen_spec.md`, `sdd/context/04_1_auth_screens.md`, `sdd/context/04_2_dashboard_screen.md`, `sdd/context/04_3_incident_flow_screens.md`, `sdd/context/04_4_archive_screens.md`
- Commit:
  - d492d03 (docs: split monolithic screen spec into per-screen documents (sdd/context/))

### 10. Spec — SDD index, backend, infra, and archive spec updates
- Description: 00_index.md updated to include new sdd/ directories. 05_api_spec.md documents AI action trigger endpoints and updated response schemas. 06_database_schema.md reflects b2c3d4e5f6a7 migration. 07_auth_spec.md condensed to pointer doc. 08_ai_integration_spec.md updated for ai_platform package. 09_backend_arch.md updated package/router/service lists. 11_deployment_spec.md removes SUPABASE_JWT_SECRET, documents ENABLE_DEV_AUTH rules. 12_testing_spec.md reflects actual 169-test suite. mock_auth_accounts.md adds password field. Archive preserves original agent instructions and spec compliance report.
- Affected files: `sdd/00_index.md`, `sdd/13_agent_instructions.md`, `sdd/backend/05_api_spec.md`, `sdd/backend/06_database_schema.md`, `sdd/backend/07_auth_spec.md`, `sdd/backend/08_ai_integration_spec.md`, `sdd/backend/09_backend_arch.md`, `sdd/infra/11_deployment_spec.md`, `sdd/infra/12_testing_spec.md`, `sdd/frontend/mock_auth_accounts.md`, `sdd/spec_compliance_report.md`, `sdd/archive/13_agent_instructions_original.md`, `sdd/archive/spec_compliance_report.md`
- Commit:
  - 4655bd9 (docs: update SDD index, backend, infra, and archive specs for AI Platform + auth)

### 11. Spec — CLAUDE.md updated with current architecture and workflow
- Description: Adds mandatory process steps (implementation lifecycle + context loading guide). Updates PowerShell venv activation syntax. Documents universal conventions. Updates critical implementation notes for auth validator composition, SQLite/PG dual-mode, Alembic PG-only guard, and source-of-truth principle. Adds documentation map pointing to new sdd/workflow/, sdd/auth/, sdd/rules/ directories.
- Affected files: `CLAUDE.md`
- Commit:
  - a4e0706 (docs: update CLAUDE.md with current architecture and workflow instructions)

# CLAUDE.md

Sentinel is an AI-assisted incident management web app. Engineers paste error logs; the backend calls Gemini to run root-cause analysis and generate ranked fix flows; the result is tracked through an incident workspace until resolved or closed.

**Stack:** Flutter Web (Riverpod + go_router) ↔ FastAPI (Python 3.12, async SQLAlchemy) ↔ SQLite (dev) / PostgreSQL (prod, Alembic) ↔ Gemini API (server-side only) ↔ Supabase Auth (JWT)

---

## Commands

### Backend (`backend/`)

```bash
python -m venv .venv && .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
cp .env.example .env

uvicorn app.main:app --reload --port 8000   # docs at http://localhost:8000/docs

pytest                                        # whole suite
pytest tests/unit/test_x.py::test_name -v    # single test

alembic upgrade head                          # PostgreSQL only
alembic revision --autogenerate -m "desc"
```

`backend/tests/` currently only has `__init__.py` — tests described in `sdd/infra/12_testing_spec.md` are not yet implemented.

### Frontend (`frontend/sentinel/`)

```bash
flutter pub get
flutter analyze
flutter test

flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key> \
  --dart-define=API_BASE_URL=http://localhost:8000
```

Runtime behavior is controlled by `--dart-define` flags, not `.env`. See `lib/core/config/app_config.dart`:
- `AUTH_PROVIDER`: `supabase` (default) | `mock` (UI-only dev)
- `USE_MOCK_DATA`: defaults `true` — set `false` to hit the real backend
- `SKIP_EMAIL_VERIFICATION`: defaults `true` for dev

---

## Universal Conventions

- Incident ID: `INC-YYYY-NNN` (e.g. `INC-2026-041`), globally unique
- Severity: `critical` | `major` | `minor` (lowercase in DB/API, display-cased in UI)
- Status: `open` → `in_progress` → `resolved` → `closed`
- Timestamps: UTC ISO-8601
- JWT: `Authorization: Bearer <token>`
- All API routes under `/api/v1`
- No hardcoded style values in Flutter — use `design_system/tokens/` always

---

## Critical Implementation Notes

**Auth:** Tokens are ES256-signed, verified against the Supabase JWKS endpoint (`{SUPABASE_URL}/auth/v1/.well-known/jwks.json`) via `PyJWKClient`. FastAPI never issues tokens, only verifies them. See `sdd/backend/07_auth_spec.md` for the actual implementation.

**Dev-only endpoint:** `POST /api/v1/auth/register` creates a local `User` row for dev testing. Returns 403 in production (`SKIP_EMAIL_VERIFICATION=False`).

**Database (dev vs prod):** Dev uses SQLite (auto-created on startup). Prod uses PostgreSQL managed exclusively by Alembic. Never run `init_db()` in prod.

**Source of truth principle:** When code and a spec disagree, the code is correct. Specs describe design intent; implementation may have diverged. Always read the actual source first.

---

## How to Start Any Task

```
1. Read this file (already done)
2. Read sdd/workflow/00_implementation_lifecycle.md  ← mandatory process
3. Read sdd/workflow/01_context_loading.md           ← which docs to load for your task
4. Load only the documents listed for your task type
5. Follow the lifecycle: Read → Analyze → Implement → Verify → Validate → Sync Docs
```

---

## Documentation

Full document map: `sdd/00_index.md`  
Implementation process: `sdd/workflow/00_implementation_lifecycle.md`  
Context loading guide: `sdd/workflow/01_context_loading.md`  
Decision flows: `sdd/workflow/02_decision_flow.md`  
Validation spec: `sdd/workflow/03_validation.md`  
State machines: `sdd/domain/state_machines.md`  
Spec authoring rules: `sdd/rules/spec_authoring_rules.md`  
File ownership: `sdd/rules/ownership.md`

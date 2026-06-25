# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Sentinel is an AI-assisted incident management web app. Engineers paste error logs; the backend calls Gemini to extract metadata, run root-cause analysis, and generate ranked fix flows; the result is tracked through an incident workspace (checklist, notes, timeline) until resolved/closed.

Stack: Flutter Web (Riverpod + go_router) ↔ FastAPI (Python 3.12, async SQLAlchemy) ↔ SQLite (dev) / PostgreSQL (prod, via Alembic) ↔ Gemini API (server-side only) ↔ Supabase Auth (JWT issuance).

## Commands

### Backend (`backend/`)

```bash
# setup
python -m venv .venv && .\.venv\Scripts\Activate.ps1   # Windows
pip install -r requirements.txt
cp .env.example .env

# run dev server (SQLite, auto-creates tables on startup)
uvicorn app.main:app --reload --port 8000
# docs at http://localhost:8000/docs

# tests
pytest                       # whole suite
pytest tests/unit/test_x.py  # single file
pytest tests/unit/test_x.py::test_name -v   # single test

# Alembic migrations (PostgreSQL only — SQLite dev DB is created directly by the app)
alembic upgrade head
alembic revision --autogenerate -m "description"
```

Note: `backend/tests/` currently only has `__init__.py` — the unit/integration suites described in `sdd/infra/12_testing_spec.md` are not yet implemented. Don't assume test files exist; check before referencing them.

### Frontend (`frontend/sentinel/`)

```bash
flutter pub get
flutter analyze
flutter test                 # widget/provider tests
flutter test test/widget/test_x.dart   # single file

flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key> \
  --dart-define=API_BASE_URL=http://localhost:8000
```

Build-time flags (`--dart-define`), not `.env` parsing, control runtime behavior — see `lib/core/config/app_config.dart`:
- `AUTH_PROVIDER`: `supabase` (default/canonical) | `mock` (UI-only dev) | `localBackend` (deprecated)
- `USE_MOCK_DATA`: defaults `true` — set `false` to hit the real backend
- `SKIP_EMAIL_VERIFICATION`: defaults `true` for dev

Start the backend before the frontend; verify connectivity by registering an incident and checking AI analysis returns.

## Architecture

### Backend layering (`backend/app/`)

```
routers/   -> thin: validate input, call service, return response
services/  -> all business logic + DB queries (incident_service.py, gemini_service.py)
models/    -> SQLAlchemy ORM (models.py)
schemas/   -> Pydantic request/response contracts
core/      -> config.py (env settings), database.py (async engine/session), auth.py (JWT verification)
```

Rules enforced by convention here (see `sdd/13_agent_instructions.md` for the full per-area ownership map):
- Routers never call `gemini_service.py` directly — always through `incident_service.py`.
- All API routes are mounted under `/api/v1` (see `app/main.py`).
- DB writes use `async with db.begin()` for transaction safety.
- Ownership enforcement: every incident read/write checks `incident.user_id == current_user["user_id"]`, raising 403 otherwise (no cross-user access).

### Auth model — important nuance vs. the SDD docs

Authentication is Supabase Auth end-to-end; FastAPI **never issues tokens, only verifies them**. The actual verification (`app/core/auth.py`) differs from what `sdd/backend/07_auth_spec.md` describes: tokens are ES256-signed and verified against the Supabase project's **JWKS endpoint** (`{SUPABASE_URL}/auth/v1/.well-known/jwks.json`) via `PyJWKClient`, not decoded with a shared `SUPABASE_JWT_SECRET`/HS256 as the spec states. The JWKS client is built once at import time and fails fast if `SUPABASE_URL` is unset.

`POST /api/v1/auth/register` (`app/routers/auth.py`) is a **dev-only** convenience endpoint that creates a local `User` row so business tables have a `user_id` to reference — it does not issue tokens and returns 403 when `SKIP_EMAIL_VERIFICATION=False` (i.e., in production).

### Database

- Dev: SQLite (`sentinel_dev.db`), tables created automatically on app startup (`lifespan` in `main.py`) — no migrations needed.
- Prod: PostgreSQL, schema managed **exclusively** by Alembic (`backend/alembic/`); the app never auto-creates tables outside SQLite. Run migrations via `backend/scripts/migrate.sh`, intended as a Cloud Run Job step before deploying a new revision.
- `resolved_database_url` (in `config.py`) picks SQLite for dev and requires `DATABASE_URL` to be set explicitly in production (raises otherwise).

### AI integration

`gemini_service.py` owns all Gemini calls and prompt templates; `incident_service.py` orchestrates: extract metadata → create incident → run analysis → persist fix flows/checklist/timeline. Gemini is called **server-side only** — the API key never reaches the Flutter client.

### Frontend structure (`frontend/sentinel/lib/`)

```
core/           api_client.dart (Dio + Supabase JWT interceptor), router/ (go_router), config/
design_system/  tokens/ (colors, typography, spacing) + components/ — no hardcoded style values, ever
features/<name>/{data,domain,presentation}/   one Riverpod AsyncNotifier per feature
```

- Routing redirect logic lives in `core/router/app_router.dart`: unauthenticated users are forced to `/login`, authenticated users away from `/login`/`/signup`.
- Every screen should match a reference PNG in `sentinel_screen_ref/web/` (or `/mobile/`) and the corresponding spec in `sdd/context/04_screen_spec.md`.
- Reuse existing `design_system/components/` before adding a new one.

## Conventions (apply across backend and frontend)

- Incident ID format: `INC-YYYY-NNN` (e.g. `INC-2026-041`), globally unique.
- Severity: `critical` | `major` | `minor` (lowercase in DB/API, display-cased in UI).
- Incident lifecycle: `open` → `in_progress` → `resolved` → `closed`.
- Timestamps: UTC ISO-8601.
- JWT passed as `Authorization: Bearer <token>`.

## Project documentation (`sdd/`)

This repo is spec-driven — `sdd/00_index.md` is the master index. Before changing API contracts, DB schema, or screens, check the relevant spec:
- `sdd/backend/05_api_spec.md` — endpoint contracts
- `sdd/backend/06_database_schema.md` — table definitions
- `sdd/backend/08_ai_integration_spec.md` — Gemini prompts/parsing
- `sdd/context/04_screen_spec.md` — screen-to-PNG mapping

Treat the specs as design intent, not ground truth for already-implemented code — as shown above with the auth flow, implementation has diverged in places. When in doubt, read the actual source first.

`sdd/13_agent_instructions.md` defines per-area ownership boundaries (e.g., only the "AI Integration" area touches `gemini_service.py`; only "Database" area touches `database/migrations/`). Respect these boundaries when a change spans multiple areas — coordinate rather than editing across them silently.

## Specification Authoring

Before creating, updating, or refactoring any specification document:

Read and follow:

`/sdd/rules/spec_authoring_rules.md`

All specification documents must comply with those rules.

If a specification exceeds the defined size limits,
split it into multiple files based on responsibility.

Avoid creating large monolithic specification documents.

# 09 — Backend Architecture

**Framework:** FastAPI (Python 3.12, async)  
**Refs:** → [API Spec](./05_api_spec.md) · [Auth](../auth/00_overview.md) · [AI Integration](./08_ai_integration_spec.md)

---

## Folder Structure

```
backend/app/
├── main.py              # FastAPI app factory, CORS, router registration, lifespan
├── core/
│   ├── config.py        # Pydantic Settings (env vars)
│   ├── database.py      # async engine, AsyncSessionFactory, get_db, init_db
│   └── auth.py          # JWT validation: _select_validator, _validate_supabase_token, _validate_dev_token, get_current_user
├── routers/
│   ├── incidents.py     # CRUD + /ai-actions + /reopen + deprecated /analyze
│   ├── checklist.py     # PATCH /checklist/{id}
│   ├── notes.py         # PUT /incidents/{id}/note
│   ├── timeline.py      # GET /incidents/{id}/timeline
│   ├── fix_flows.py     # PATCH /fix-flows/{id}/attempted
│   ├── archive.py       # GET /archive
│   ├── auth.py          # POST /auth/register (dev-only convenience)
│   ├── ocr.py           # POST /ocr/extract-log
│   └── dev.py           # POST /dev/token — conditionally registered only when ENABLE_DEV_AUTH=True (see sdd/auth/03_development.md)
├── models/
│   └── models.py        # SQLAlchemy ORM (all tables)
├── schemas/
│   └── incident.py      # All Pydantic request/response schemas
├── services/
│   ├── gemini_service.py     # Gemini API calls: extract_metadata(), generate()
│   ├── incident_service.py   # Incident CRUD, compute_primary_action/secondary_actions
│   └── ai_action_service.py  # request_action(), run_background(), create_system_action()
└── ai_platform/
    ├── registry.py           # REGISTRY dict, PRIORITY_ORDER list, get_handler()
    ├── executor.py           # T1/T2 execution loop
    ├── handlers/
    │   ├── base.py                  # AIActionHandler ABC
    │   ├── root_cause_analysis.py   # RootCauseAnalysisHandler (priority 10)
    │   └── improved_fix_flow.py     # ImprovedFixFlowHandler (priority 20)
    └── context/
        ├── types.py          # Frozen dataclasses: CoreIncidentContext, etc.
        └── builders.py       # Async context assembly functions
```

---

## Layering Rules

- **Routers:** validate input, call service, return response. Never call `gemini_service` or `executor` directly.
- **incident_service:** owns incident CRUD + `compute_primary_action` + lifecycle hooks. Never calls executor.
- **ai_action_service:** owns AIAction row creation and `run_background()` dispatch. Called by router.
- **executor:** owns T1/T2 transaction boundary. Calls handlers. Opens its own sessions via `AsyncSessionFactory`.
- **handlers:** own prompt construction, output parsing, result persistence per action type.
- **gemini_service:** owns model calls and prompt templates. No DB access.

All incident read/write checks `incident.user_id == current_user["user_id"]`, raises 403 otherwise.

---

## main.py

```python
from app.routers import incidents, checklist, notes, timeline, fix_flows, archive, auth, ocr

@asynccontextmanager
async def lifespan(app):
    if settings.resolved_database_url.startswith("sqlite"):
        await init_db()   # dev only — PostgreSQL uses Alembic
    yield

def create_app():
    app = FastAPI(title="Sentinel API", version="1.0.0", lifespan=lifespan)
    app.add_middleware(CORSMiddleware, ...)
    for r in [auth, incidents, checklist, notes, timeline, fix_flows, archive, ocr]:
        app.include_router(r.router, prefix="/api/v1")
    return app
```

---

## core/config.py

```python
class Settings(BaseSettings):
    DATABASE_URL: str | None = None   # required in prod; omit for SQLite dev
    SUPABASE_URL: str                 # used for JWKS endpoint
    GEMINI_API_KEY: str
    GEMINI_MODEL: str = "gemini-2.0-flash"
    ANALYSIS_TIMEOUT_SECONDS: int = 15
    ALLOWED_ORIGINS: list[str] = ["http://localhost:3000"]
    APP_ENV: str = "development"
    SKIP_EMAIL_VERIFICATION: bool = True

    @property
    def resolved_database_url(self) -> str:
        return self.DATABASE_URL or "sqlite+aiosqlite:///./sentinel_dev.db"
```

---

## core/database.py

```python
engine = create_async_engine(settings.resolved_database_url, echo=False)
AsyncSessionFactory = async_sessionmaker(engine, expire_on_commit=False)

async def get_db() -> AsyncSession:
    async with AsyncSessionFactory() as session:
        yield session
```

`AsyncSessionFactory` is used directly by `executor.py` and `ai_action_service.create_system_action()` when they need sessions independent of the request lifecycle.

---

## incident_service.py Key Functions

| Function | Responsibility |
|---|---|
| `extract_metadata_for_display(log_text, db)` | Calls gemini; returns metadata dict (no DB write) |
| `create_incident(body, user_id, db, origin_type)` | Creates Incident + initial AIAction row; returns `(incident_id, action_id)` |
| `get_incident_detail(incident_id, user_id, db)` | Returns `IncidentResponse` with computed `primary_action`/`secondary_actions` |
| `compute_primary_action(incident)` | Pure fn: iterates PRIORITY_ORDER, returns first matching handler's descriptor |
| `compute_secondary_actions(incident)` | Pure fn: returns at most 2 secondary descriptors |
| `patch_incident / resolve / reopen / close` | Lifecycle transitions + timeline events |
| `_fire_lifecycle_hooks(event, incident_id)` | Calls `ai_action_service.create_system_action` for matching handlers |

---

## ai_action_service.py Key Functions

| Function | Responsibility |
|---|---|
| `request_action(incident_id, action_type, user_id, db)` | Validates, creates AIAction row, returns `(action_id, attempt_number)` |
| `run_background(action_id)` | Entry point for BackgroundTasks; delegates to executor |
| `create_system_action(incident_id, action_type)` | Opens own session; used by lifecycle hooks |

---

## Dependencies

```
fastapi==0.115.x
uvicorn[standard]==0.34.x
sqlalchemy[asyncio]==2.0.x
aiosqlite==0.20.x          # dev SQLite driver
asyncpg==0.30.x            # prod PostgreSQL driver
alembic==1.13.x
pydantic-settings==2.x
google-generativeai==0.8.x
PyJWKClient (PyJWT + cryptography)  # Supabase JWKS verification
python-dotenv==1.x
pillow / pytesseract        # OCR support
```

# 09 — Backend Architecture

**Framework:** FastAPI (Python 3.12)  
**Refs:** → [API Spec](./05_api_spec.md) · [Auth Spec](./07_auth_spec.md) · [AI Integration Spec](./08_ai_integration_spec.md)

---

## Folder Structure

```
backend/
├── app/
│   ├── main.py              # FastAPI app factory, CORS, router registration
│   ├── core/
│   │   ├── config.py        # Pydantic Settings (env vars)
│   │   ├── database.py      # SQLAlchemy async engine + session factory
│   │   └── auth.py          # JWT validation, get_current_user dependency
│   ├── routers/
│   │   ├── incidents.py     # /incidents CRUD + analyze-metadata endpoint
│   │   ├── checklist.py     # /checklist/{item_id} PATCH
│   │   ├── notes.py         # /incidents/{id}/note PUT
│   │   ├── timeline.py      # /incidents/{id}/timeline GET
│   │   ├── fix_flows.py     # /fix-flows/{id}/attempted PATCH
│   │   └── archive.py       # /archive GET
│   ├── models/
│   │   └── models.py        # SQLAlchemy ORM models (all tables)
│   ├── schemas/
│   │   ├── incident.py      # Pydantic request/response schemas for incidents
│   │   ├── checklist.py     # Pydantic schemas for checklist items
│   │   ├── fix_flow.py      # Pydantic schemas for fix flows
│   │   ├── note.py          # Pydantic schemas for notes
│   │   └── analysis.py      # Pydantic schemas for AI responses
│   └── services/
│       ├── gemini_service.py    # Gemini API calls, prompt templates, parsing
│       └── incident_service.py  # Business logic: create incident, run analysis, build context
├── requirements.txt
├── Dockerfile
└── .env.example
```

---

## main.py Responsibilities

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import incidents, checklist, notes, timeline, fix_flows, archive

def create_app() -> FastAPI:
    app = FastAPI(title="Sentinel API", version="1.0.0")
    app.add_middleware(CORSMiddleware,
        allow_origins=settings.ALLOWED_ORIGINS,
        allow_methods=["*"], allow_headers=["*"], allow_credentials=True)
    app.include_router(incidents.router, prefix="/api/v1")
    app.include_router(checklist.router, prefix="/api/v1")
    app.include_router(notes.router, prefix="/api/v1")
    app.include_router(timeline.router, prefix="/api/v1")
    app.include_router(fix_flows.router, prefix="/api/v1")
    app.include_router(archive.router, prefix="/api/v1")
    return app
```

---

## core/config.py

```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    DATABASE_URL: str           # postgresql+asyncpg://...
    SUPABASE_JWT_SECRET: str
    GEMINI_API_KEY: str
    GEMINI_MODEL: str = "gemini-2.0-flash"
    GEMINI_TIMEOUT_SECONDS: int = 15
    ALLOWED_ORIGINS: list[str] = ["http://localhost:3000"]

    class Config:
        env_file = ".env"

settings = Settings()
```

---

## core/database.py

```python
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

engine = create_async_engine(settings.DATABASE_URL, echo=False)
AsyncSessionFactory = async_sessionmaker(engine, expire_on_commit=False)

async def get_db() -> AsyncSession:
    async with AsyncSessionFactory() as session:
        yield session
```

---

## Router Pattern

Every router uses the same dependency injection pattern:

```python
# routers/incidents.py
from fastapi import APIRouter, Depends
from app.core.auth import get_current_user
from app.core.database import get_db

router = APIRouter(tags=["incidents"])

@router.post("/incidents", status_code=201)
async def create_incident(
    body: IncidentCreateRequest,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    return await incident_service.create_and_analyze(body, current_user["user_id"], db)
```

---

## Service Layer Rules

- Routers are thin: validate input, call service, return response
- Services contain all business logic and DB queries
- Gemini calls happen inside `incident_service.py`, which calls `gemini_service.py`
- Services never import from routers
- All DB operations use `async with db.begin()` for transaction safety

---

## incident_service.py Key Functions

| Function | Responsibility |
|----------|----------------|
| `extract_metadata(log_text)` | Calls gemini; returns metadata dict |
| `create_and_analyze(body, user_id, db)` | Creates incident, runs full AI analysis, stores all results |
| `attach_fix_flow(incident_id, flow_id, user_id, db)` | Updates selected_fix_flow_id, sets status in_progress, adds timeline event |
| `resolve_incident(incident_id, user_id, db)` | Sets status=resolved, resolved_at=now, adds timeline event |
| `get_dashboard_incidents(user_id, db)` | Returns all non-closed incidents |
| `get_archive_incidents(user_id, db)` | Returns resolved+closed incidents with computed resolution_time_minutes |

---

## Dependencies

```
fastapi==0.115.x
uvicorn[standard]==0.34.x
sqlalchemy[asyncio]==2.0.x
asyncpg==0.30.x
pydantic-settings==2.x
python-jose[cryptography]==3.x
google-generativeai==0.8.x
python-dotenv==1.x
```

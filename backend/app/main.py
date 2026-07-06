from contextlib import asynccontextmanager
from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db, init_db
from app.routers import incidents, checklist, notes, timeline, fix_flows, archive, auth, ocr


@asynccontextmanager
async def lifespan(app: FastAPI):
    # SQLite only: create tables on first run (dev convenience).
    # PostgreSQL tables are managed exclusively by Alembic migrations.
    if settings.resolved_database_url.startswith("sqlite"):
        await init_db()
    yield


def create_app() -> FastAPI:
    app = FastAPI(
        title="Sentinel API",
        version="1.0.0",
        lifespan=lifespan,
        # Disable interactive docs in production to reduce attack surface.
        docs_url="/docs" if settings.APP_ENV != "production" else None,
        redoc_url="/redoc" if settings.APP_ENV != "production" else None,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.ALLOWED_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(auth.router,       prefix="/api/v1")
    app.include_router(incidents.router,  prefix="/api/v1")
    app.include_router(checklist.router,  prefix="/api/v1")
    app.include_router(notes.router,      prefix="/api/v1")
    app.include_router(timeline.router,   prefix="/api/v1")
    app.include_router(fix_flows.router,  prefix="/api/v1")
    app.include_router(archive.router,    prefix="/api/v1")
    app.include_router(ocr.router,        prefix="/api/v1")

    # Dev router: registered only when ENABLE_DEV_AUTH is True.
    # When disabled, POST /api/v1/dev/token does not exist (404, not 403).
    if settings.ENABLE_DEV_AUTH:
        from app.routers import dev  # noqa: PLC0415
        app.include_router(dev.router, prefix="/api/v1")

    # ── Health endpoints ──────────────────────────────────────────────────────

    @app.get("/health", tags=["health"], include_in_schema=False)
    async def health():
        """
        Liveness probe — returns 200 as long as the process is alive.
        Cloud Run uses this to decide whether to restart the container.
        """
        return {"status": "ok", "version": "1.0.0"}

    @app.get("/health/ready", tags=["health"], include_in_schema=False)
    async def health_ready(db: AsyncSession = Depends(get_db)):
        """
        Readiness probe — returns 200 only when the DB is reachable.
        Cloud Run (and load balancers) can use this to gate traffic.

        Returns 503 if the database is unavailable so the instance is
        temporarily removed from the load-balancer rotation rather than
        serving 500s to real users.
        """
        try:
            await db.execute(text("SELECT 1"))
            return {"status": "ready"}
        except Exception:
            raise HTTPException(status_code=503, detail="Database unavailable")

    return app


app = create_app()

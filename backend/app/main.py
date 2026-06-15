from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.core.database import init_db
from app.routers import incidents, checklist, notes, timeline, fix_flows, archive, auth


@asynccontextmanager
async def lifespan(app: FastAPI):
    if settings.resolved_database_url.startswith("sqlite"):
        await init_db()
    yield


def create_app() -> FastAPI:
    app = FastAPI(title="Sentinel API", version="1.0.0", lifespan=lifespan)

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.ALLOWED_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(auth.router, prefix="/api/v1")
    app.include_router(incidents.router, prefix="/api/v1")
    app.include_router(checklist.router, prefix="/api/v1")
    app.include_router(notes.router, prefix="/api/v1")
    app.include_router(timeline.router, prefix="/api/v1")
    app.include_router(fix_flows.router, prefix="/api/v1")
    app.include_router(archive.router, prefix="/api/v1")

    @app.get("/health", tags=["health"])
    async def health():
        return {"status": "ok", "version": "1.0.0"}

    return app


app = create_app()

"""
Shared test fixtures.

All async fixtures and tests run with asyncio_mode=auto (set in pytest.ini).
env vars are set in the root backend/conftest.py before any app.* imports.
"""
import pytest
from httpx import AsyncClient, ASGITransport
from sqlalchemy import text
from unittest.mock import AsyncMock, patch

from app.core.database import Base, AsyncSessionFactory, engine
from app.core.auth import get_current_user
from app.main import create_app

TEST_USER_ID = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
TEST_USER_ID_2 = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"

SAMPLE_INCIDENT = {
    "log_text": "ERROR: FATAL: remaining connection slots reserved for replication",
    "title": "DB Connection Pool Exhausted",
    "severity": "critical",
    "components": ["PostgreSQL"],
}

RCA_OUTPUT = {
    "root_cause": "Database connection pool exhausted due to high traffic",
    "confidence": 0.87,
    "impact_summary": "Database rejecting new connections",
    "fix_flows": [
        {
            "title": "Restart connection pool",
            "confidence": 0.9,
            "checklist_items": ["Check pool config", "Restart service"],
        },
        {
            "title": "Scale database connections",
            "confidence": 0.75,
            "checklist_items": ["Increase max_connections"],
        },
    ],
    "similar_incident_codes": [],
}

IFF_OUTPUT = {
    "root_cause": "Connection pool settings too conservative for current traffic",
    "confidence": 0.92,
    "fix_flows": [
        {
            "title": "Deploy PgBouncer connection pooler",
            "confidence": 0.95,
            "checklist_items": ["Install PgBouncer", "Set pool_size=50", "Update DSN"],
        }
    ],
}


@pytest.fixture(scope="session", autouse=True)
async def setup_database():
    """Create all tables once per test session."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest.fixture(autouse=True)
async def clear_tables():
    """Wipe all rows before each test for isolation."""
    async with engine.begin() as conn:
        # FK constraints are ON (SQLite PRAGMA set by _build_engine).
        # Disable them temporarily so we can delete in any order.
        await conn.execute(text("PRAGMA foreign_keys = OFF"))
        for table in Base.metadata.tables.values():
            await conn.execute(table.delete())
        await conn.execute(text("PRAGMA foreign_keys = ON"))
    yield


@pytest.fixture
def app():
    """FastAPI app with auth dependency replaced by a fixed test user."""
    application = create_app()

    async def _fake_user():
        return {"user_id": TEST_USER_ID, "email": "test@test.com"}

    application.dependency_overrides[get_current_user] = _fake_user
    return application


@pytest.fixture
async def client(app):
    """HTTP test client. lifespan runs init_db() (idempotent on existing tables)."""
    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test/api/v1",
    ) as c:
        yield c


@pytest.fixture
async def db():
    """Raw AsyncSession for test-setup DB writes and post-action assertions."""
    async with AsyncSessionFactory() as session:
        yield session


@pytest.fixture
def mock_run_background():
    """Prevents background AI tasks from running during router-only tests."""
    with patch(
        "app.services.ai_action_service.run_background",
        new_callable=AsyncMock,
    ) as m:
        yield m


@pytest.fixture
def mock_gemini_rca():
    """Gemini returns a valid RCA JSON payload."""
    import json

    with patch(
        "app.services.gemini_service.generate",
        new_callable=AsyncMock,
        return_value=json.dumps(RCA_OUTPUT),
    ) as m:
        yield m


@pytest.fixture
def mock_gemini_iff():
    """Gemini returns a valid IFF JSON payload."""
    import json

    with patch(
        "app.services.gemini_service.generate",
        new_callable=AsyncMock,
        return_value=json.dumps(IFF_OUTPUT),
    ) as m:
        yield m

from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy import event
from app.core.config import settings


def _build_engine():
    url = settings.resolved_database_url
    if url.startswith("sqlite"):
        eng = create_async_engine(url, echo=False)

        @event.listens_for(eng.sync_engine, "connect")
        def _set_sqlite_pragma(dbapi_conn, _):
            cursor = dbapi_conn.cursor()
            cursor.execute("PRAGMA foreign_keys=ON")
            cursor.close()

        return eng
    return create_async_engine(url, echo=False, pool_pre_ping=True)


engine = _build_engine()
AsyncSessionFactory = async_sessionmaker(engine, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


async def get_db() -> AsyncSession:
    async with AsyncSessionFactory() as session:
        yield session


async def init_db() -> None:
    """Create all tables from ORM metadata. Called on startup for SQLite environments."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

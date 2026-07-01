from uuid import uuid4

from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy import event
from sqlalchemy.pool import NullPool
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
    # DATABASE_URL is Supabase's pooler (transaction-pooling mode, port
    # 6543) — PgBouncer/Supavisor does not guarantee the same backend
    # Postgres connection across uses. Two independent prepared-statement
    # paths need covering (confirmed by direct testing against the pooler):
    #   * SQLAlchemy's own query execution always issues *named* prepared
    #     statements via asyncpg.Connection.prepare() with a predictable
    #     sequential name -> fixed by prepared_statement_name_func
    #     (UUID-based names, so two clients sharing a recycled backend
    #     connection can never collide on the same statement name).
    #   * asyncpg's own internal bookkeeping (e.g. the dialect's automatic
    #     on-connect JSONB-codec type introspection) goes through asyncpg's
    #     *native* statement cache/auto-naming, independent of the
    #     SQLAlchemy-level hook above -> fixed by statement_cache_size=0
    #     (asyncpg's own error message names this exact setting for this
    #     exact scenario).
    #   * poolclass=NullPool — PgBouncer is the only connection pool in the
    #     stack; SQLAlchemy must not pool on top of it.
    # All three together are SQLAlchemy's documented PgBouncer-compatible
    # configuration:
    # https://docs.sqlalchemy.org/en/20/dialects/postgresql.html#prepared-statement-name-with-pgbouncer
    # Do not re-enable SQLAlchemy-side pooling or revert either setting
    # without confirming DATABASE_URL no longer points at a pooled connection.
    return create_async_engine(
        url,
        echo=False,
        pool_pre_ping=True,
        poolclass=NullPool,
        connect_args={
            "statement_cache_size": 0,
            "prepared_statement_name_func": lambda: f"__asyncpg_{uuid4()}__",
        },
    )


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

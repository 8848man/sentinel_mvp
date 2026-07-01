"""Alembic env.py — synchronous migrations, async FastAPI runtime.

Connection URL priority (migration only):
  1. MIGRATION_DATABASE_URL  — direct Supabase connection (port 5432), required for DDL
  2. DATABASE_URL             — fallback; asyncpg/aiosqlite scheme is normalised to psycopg2

⚠️  Supabase pooler (port 6543, PgBouncer transaction mode) must NOT be used here.
    Use the "Direct connection" URL from:
      Supabase Dashboard → Project Settings → Database → Connection string (URI)
    Format: postgresql://postgres:<password>@db.<ref>.supabase.co:5432/postgres

FastAPI runtime continues to use create_async_engine (postgresql+asyncpg://) unchanged.
"""
import os
from logging.config import fileConfig

from sqlalchemy import engine_from_config, pool

from alembic import context

# ── Import Base + all models so their tables are registered in metadata ────────
from app.core.database import Base          # noqa: E402
import app.models.models                    # noqa: F401, E402  (side-effect import)
from app.core.config import settings

# ── Alembic Config ─────────────────────────────────────────────────────────────
config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


# ── URL resolution ─────────────────────────────────────────────────────────────

def _get_url() -> str:
    """
    Resolve and normalise the migration URL to a synchronous psycopg2 scheme.

    Accepted input formats → output:
      postgresql://...              → postgresql://...          (unchanged)
      postgres://...                → postgresql://...
      postgresql+asyncpg://...      → postgresql://...
      postgresql+aiosqlite://...    → error (SQLite has no sync PG driver)
      sqlite+aiosqlite://...        → error (SQLite unsupported for migrations)
    """
    raw = settings.MIGRATION_DATABASE_URL or settings.DATABASE_URL
    if not raw:
        raise ValueError(
            "Set MIGRATION_DATABASE_URL (preferred, port 5432 direct connection) "
            "or DATABASE_URL before running Alembic."
        )

    url = raw
    # Strip async driver suffixes → plain postgresql://
    for prefix in (
        "postgresql+asyncpg://",
        "postgresql+psycopg2://",
        "postgres+asyncpg://",
    ):
        if url.startswith(prefix):
            url = "postgresql://" + url[len(prefix):]
            break

    # Normalise legacy postgres:// alias
    if url.startswith("postgres://"):
        url = "postgresql://" + url[len("postgres://"):]

    if not url.startswith("postgresql://"):
        raise ValueError(
            f"MIGRATION_DATABASE_URL must be a PostgreSQL URL. Got: {raw!r}\n"
            "SQLite is not supported for Alembic migrations."
        )

    return url


# ── Offline mode ───────────────────────────────────────────────────────────────

def run_migrations_offline() -> None:
    """Emit SQL to stdout without opening a DB connection.

    Usage:  alembic upgrade head --sql
    """
    url = _get_url()
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


# ── Online mode ────────────────────────────────────────────────────────────────

def run_migrations_online() -> None:
    """Open a synchronous engine and run migrations."""
    url = _get_url()

    # Build connect_args for Supabase direct connections
    connect_args: dict = {}
    if "supabase" in url:
        connect_args["sslmode"] = "require"

    connectable = engine_from_config(
        {"sqlalchemy.url": url},
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
        connect_args=connect_args,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,
            compare_server_default=True,
        )
        with context.begin_transaction():
            context.run_migrations()


# ── Dispatch ──────────────────────────────────────────────────────────────────
if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()

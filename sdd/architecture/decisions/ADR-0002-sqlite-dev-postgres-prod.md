# ADR-0002: Dual Database Mode — SQLite for Development, PostgreSQL for Production

**Status:** Accepted
**Date:** 2026-06-15 (approximate — predates formal ADR tracking; inferred from `CLAUDE.md` and `core/config.py`)
**Affects specs:** `sdd/backend/06_database_schema.md`, `sdd/backend/09_backend_arch.md`, `sdd/infra/11_deployment_spec.md`

---

## Context

Local backend development should not require provisioning a PostgreSQL instance (Cloud SQL or otherwise) just to run the app and its tests. Production requires PostgreSQL for Cloud SQL integration, concurrent-write correctness, and Alembic-managed schema evolution.

## Decision

`Settings.resolved_database_url` returns the explicit `DATABASE_URL` if set, otherwise falls back to `sqlite+aiosqlite:///./sentinel_dev.db`. `app/main.py`'s lifespan hook calls `init_db()` (create tables from ORM models directly) **only** when the resolved URL starts with `sqlite`. PostgreSQL schema is managed exclusively by Alembic migrations (`backend/alembic/versions/`) — `init_db()` must never run against PostgreSQL. In production, `resolved_database_url` raises `ValueError` if `DATABASE_URL` is unset, rather than silently falling back to SQLite.

## Alternatives Considered

- **PostgreSQL everywhere, including local dev** (e.g., via Docker Compose) — rejected: adds a mandatory local dependency and startup step for every contributor and CI job, with no correctness benefit at this project's current scale (single-writer-per-request patterns, no concurrent-migration testing need locally).
- **SQLite in production** — never seriously considered; ruled out immediately by Cloud Run's ephemeral, horizontally-scaled filesystem model, which SQLite's single-file, single-writer design is incompatible with.

## Consequences

- Two schema-creation code paths exist (`init_db()` for SQLite, Alembic for PostgreSQL) and must be kept in sync manually — a model change requires updating both `models.py` and, for the PostgreSQL path, a migration. This is the source of the ordering rule in `sdd/workflow/02_decision_flow.md` Decision 2 ("write migration first, then update the model" per `sdd/rules/ownership.md`'s cross-boundary rule).
- A schema drift between the two paths (SQLite auto-created vs. PostgreSQL migrated) is possible if a migration is forgotten — this is a known, accepted risk mitigated by CI test coverage against SQLite and manual migration review, not by any automated cross-check today.
- `DATABASE_URL` unset in production fails fast (`ValueError`) rather than silently defaulting to a throwaway SQLite file — a deliberate fail-closed choice.

---

*Backfilled during Phase 1 of the Sentinel Development Operating Model rollout. Predates ADR tracking; reconstructed from `CLAUDE.md` and `backend/app/core/config.py`, not from a contemporaneous design discussion.*

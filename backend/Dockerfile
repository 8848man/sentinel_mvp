# syntax=docker/dockerfile:1
# ─────────────────────────────────────────────────────────────────────────────
# Sentinel API — production Docker image
# Target runtime: Google Cloud Run (linux/amd64)
# Python:   3.11-slim  (Debian Bookworm)
# Server:   Gunicorn + UvicornWorker  (process supervisor + async loop)
# ─────────────────────────────────────────────────────────────────────────────

FROM python:3.11-slim

# ── Build-time environment ────────────────────────────────────────────────────
# PYTHONDONTWRITEBYTECODE — skip .pyc files (saves ~10 MB, speeds up image build)
# PYTHONUNBUFFERED        — flush stdout/stderr immediately (essential for Cloud Logging)
# PIP_NO_CACHE_DIR        — skip pip cache (saves ~50 MB in final layer)
# PIP_DISABLE_PIP_VERSION_CHECK — silence the "new pip available" noise
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# ── System dependencies ───────────────────────────────────────────────────────
# psycopg2-binary bundles its own libpq — no apt packages needed for DB drivers.
# curl is the only extra, kept for optional manual health-check debugging.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# ── Python dependencies (own layer — rebuilt only when requirements.txt changes)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ── Application code ──────────────────────────────────────────────────────────
COPY app/       ./app/
COPY alembic/   ./alembic/
COPY alembic.ini .
COPY scripts/   ./scripts/

RUN chmod +x scripts/migrate.sh scripts/start.sh

# ── Non-root user (Cloud Run best practice) ───────────────────────────────────
RUN groupadd --system --gid 1001 appuser \
    && useradd --system --uid 1001 --gid appuser --no-create-home appuser \
    && chown -R appuser:appuser /app

USER appuser

# ── Runtime environment ───────────────────────────────────────────────────────
# PORT      — Cloud Run injects this; default 8080 matches Cloud Run's expectation.
# WEB_CONCURRENCY — number of Gunicorn workers.  Cloud Run scales *horizontally*
#             (more instances), so keep workers low (1–2) per container.
#             Override via Cloud Run env var if you give instances ≥2 CPUs.
ENV PORT=8080 \
    WEB_CONCURRENCY=1

EXPOSE 8080

# ── Startup ───────────────────────────────────────────────────────────────────
# start.sh launches Gunicorn.  The Cloud Run Job override runs migrate.sh instead.
CMD ["scripts/start.sh"]

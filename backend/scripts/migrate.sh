#!/bin/sh
# ─────────────────────────────────────────────────────────────────────────────
# migrate.sh — run Alembic migrations to latest head.
#
# Designed to run as a Cloud Run Job before the service revision is deployed:
#
#   gcloud run jobs execute sentinel-migrate --region <REGION> --wait
#
# Required env vars (injected from Secret Manager via Cloud Run Job config):
#   MIGRATION_DATABASE_URL   postgresql:// direct connection (port 5432)
#
# Exit codes:
#   0   — migrations completed (or already at head)
#   1   — migration failed; Cloud Run Job will mark the execution as FAILED
# ─────────────────────────────────────────────────────────────────────────────
set -e

echo "[migrate] Starting Alembic migration — target: head"
alembic upgrade head
echo "[migrate] Migration complete."

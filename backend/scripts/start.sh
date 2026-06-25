#!/bin/sh
# ─────────────────────────────────────────────────────────────────────────────
# start.sh — production entrypoint for the Sentinel API Cloud Run service.
#
# Starts Gunicorn with the UvicornWorker class so the fully-async FastAPI app
# runs under a proper process supervisor (graceful restarts, signal handling).
#
# Key design choices:
#
#   --worker-class uvicorn.workers.UvicornWorker
#       Runs the asyncio event loop inside each Gunicorn worker.  This is the
#       correct way to run an async ASGI app; do NOT use sync workers.
#
#   --workers "${WEB_CONCURRENCY:-1}"
#       Cloud Run scales horizontally (more *instances*), so keep workers low.
#       Default: 1.  Raise to 2 if you allocate ≥2 CPUs per instance.
#
#   --forwarded-allow-ips "*"
#       Cloud Run sits behind Google's load balancer; trust all X-Forwarded-For
#       headers so request.client.host reflects the real client IP.
#
#   --timeout 120 / --graceful-timeout 30
#       Allow up to 120 s for a single request.  Gunicorn sends SIGTERM 30 s
#       before hard-killing a worker, allowing in-flight requests to finish.
#       Cloud Run's own request timeout should be ≥ this value (default 300 s).
#
#   --access-logfile / --error-logfile "-"
#       Write all logs to stdout/stderr so Cloud Logging picks them up.
# ─────────────────────────────────────────────────────────────────────────────
set -e

exec gunicorn app.main:app \
    --worker-class  uvicorn.workers.UvicornWorker \
    --workers       "${WEB_CONCURRENCY:-1}" \
    --bind          "0.0.0.0:${PORT:-8080}" \
    --timeout       120 \
    --graceful-timeout 30 \
    --keep-alive    5 \
    --access-logfile  "-" \
    --error-logfile   "-" \
    --log-level     info \
    --forwarded-allow-ips "*"

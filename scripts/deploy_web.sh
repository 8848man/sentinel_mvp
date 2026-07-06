#!/usr/bin/env bash
# Sentinel — Firebase Hosting deployment script.
#
# Builds Flutter Web with the required --dart-define flags and deploys to
# Firebase Hosting in one command. Centralizes per-environment configuration
# so engineers never hand-type flutter build / firebase deploy invocations.
#
# Usage:
#   SUPABASE_URL=... SUPABASE_ANON_KEY=... API_BASE_URL=... ./scripts/deploy_web.sh [production|staging]
#
# Environment defaults to "production" if omitted.

set -euo pipefail

ENVIRONMENT="${1:-production}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND_DIR="$ROOT_DIR/frontend/sentinel"

# Optional per-environment env file (not committed) — e.g. scripts/.env.production
ENV_FILE="$ROOT_DIR/scripts/.env.$ENVIRONMENT"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable '$name' for a '$ENVIRONMENT' deploy." >&2
    echo "Set it before running this script (or add it to scripts/.env.$ENVIRONMENT)." >&2
    exit 1
  fi
}

case "$ENVIRONMENT" in
  production)
    require_var SUPABASE_URL
    require_var SUPABASE_ANON_KEY
    require_var API_BASE_URL
    AUTH_PROVIDER="supabase"
    FIREBASE_PROJECT="${FIREBASE_PROJECT:-sentinel-mvp-eeeee}"
    ;;
  staging)
    # Not configured yet. To enable: provision a staging Supabase project and
    # Cloud Run backend, then set SUPABASE_URL / SUPABASE_ANON_KEY / API_BASE_URL /
    # FIREBASE_PROJECT for staging (e.g. via scripts/.env.staging) and remove this guard.
    echo "Staging deployment is not configured yet. See scripts/deploy_web.sh to enable it." >&2
    exit 1
    ;;
  *)
    echo "Unknown environment '$ENVIRONMENT'. Use 'production' or 'staging'." >&2
    exit 1
    ;;
esac

echo "==> Building Sentinel web (${ENVIRONMENT}, AUTH_PROVIDER=${AUTH_PROVIDER})"

cd "$FRONTEND_DIR"
flutter build web --release \
  --dart-define=AUTH_PROVIDER="$AUTH_PROVIDER" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=USE_MOCK_DATA=false \
  --dart-define=SKIP_EMAIL_VERIFICATION=false

echo "==> Deploying to Firebase Hosting project ${FIREBASE_PROJECT}"
# firebase.json / .firebaserc live in frontend/sentinel; stay there so "public": "build/web" resolves correctly.
firebase deploy --only hosting --project "$FIREBASE_PROJECT"

echo "==> Deployment complete."

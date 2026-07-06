# ADR-0001: JWT Validator Dispatch by `iss` Claim for Dev Authentication

**Status:** Accepted
**Date:** 2026-06-30
**Affects specs:** `sdd/auth/00_overview.md`, `sdd/auth/03_development.md`, `sdd/backend/09_backend_arch.md`

---

## Context

Every authenticated endpoint required a valid Supabase-issued JWT, verified via Supabase's JWKS endpoint (ES256). This meant:

- Backend-only development required internet access and a configured Supabase project
- The Swagger UI at `/docs` could not be used for authenticated endpoints without a Supabase account
- `AUTH_PROVIDER=mock` on the frontend issued opaque, non-JWT strings, incompatible with `USE_MOCK_DATA=false`

A local, dev-only way to obtain a verifiable token was needed, without weakening production verification.

## Decision

Add a dev-only `POST /api/v1/dev/token` endpoint that issues HS256 JWTs signed with `DEV_JWT_SECRET`, carrying `iss: "sentinel-dev"`. `get_current_user()` dispatches to the correct validator by peeking the `iss` claim (`_select_validator()`, unsigned peek, no trust placed in it) — `iss == "sentinel-dev"` routes to `_validate_dev_token()` (HS256 + `APP_ENV`/`ENABLE_DEV_AUTH` guards), anything else routes to `_validate_supabase_token()` (ES256/JWKS, unchanged from before). The dev router is only registered in `app/main.py` when `ENABLE_DEV_AUTH=True`.

## Alternatives Considered

- **Try-Supabase-then-fall-back-to-local** — attempt Supabase JWKS verification first, catch failure, retry against a local key. Rejected: every request pays a network round-trip (or timeout) against Supabase even in pure dev-only mode; also blurs the production code path with a fallback branch that must itself be proven safe.
- **Separate middleware per environment** (swap the entire auth middleware based on `APP_ENV`) — rejected as unnecessary abstraction for a single additional case; the codebase does not need multiple pluggable identity providers, only one additional path with strict guards.
- **`AUTH_PROVIDER=mock` issuing self-signed JWTs from the frontend** — considered (would let mock mode work against a real backend), rejected: requires embedding JWT-signing logic or long-lived pre-generated tokens in the Flutter bundle, a needless security surface for a UI-only development mode that doesn't need to reach a real backend.

## Consequences

- Backend-only development and Swagger UI testing work fully offline, with zero Supabase dependency, guarded by three independent layers (conditional router registration, endpoint-level guard, validator-level guard).
- `AUTH_PROVIDER=mock` remains explicitly UI-only (`USE_MOCK_DATA=true` only) — not extended to work against a real backend. Documented as an intentional constraint, not a gap.
- The `iss`-dispatch pattern is unreachable in production by construction: the dev router doesn't exist unless `ENABLE_DEV_AUTH=True`, which must never be set in Cloud Run/Secret Manager.
- Adding a future third identity provider would require one more branch in `_select_validator()` — acceptable, not designed for beyond that.

---

*Mined from `SENTINEL_AUTH_ARCHITECTURE_REVIEW.md` (Option C), archived per Phase 2 of the Sentinel Development Operating Model rollout — see `sdd/archive/`.*

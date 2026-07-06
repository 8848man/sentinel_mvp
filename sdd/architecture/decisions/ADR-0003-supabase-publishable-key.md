# ADR-0003: Use Supabase Publishable Key Format for the Frontend Client

**Status:** Accepted
**Date:** 2026-06 (approximate — predates formal ADR tracking; inferred from key format in use)
**Affects specs:** `sdd/auth/02_production.md`, `sdd/infra/11_deployment_spec.md`

---

## Context

The Flutter web client must ship a Supabase API key in its compiled JS bundle to initialize the Supabase Auth SDK (`SUPABASE_ANON_KEY` via `--dart-define`). Supabase offers two key families: the legacy long-lived JWT-format `anon` key, and the newer `sb_publishable_...` / `sb_secret_...` key pair introduced to reduce the risk of an `anon` and `service_role` key being confused or a `service_role` key being accidentally shipped client-side (both were previously opaque JWTs, differing only in an internal role claim).

## Decision

Use the newer `sb_publishable_...` key format (verified in `frontend/sentinel/.env` and historical `README.md` commits) rather than the legacy `anon` JWT key. No `sb_secret_...` or `service_role` key exists anywhere in the frontend or backend codebase (verified by repository-wide search during the prior security audit).

## Alternatives Considered

- **Legacy `anon` JWT key** — functionally equivalent for this app's needs, but the newer format's distinct `sb_publishable_`/`sb_secret_` prefixes make an accidental privileged-key leak into client code structurally harder to miss during review (the prefix itself signals which key it is, unlike two opaque JWTs distinguished only by an internal claim).

## Consequences

- No client code changes were required beyond using the new key value — `supabase_flutter`'s `Supabase.initialize(url:, anonKey:)` accepts either format transparently.
- Any future key rotation or key-type audit can grep for the `sb_publishable_`/`sb_secret_` prefixes directly, rather than having to decode a JWT to determine its role.
- This key is, by Supabase's own design, safe to embed in the compiled bundle and expose publicly — RLS (where applicable) and the backend's own JWT verification are the actual security boundary, not key secrecy. See `sdd/auth/02_production.md`.

---

*Backfilled during Phase 1 of the Sentinel Development Operating Model rollout. Predates ADR tracking; reconstructed from the key format already in use, not from a contemporaneous design discussion.*

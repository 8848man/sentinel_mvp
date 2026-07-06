# Authentication — Capability Overview

**Purpose:** Single source of truth for Sentinel's authentication model. All code and specifications that interact with identity, tokens, or session state must be consistent with this document. Any spec that describes authentication must reference this document rather than re-defining the model.

**Refs:** → [Contract](./01_contract.md) · [Production Auth](./02_production.md) · [Development Auth](./03_development.md)

---

## Supported Mechanisms

| Mechanism | Algorithm | Issued by | Environment | Status |
|-----------|-----------|-----------|-------------|--------|
| Supabase Auth | ES256 (JWKS) | Supabase | All | Active |
| Development JWT | HS256 (local secret) | `POST /api/v1/dev/token` | Development only | Active |
| Mock Auth | N/A (opaque strings) | `MockAuthRepository` | Frontend dev only | Active |

**Mock Auth tokens are not verifiable by the backend.** They exist for UI-only development (`USE_MOCK_DATA=true`) and must never be sent to the real backend. The combination `AUTH_PROVIDER=mock + USE_MOCK_DATA=false` is not supported.

---

## Security Principles

1. **Backend verifies, never issues** — in production, FastAPI validates tokens only. Supabase is the sole identity authority.
2. **JWKS-based key verification** — ES256 public keys are fetched from Supabase's JWKS endpoint at startup. No shared secrets exist in production.
3. **Stateless identity** — no server-side session storage. Every request carries a self-contained, verifiable JWT.
4. **Data isolation by `user_id`** — every DB read/write filters on `incident.user_id == current_user["user_id"]`. See [Production Auth §Ownership Enforcement](./02_production.md).
5. **Development auth is off by default** — `ENABLE_DEV_AUTH` defaults to `False`. Production deployments must not set this variable.

---

## Environment Model

```
Environment     AUTH_PROVIDER   Mechanism                    Token issuer            Backend validator
─────────────   ─────────────   ───────────────────────────  ──────────────────────  ─────────────────────
production      supabase        Supabase Auth (ES256)        Supabase                JWKS endpoint
development     supabase        Supabase Auth (ES256)        Supabase                JWKS endpoint (same)
development     dev             Dev JWT (HS256)              POST /api/v1/dev/token  Local HS256 secret *
frontend-only   mock            Mock Auth (opaque string)    MockAuthRepository      Not sent to backend

* Requires APP_ENV=development AND ENABLE_DEV_AUTH=True on the backend.
  Requires AUTH_PROVIDER=dev and SKIP_EMAIL_VERIFICATION=true on the frontend.
```

---

## Token Convention

All authenticated API requests carry:
```
Authorization: Bearer <jwt>
```

`get_current_user()` extracts identity from the token and returns `{"user_id": str, "email": str | None}`.  
`user_id` is the `sub` claim — a Supabase UUID in production, or a deterministic dev UUID in development.

**Token acquisition:** `api_client.dart` calls `authRepository.getAccessToken()` before each API call. Each `AuthRepository` implementation is responsible for its own token lifecycle, including refresh. See [Auth Contract §Token Attachment](./01_contract.md) for the full specification.

See [Auth Contract](./01_contract.md) for the full token format and claims specification.

---

## Supported Development Workflows

| Goal | `AUTH_PROVIDER` | `USE_MOCK_DATA` | Backend needed |
|------|-----------------|-----------------|----------------|
| Flutter UI dev, no backend | `mock` | `true` | No |
| Flutter + local FastAPI + SQLite | `dev` | `false` | Yes — `ENABLE_DEV_AUTH=True` |
| Flutter + Supabase dev project | `supabase` | `false` | Yes — real Supabase |
| Backend API dev (curl / `/docs`) | N/A | N/A | Yes — `ENABLE_DEV_AUTH=True` |
| Automated backend tests | N/A | N/A | In-process via `dependency_overrides` |

---

## Document Map

| Document | Audience | Contents |
|----------|----------|---------|
| [01_contract.md](./01_contract.md) | Backend + Frontend | Token format, required claims, AuthRepository interface, `getAccessToken()`, supported environment combinations |
| [02_production.md](./02_production.md) | Backend + Frontend | Supabase sign-up/in flows, ES256/JWKS verification, session lifecycle, ownership enforcement |
| [03_development.md](./03_development.md) | Backend + Frontend + DevOps | Validator dispatch architecture, dev token endpoint, DevAuthRepository, frontend refactoring, migration checklist |

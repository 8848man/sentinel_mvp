# Sentinel Authentication Architecture Review (Archived)

**Archived:** Its "Option C" recommendation was implemented and is now the authoritative, accepted design — see [ADR-0001](../architecture/decisions/ADR-0001-jwt-validator-dispatch.md) and [`sdd/auth/03_development.md`](../auth/03_development.md). This document is preserved for historical reasoning only; it is no longer a live evaluation and its "Status: Evaluation Only" line below is stale.

---

**Author:** Principal Software Architect / Backend Architect / Security Architect  
**Date:** 2026-06-30  
**Status:** Evaluation Only — No implementation work has been performed  
**Scope:** Authentication architecture across Flutter frontend, FastAPI backend, and Supabase Auth  

---

## Executive Summary

Sentinel's current authentication architecture is well-designed for production: externally-managed identity, ES256 JWT validation, JWKS-based key rotation, and a clean FastAPI dependency contract. The problems identified are entirely development-environment problems, not production architecture problems.

Authentication abstraction **is justified**, but the project has already gone approximately 70% of the way toward the correct solution. The Flutter `AuthRepository` interface already isolates authentication concerns cleanly. The FastAPI side has not followed the same pattern. The correct architectural direction is **not** a full provider abstraction on the backend — it is a targeted development JWT issuer that makes backend-only work self-contained, combined with completing the cleanup of dead code that was left over from a prior (now-deprecated) architecture.

The recommendation is: introduce a minimal backend development token endpoint, controlled by an explicit environment flag, never active in production. No full middleware abstraction is necessary or advisable.

---

## 1. Current Authentication Architecture Analysis

### 1.1 What the code actually shows

The backend authentication is implemented in a single module (`app/core/auth.py`, 78 lines). At module import time, `_make_jwks_client()` constructs a `PyJWKClient` pointing at `{SUPABASE_URL}/auth/v1/.well-known/jwks.json`. Every authenticated endpoint declares `Depends(get_current_user)`. `get_current_user` validates the Bearer token using ES256 and the JWKS endpoint, then returns `{"user_id": "<uuid>", "email": "<email>"}`.

The Flutter side is architecturally more mature. `AuthRepository` is an abstract interface with three concrete implementations:

| Implementation | Status | Purpose |
|----------------|--------|---------|
| `SupabaseAuthRepository` | Active, production | Real Supabase Auth flow |
| `MockAuthRepository` | Active, dev | In-process mock, no network, hardcoded accounts |
| `LocalBackendAuthRepository` | `@Deprecated` | Called a now-removed FastAPI token-issuance endpoint |

Provider selection happens at compile time via `--dart-define=AUTH_PROVIDER=supabase|mock|localBackend`. The `authRepositoryProvider` switches on the enum. The `api_client.dart` Dio interceptor calls `_resolveToken()`, which for `supabase` mode reads the live Supabase session, and for all other modes reads `authProvider.user?.accessToken` — which for `mock` mode is the hardcoded string `'mock.access.token.admin.sentinel.ai'`.

**Critical observation:** `MockAuthRepository` issues non-JWT strings as access tokens. Because the backend calls `_jwks_client.get_signing_key_from_jwt(token)` on every request, any request from a mock Flutter session to the real FastAPI backend will fail with 401. This means `AUTH_PROVIDER=mock` and `USE_MOCK_DATA=false` is a broken combination today. It is a structural gap, not a minor configuration issue.

### 1.2 Architectural Strengths (Production)

**Identity delegation is correct.** Sentinel does not manage credentials, password hashing, session state, token refresh, or email verification. These are delegated entirely to Supabase. This is the right call for a product at this stage.

**ES256 with JWKS is the right choice.** ES256 (ECDSA P-256) is cryptographically stronger than HS256. JWKS-based key delivery means that if Supabase rotates its signing key, the backend picks up the new key automatically on the next JWKS fetch without a deploy or config change. This is significantly better than a hardcoded `SUPABASE_JWT_SECRET`.

**Fail-fast at startup.** `_jwks_client = _make_jwks_client()` runs at module import time. If `SUPABASE_URL` is not configured, the process fails immediately with a clear message rather than serving 500s on the first authenticated request. This is correct operational practice.

**Thin dependency contract.** Every endpoint receives `{"user_id": str, "email": str}` from `get_current_user`. Endpoint code does not touch JWT internals. The entire authentication surface for a given endpoint is a single `Depends(get_current_user)` declaration. Swapping the verification mechanism requires changing only `auth.py`.

**Flutter abstraction is already correct.** `AuthRepository` is a clean interface. `SupabaseAuthRepository`, `MockAuthRepository`, and (the deprecated) `LocalBackendAuthRepository` all implement it. The `authRepositoryProvider` dispatches at compile time. Adding a new frontend auth implementation is a matter of adding a new class and a new switch case.

**No token issuance on the backend.** The comment in `auth.py` is explicit: "It does NOT issue tokens." This is a security strength. A backend that issues its own tokens in addition to verifying external ones introduces two attack surfaces and makes identity ambiguous.

### 1.3 Architectural Weaknesses (Development)

**Backend startup requires a live SUPABASE_URL.** `_make_jwks_client()` runs at import time and constructs a URL from `settings.SUPABASE_URL`. The resulting `PyJWKClient` is stateful and performs JWKS fetches lazily (on first token verification), not at construction. So starting the backend without a real `SUPABASE_URL` does not fail at startup — it fails at the first authenticated request. This is slightly misleading. More importantly, `SUPABASE_URL` must be set in the environment even when the developer has no intention of verifying any real Supabase tokens.

**Backend cannot be tested without a Supabase JWT.** The test suite works around this by overriding `get_current_user` with a `dependency_overrides` stub. This is correct for unit and integration tests, but it means any manual API testing (via curl, Postman, or `http://localhost:8000/docs`) requires a real Supabase token, which requires running the Flutter client through the full Supabase sign-in flow. The interactive docs at `/docs` cannot be used for authenticated endpoints without external tooling.

**`MockAuthRepository` tokens are not verifiable by the backend.** The strings in `mock_auth_accounts.dart` (`'mock.access.token.admin.sentinel.ai'`) are not JWTs. They cannot pass ES256 validation. This means `AUTH_PROVIDER=mock` with the real backend is silently broken. The developer who tries this combination gets 401 on every authenticated call and has to debug why.

**`LocalBackendAuthRepository` is deprecated but not removed.** The deprecated class still exists, is still referenced in the provider switch, and points at a `/api/v1/auth/login` endpoint that no longer exists. If a developer uses `AUTH_PROVIDER=localBackend`, the app compiles, runs, shows a login screen, and then fails at runtime with a network error to a non-existent endpoint. This is an active trap.

**Internet connectivity required for all backend work.** Because `SUPABASE_URL` must be configured and the JWKS endpoint is fetched on demand, any developer working on backend features that involve authentication needs internet access. Offline development is not possible for authenticated code paths.

**No viable path for CI against a real backend without secrets.** CI environments that run integration tests against the live backend (not the mocked ASGI tests in the existing test suite) must possess valid Supabase credentials. This introduces either a service-account credential (security concern) or a permanent Supabase dev project (operational concern and cost).

### 1.4 Why It Is Appropriate for Production

The current production flow is correct. Supabase is the identity authority. The backend verifies tokens without knowledge of credentials. ES256 with JWKS means key rotation is handled by Supabase transparently. The backend has no credential storage, no session management, and no token refresh logic. This minimizes the backend's security surface.

The `SKIP_EMAIL_VERIFICATION=False` guard on the dev-only register endpoint correctly prevents it from being callable in production. The `docs_url=None` in production disables interactive API documentation. These are correct production hardening choices.

### 1.5 Coupling Analysis

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ COUPLING MAP — Current Architecture                                          │
├──────────────────┬──────────────────────────────────────────────────────────┤
│ Flutter          │ Hard-coupled to Supabase SDK via SupabaseAuthRepository   │
│                  │ Decoupled via AuthRepository interface (✓ correct)        │
│                  │ MockAuthRepository does not produce valid JWTs (✗ gap)    │
├──────────────────┼──────────────────────────────────────────────────────────┤
│ FastAPI          │ Hard-coupled to Supabase JWKS at module import time       │
│                  │ No development bypass without dependency_overrides        │
│                  │ _jwks_client is a module-level singleton                  │
├──────────────────┼──────────────────────────────────────────────────────────┤
│ Tests            │ Decoupled via dependency_overrides (✓ correct)            │
│                  │ Tests never exercise real JWT verification path            │
├──────────────────┼──────────────────────────────────────────────────────────┤
│ CI               │ Requires SUPABASE_URL even for non-JWT tests             │
│                  │ (because conftest.py must set it before app.* imports)    │
└──────────────────┴──────────────────────────────────────────────────────────┘
```

The Flutter coupling is well-managed. The FastAPI coupling is the problem: a single module-level singleton ties every server startup to the Supabase URL. There is no seam to insert an alternative for development.

### 1.6 Long-Term Maintainability

The current design is maintainable at production scale. `auth.py` is small, focused, and well-commented. The FastAPI dependency system means any future change (e.g., adding role claims, supporting multiple identity providers) requires changing only this module and the contract it returns.

The maintainability concern is the dead code and broken combination documented above. `LocalBackendAuthRepository` is `@Deprecated` but still in the switch statement. The `localBackend` `AuthProviderMode` enum value still exists. The combination `AUTH_PROVIDER=mock + USE_MOCK_DATA=false` is silently broken. These are maintenance debt items that must be cleaned up regardless of whether any new abstraction is introduced.

---

## 2. Is Authentication Abstraction Actually Necessary?

### 2.1 Framing the Question Correctly

The question "is authentication abstraction necessary?" is more precisely stated as: "which specific problems need to be solved, and is abstraction the minimum sufficient solution?"

**Problems that are real and need solving:**

1. Backend API cannot be manually tested (curl/docs) without a real Supabase JWT.
2. `AUTH_PROVIDER=mock + USE_MOCK_DATA=false` is a silently broken combination.
3. `LocalBackendAuthRepository` is deprecated but not cleaned up.
4. `SUPABASE_URL` must be set in `.env` even when Supabase is not being used.

**Problems that are already solved:**

1. Test isolation: the existing `dependency_overrides` pattern already solves this correctly for the automated test suite.
2. Frontend abstraction: `AuthRepository` already exists and is correctly designed.

**Problems that are overstated:**

1. "Internet connectivity required." In practice, `PyJWKClient` caches JWKS responses. After the first fetch, subsequent token verifications do not hit the network unless the cache expires. The dependency on connectivity exists at first token verification, not continuously.

### 2.2 Objective Evaluation

**Is abstraction justified?** Partially. The Flutter side already has the right abstraction. The backend needs a narrower change: a way to obtain a verifiable Bearer token for local development without going through Supabase. Full middleware abstraction is not necessary to achieve this.

**Is this introducing unnecessary complexity?** A full `IAuthProvider` / `CurrentUserResolver` abstraction with multiple implementations on the backend introduces more complexity than the problem warrants. The backend authentication surface is a single 78-line module and a single FastAPI dependency. Adding a two-implementation abstract interface for this boundary adds two new classes, an interface, and a factory, to solve a problem that could be solved by a single new endpoint and an environment flag.

**Does it improve developer productivity?** Yes, but the productivity gain can be achieved with a smaller change than a full abstraction. A developer who can `curl -X POST /api/v1/dev/token -d '{"email": "dev@sentinel.ai"}'` and receive a real ES256 JWT (signed by a local key) has the same productivity benefit as full abstraction with less complexity.

**Does it improve testability?** The existing `dependency_overrides` pattern already provides full testability. Authentication abstraction does not improve the automated test suite.

**Does it improve maintainability?** A minimal change (one new endpoint, one environment flag, one code path) is more maintainable than a full abstraction layer. Every new abstraction boundary is a maintenance burden: it requires consistent implementation in all concrete classes, documentation, and testing of the dispatch mechanism itself.

**Are there simpler alternatives?** Yes. See Section 3.

### 2.3 Verdict

Authentication abstraction in the sense of `IAuthProvider` with multiple backend implementations is **not the right design for the backend**. It is architecturally over-engineered for the problem at hand.

The correct approach is:
- A development-only JWT issuer endpoint (producing real ES256 or HS256 tokens) controlled by `APP_ENV != production`.
- Cleanup of the dead `LocalBackendAuthRepository` code path.
- A fix to `MockAuthRepository` so that its `accessToken` values are either valid JWTs (for the `USE_MOCK_DATA=false` combination) or the documentation clearly states the combination is unsupported.

---

## 3. Evaluation of Architectural Options

### Option A: Full Authentication Provider Abstraction (Backend)

```
                         ┌──────────────────────────┐
                         │  ICurrentUserResolver    │
                         └───────────┬──────────────┘
                                     │  implements
               ┌─────────────────────┼─────────────────────┐
               │                                           │
  ┌────────────▼─────────────┐           ┌────────────────▼────────────┐
  │  SupabaseJWTResolver     │           │  LocalDevelopmentResolver   │
  │  (verifies JWKS)         │           │  (validates dev tokens)     │
  └──────────────────────────┘           └─────────────────────────────┘
```

The FastAPI `get_current_user` dependency becomes an abstract call dispatched to one of these implementations based on configuration.

**Advantages:**
- Clean conceptual separation.
- Adding a third identity provider (e.g., Auth0) requires only a new implementation.
- Mirrors the existing Flutter architecture.

**Disadvantages:**
- Adds 2–4 new classes and an interface for a boundary that has never needed to change in Sentinel's history.
- The FastAPI dependency injection system does not natively support runtime polymorphism through Python abstract classes; the dispatch must be done manually (factory function or conditional import).
- Each new implementation must handle: key fetching or storage, token validation, claim extraction, error mapping, and timeout handling. This is non-trivial to keep consistent.
- Increases the complexity of `auth.py` from 78 lines to 150+ lines with supporting modules.
- If the dispatch is environment-variable-driven at startup (not compile-time like Flutter), there is a risk that a misconfigured deployment runs the wrong resolver.

**Implementation complexity:** Medium-high  
**Maintainability:** Lower than the current single-module design  
**Production safety:** Acceptable if the guard is implemented correctly, but more surface area means more risk  
**Development experience:** Good once implemented  
**Verdict:** Over-engineered. The abstraction buys flexibility Sentinel does not need.

---

### Option B: JWT Validator Abstraction (Backend)

A narrower version of Option A: keep `get_current_user` as the single FastAPI dependency, but make the JWT validation strategy pluggable at the validator level rather than the resolver level.

```python
class JWTValidator(Protocol):
    async def validate(self, token: str) -> dict: ...

# Two implementations:
# SupabaseJWTValidator  — JWKS fetch, ES256
# LocalJWTValidator     — local HMAC secret, HS256
```

`get_current_user` calls `_validator.validate(token)` where `_validator` is selected at startup.

**Advantages:**
- Smaller interface than Option A — only one method.
- The dispatch is inside `auth.py` and does not leak into every router.
- Easier to test each validator implementation independently.

**Disadvantages:**
- Still adds a Protocol/interface and a factory for what is essentially two `if` branches.
- The local validator must store or generate a signing key, which introduces a new secret management concern (even if it is dev-only).
- The dispatch logic at startup must be protected against accidental production activation.

**Implementation complexity:** Medium  
**Maintainability:** Better than Option A, marginal improvement over current  
**Production safety:** Acceptable  
**Development experience:** Good  
**Verdict:** Architecturally cleaner than Option A but still more complex than necessary. Consider as the design if more than one future identity provider is plausible.

---

### Option C: Local Development Authentication (Recommended — Backend)

Introduce a single development-only endpoint that issues a verifiable JWT:

```
POST /api/v1/dev/token
Body: { "email": "dev@sentinel.ai", "user_id": "<optional-uuid>" }
Response: { "access_token": "<signed-jwt>", "token_type": "bearer" }
```

The token is signed with a locally-generated or configured HMAC secret (HS256) or a locally-generated ECDSA key pair (ES256). The backend's `get_current_user` dependency checks the environment:

- In production (`APP_ENV=production`): validates only against Supabase JWKS, exactly as today.
- In development (`APP_ENV=development` or `APP_ENV=test`): validates against either Supabase JWKS or the local signing key, accepting either.

The "accept either" logic is implemented as a try-Supabase-then-try-local fallback, or the development endpoint's tokens use a distinguishable `iss` (issuer) claim that routes the validation to the correct path.

```
Developer flow (no Supabase):
  curl POST /api/v1/dev/token → receives JWT
  curl -H "Authorization: Bearer <jwt>" GET /api/v1/incidents → 200 OK

Production flow (unchanged):
  Flutter → Supabase → JWT → FastAPI JWKS validation → 200 OK
```

**Advantages:**
- Produces real JWTs. Works with the Swagger UI at `/docs`. Works with curl. Works with any HTTP client.
- No change to any existing production code path.
- Does not require a Flutter change to work — a backend developer can test the API entirely with curl.
- Works offline (after the local key is generated once at startup).
- Simple to implement: one new endpoint, one new environment guard, 40–60 lines of code.
- No new abstractions, no new interfaces, no new dispatch logic.
- Can be used by the MockAuthRepository fix (see Section 3, Option E).

**Disadvantages:**
- The development endpoint must be rigorously guarded against production activation. A single misconfigured `APP_ENV` exposes unauthenticated token issuance.
- The local signing key must be stored somewhere (env var `DEV_JWT_SECRET` or auto-generated ephemeral key). If ephemeral, tokens issued before a restart become invalid — acceptable for development, confusing if not documented.
- Does not cleanly extend to multiple future identity providers (but Sentinel does not need this now).

**Implementation complexity:** Low  
**Maintainability:** High — minimal new code, no new abstractions  
**Scalability:** Irrelevant (dev-only)  
**Production safety:** High if guarded by `APP_ENV` check, acceptable  
**Development experience:** Excellent — all HTTP tools work, no Flutter required  
**Verdict:** This is the recommended backend change. See Section 8.

---

### Option D: Frontend Authentication Provider Separation

The Flutter side already implements this correctly (`AuthRepository` interface + three implementations + provider switch). The remaining work is:

1. Delete `LocalBackendAuthRepository` (deprecated, calls a non-existent endpoint).
2. Remove `AuthProviderMode.localBackend` from the enum and provider switch.
3. Fix `MockAuthRepository` so its `accessToken` values are valid JWTs when `USE_MOCK_DATA=false`.

**The fix for item 3** is the key insight: the Flutter mock system can either:
  - (a) Generate real JWTs signed with the development secret that Option C introduces.
  - (b) Accept that `AUTH_PROVIDER=mock` is only compatible with `USE_MOCK_DATA=true` (fully mocked backend) and document this constraint explicitly.

Option (b) is simpler and probably the right call. `AUTH_PROVIDER=mock` is a frontend-only development mode. If a developer wants to test against the real backend, they should use `AUTH_PROVIDER=supabase` with a real Supabase dev project, or use curl with tokens from the new dev endpoint.

**Advantages:**
- Eliminates dead code.
- Clarifies the supported combinations.
- No new abstractions.

**Disadvantages:**
- Removing `localBackend` is a breaking change for any developer currently using `AUTH_PROVIDER=localBackend`. (Low risk given the `@Deprecated` annotation already signals this.)

**Implementation complexity:** Very low (deletion + documentation)  
**Maintainability:** Improves significantly by removing dead code  
**Verdict:** Should be done regardless of what else is decided.

---

### Option E: Mock Authentication Layer (Hybrid)

Generate valid JWTs inside `MockAuthRepository` using the development secret from Option C. The `accessToken` stored in `kMockAuthAccounts` would be a real HS256 JWT with the expected claims (`sub`, `email`, `aud: "authenticated"`), signed with `DEV_JWT_SECRET`.

This makes `AUTH_PROVIDER=mock + USE_MOCK_DATA=false` a valid, working combination.

```
MockAuthRepository.signIn() →
  AuthUser(accessToken: _issueJWT(account.userId, account.email))

_issueJWT() signs with DEV_JWT_SECRET (same secret as the backend's dev endpoint)
```

**Advantages:**
- Completes the mock system. Developers can work on the Flutter UI against the real backend without a Supabase account.
- The backend does not need to know about Flutter mock mode at all.

**Disadvantages:**
- Requires the Flutter app to embed JWT signing logic (or the dev tokens to be hardcoded pre-generated JWTs with a long expiry).
- Pre-generated tokens expire. Hardcoded long-lived tokens are a security risk if the development secret leaks.
- Adds JWT library dependency to Flutter (or requires pre-generated static tokens with a very long `exp`).

**Verdict:** Option (b) from Option D (documenting the unsupported combination) is simpler. If the mock+real-backend combination turns out to be genuinely needed, Option E is the right approach, using pre-generated tokens with a fixed long expiry signed by a known dev secret.

---

### Option F: Architecture-Level Recommendation Summary

No single option above is ideal in isolation. The recommended architecture combines:

- **Option C** (dev token endpoint on the backend)
- **Option D** (frontend cleanup)
- **Selected elements of Option E** only if mock+real-backend is a required combination

Avoid:

- **Option A** — unnecessary abstraction complexity
- **Option B** — justifiable but premature; revisit only if a second production identity provider is actually planned

---

### Option Comparison Table

| Criterion | A: Full Abstraction | B: JWT Validator | C: Dev Endpoint | D: FE Cleanup | E: Mock JWT |
|-----------|--------------------:|----------------:|---------------:|-------------:|------------:|
| Implementation complexity | High | Medium | Low | Very low | Low |
| New files/classes | 4+ | 2–3 | 1 endpoint | 0 new | 1 utility |
| Breaks existing tests | No | No | No | No | No |
| Production code changed | Yes | Yes | No | No | No |
| Covers curl/docs use case | Yes | Yes | Yes | No | No |
| Covers offline backend dev | Yes | Yes | Yes | No | No |
| Enables mock+real-backend | Indirectly | Indirectly | With E | No | Yes |
| Dead code cleaned up | No | No | No | Yes | No |
| Over-engineered | Yes | Slightly | No | No | No |

---

## 4. Development Authentication Design Considerations

This section evaluates what a development authentication system (Option C) would need to address.

### 4.1 JWT Generation

A development token endpoint must produce tokens that:

- Are structurally valid JWTs (header + payload + signature, Base64URL-encoded).
- Use a consistent algorithm. HS256 is appropriate for development: it requires only a shared secret, produces smaller tokens, and is simpler to implement than ES256 (no key pair management).
- Carry the same claims that the backend expects from Supabase tokens: `sub` (UUID), `email`, `aud: "authenticated"`, `iss`, `iat`, `exp`.
- Have a reasonable expiry (e.g., 24 hours for development convenience). Supabase tokens expire in 1 hour; development tokens can be longer-lived without meaningful security risk since they only work in development environments.

The backend's `get_current_user` must be extended to accept HS256 tokens signed by the development secret when `APP_ENV != production`. The HS256 path must be tried only after the ES256/JWKS path fails (or the `iss` claim routes to the correct validator). If the HS256 path is tried before JWKS, it could interfere with production token validation if `APP_ENV` is misconfigured.

**Recommended issuer claim:** `iss: "sentinel-dev"` — distinguishable from Supabase's issuer, enabling unambiguous routing without fallback logic.

### 4.2 Identity Management in Development

Development tokens should carry user identities that match rows in the local `users` table. The existing `POST /api/v1/auth/register` endpoint already creates user rows for development. The token endpoint should accept a `user_id` or derive it from the `email` (using the same `_user_id_for(email)` deterministic UUID function already in the codebase).

This means the development flow is:
1. `POST /api/v1/auth/register` (email + password) → creates User row
2. `POST /api/v1/dev/token` (email) → issues JWT with matching `sub`
3. All authenticated API calls work

### 4.3 Production Safety Mechanisms

The development endpoint must be protected by multiple independent guards:

**Guard 1 — Environment check (runtime):**
```python
if settings.APP_ENV == "production":
    raise HTTPException(403, "Not available in production")
```

**Guard 2 — Explicit feature flag:**
```python
if not settings.ENABLE_DEV_AUTH:  # defaults to False
    raise HTTPException(403, "Dev auth is not enabled")
```

Two independent guards prevent misconfiguration from exposing the endpoint. Both must be True for the endpoint to respond. A production deployment that accidentally has `APP_ENV=development` would still be blocked by the second guard.

**Guard 3 — Algorithm separation:**  
Use `iss: "sentinel-dev"` in development tokens. The production validation path (ES256/JWKS) never processes tokens with this issuer. The development validation path (HS256/local secret) never runs when `APP_ENV=production`.

**Guard 4 — Logging:**  
Every token issuance should be logged at INFO level. An unexpected token-issuance log in a production environment is an immediate signal of misconfiguration.

### 4.4 Signing Key Management

The development JWT signing secret should:

- Be set via `DEV_JWT_SECRET` environment variable.
- Default to a fixed well-known development secret if not set (acceptable for development, since this secret is only valid in development environments by design).
- Never be used in production (enforced by guard above).
- Be documented as a development-only secret in `.env.example`.

An ephemeral auto-generated key (re-generated on each startup) is an alternative but causes all issued tokens to become invalid on server restart — a confusing development experience.

### 4.5 CI Integration

For CI environments running integration tests against the backend:

- The existing `dependency_overrides` pattern already handles automated test isolation correctly and requires no change.
- If a future E2E test suite needs to authenticate against the running server, the dev token endpoint provides a clean mechanism: the CI job calls `POST /dev/token` to obtain a JWT, then uses it in E2E HTTP calls.
- No Supabase credentials are needed in CI.

### 4.6 Differences Between Development and Production Authentication

| Aspect | Development | Production |
|--------|------------|------------|
| Token issuer | Sentinel backend | Supabase Auth |
| Algorithm | HS256 | ES256 |
| Key management | Single shared secret | JWKS / key rotation |
| Token refresh | Not supported | Supabase handles |
| Email verification | Not required | Required |
| Token expiry | Long (24h) | Short (1h) |
| Social login | Not supported | Supabase supports |
| MFA | Not supported | Supabase supports |
| Audit trail | Backend logs | Supabase dashboard |

Developers must understand that development tokens exercise the authorization layer (user_id-based data isolation) but do not exercise the actual authentication mechanisms (ES256, JWKS, token refresh). Tests of the authentication mechanism itself require either a real Supabase account or future test-mode configuration in the test suite.

---

## 5. Project-Wide Impact Analysis

### 5.1 FastAPI Backend

| Component | Change Required | Invasiveness |
|-----------|----------------|-------------|
| `app/core/auth.py` | Add HS256 path for `iss: "sentinel-dev"` tokens | Low — ~20 lines |
| `app/core/config.py` | Add `ENABLE_DEV_AUTH: bool = False` | Very low — 1 line |
| `app/routers/auth.py` | Add `POST /dev/token` endpoint | Low — ~30 lines |
| All other routers | No change | None |
| All services | No change | None |
| All models | No change | None |
| Tests | No change (dependency_overrides still correct) | None |

Total backend impact: ~50–80 lines of new code, no changes to existing production paths.

### 5.2 Flutter Frontend

| Component | Change Required | Invasiveness |
|-----------|----------------|-------------|
| `LocalBackendAuthRepository` | Delete | Reduces codebase |
| `AuthProviderMode` enum | Remove `localBackend` | Very low |
| `authRepositoryProvider` | Remove `localBackend` case | Very low |
| `AppConfig` | Keep as-is or update comments | None |
| `MockAuthRepository` | Clarify unsupported combinations or fix tokens | Very low |
| `api_client.dart` | No change | None |
| `SupabaseAuthRepository` | No change | None |

Total frontend impact: deletion of ~100 lines of dead code, minor comment updates.

### 5.3 Testing Impact

The existing test suite requires zero changes. The `dependency_overrides` pattern for `get_current_user` is the correct way to test authenticated endpoints and is not affected by any of the proposed changes.

### 5.4 CI/CD Impact

Negligible. Current CI uses `pytest` with `dependency_overrides`. This continues unchanged. If E2E tests against the running server are added in the future, the dev token endpoint provides the mechanism they need.

### 5.5 Deployment Impact

None for production. The dev token endpoint is guarded and inactive in production. `ENABLE_DEV_AUTH` defaults to `False` and is not set in any production environment configuration.

### 5.6 Infrastructure Impact

None. No new services, no new databases, no new secrets management requirements for production.

---

## 6. Refactoring Scope

### 6.1 Modules Requiring Modification

**Backend:**
- `app/core/auth.py` — add development token validation branch (~20 lines)
- `app/core/config.py` — add `ENABLE_DEV_AUTH` and `DEV_JWT_SECRET` settings (~3 lines)
- `app/routers/auth.py` — add `POST /dev/token` endpoint (~30 lines)
- `.env.example` — document new variables

**Frontend:**
- `lib/features/auth/data/repositories/local_backend_auth_repository.dart` — delete
- `lib/features/auth/data/providers/auth_repository_provider.dart` — remove `localBackend` case
- `lib/core/config/app_config.dart` — remove `localBackend` enum value

### 6.2 New Interfaces

None required. The recommendation deliberately avoids new interfaces.

### 6.3 New Abstractions

None. The dev token endpoint is a concrete endpoint with concrete guards, not an abstraction.

### 6.4 Obsolete Code

- `LocalBackendAuthRepository` (Flutter) — delete
- `AuthProviderMode.localBackend` enum value — delete

### 6.5 Migration Effort

Two days of development work:
- Day 1: backend changes (auth.py, config.py, auth router, tests for new endpoint)
- Day 2: frontend cleanup + documentation + verification

### 6.6 Compatibility

Fully backward-compatible. All existing production behavior is unchanged. All existing test infrastructure is unchanged. The Flutter `AUTH_PROVIDER=supabase` (default) path is unchanged. The `AUTH_PROVIDER=mock` path behavior is unchanged (still produces mock tokens that only work with `USE_MOCK_DATA=true`).

---

## 7. Risk Assessment

### 7.1 Authentication Bypass Risk

**Risk:** The development token endpoint, if activated in production, would allow unauthenticated callers to issue themselves arbitrary JWTs with any `user_id`.

**Severity:** Critical if activated in production.

**Mitigation:**
- Two independent runtime guards (`APP_ENV == "production"` and `ENABLE_DEV_AUTH=False` default).
- Algorithm and issuer separation (`iss: "sentinel-dev"`, HS256) means development tokens cannot be mistaken for Supabase tokens.
- Explicit documentation of the dual-guard requirement.
- The endpoint must be included in security review checklists for production deployments.

**Residual risk:** Low. The dual-guard pattern is standard practice (e.g., Django's `DEBUG=False` + `ALLOWED_HOSTS`). The risk is not eliminated but is well-understood and manageable.

### 7.2 Accidental Production Exposure

**Risk:** `APP_ENV` is misconfigured to `development` in a production Cloud Run deployment.

**Current state:** This risk already exists for the `/api/v1/auth/register` endpoint, which uses the same `SKIP_EMAIL_VERIFICATION` guard pattern. The proposed change does not introduce a new risk category.

**Mitigation:** The second guard (`ENABLE_DEV_AUTH`) must not be set in production environment configurations. Cloud Run environment variables should be reviewed as part of the deployment checklist.

**Residual risk:** Low-medium. Dependent on deployment discipline.

### 7.3 Increased Complexity

**Risk:** The new code path in `auth.py` increases cognitive load for maintainers.

**Assessment:** Minimal. A clearly documented `if APP_ENV != "production" and settings.ENABLE_DEV_AUTH` branch followed by HS256 validation is not complex. The branch is isolated and does not interfere with the production path.

**Risk level:** Very low.

### 7.4 Technical Debt

**Risk:** The development endpoint remains in the codebase indefinitely, accumulating entropy.

**Assessment:** This risk is mitigated by the explicit `APP_ENV` guard and clear documentation. Compare to the existing `auth/register` endpoint: it has been in the codebase as a dev-only endpoint without causing confusion because it is well-commented and guarded.

**Risk level:** Low.

### 7.5 Full Abstraction Risk (If Option A Is Chosen Instead)

If the decision is made to implement a full `IAuthProvider` abstraction despite the recommendation against it, the following additional risks apply:

- **Interface drift:** Over time, `SupabaseAuthProvider` and `LocalAuthProvider` may diverge in behavior in ways that are not caught by tests.
- **Debug complexity:** When authentication fails, the developer must determine which provider is active and trace through the dispatch mechanism.
- **Testing coverage gap:** Each concrete implementation must be independently tested. The existing test suite tests neither implementation (it overrides `get_current_user` directly). New tests must be written for both.
- **Abstraction leakage:** Claims available from Supabase (e.g., social login metadata, role claims) may not be present in development tokens, causing downstream code to fail differently in development vs. production.

---

## 8. Recommended Architecture

### 8.1 Recommendation

**Adopt a minimal development JWT endpoint. Do not introduce a full authentication provider abstraction.**

The recommended architecture makes one targeted change to the backend (a development token endpoint), performs cleanup of dead Flutter code, and leaves all production code paths unchanged.

### 8.2 Recommended Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PRODUCTION FLOW (unchanged)                          │
│                                                                               │
│  Flutter ──► Supabase Auth ──► ES256 JWT ──► FastAPI JWKS Validation ──► DB │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                    DEVELOPMENT FLOW (new, backend-only)                       │
│                                                                               │
│  curl/docs ──► POST /api/v1/dev/token ──► HS256 JWT (iss:sentinel-dev)       │
│                          │                                                    │
│                          ▼ (guarded: APP_ENV≠production AND ENABLE_DEV_AUTH) │
│  FastAPI ──► check iss claim ──► HS256 validation ──► DB                    │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                    TEST FLOW (unchanged, already correct)                     │
│                                                                               │
│  pytest ──► dependency_overrides[get_current_user] ──► fixed dict ──► DB    │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                    FLUTTER MOCK FLOW (clarified)                              │
│                                                                               │
│  AUTH_PROVIDER=mock + USE_MOCK_DATA=true: fully in-process, no backend      │
│  AUTH_PROVIDER=supabase + USE_MOCK_DATA=false: production flow, dev project  │
│  AUTH_PROVIDER=localBackend: DELETED (was deprecated, endpoint removed)      │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 8.3 Modified `get_current_user` Logic

```
get_current_user(token):
  if token.iss == "sentinel-dev":
    if APP_ENV == "production":
      reject (401)   ← guard 1
    if not ENABLE_DEV_AUTH:
      reject (401)   ← guard 2
    validate HS256 with DEV_JWT_SECRET
    return {user_id, email}
  else:
    validate ES256 via JWKS (current behavior, unchanged)
    return {user_id, email}
```

The claim check (`iss`) routes the token to the correct validation path without fallback retry logic. If the `iss` claim is absent or mismatched, the JWKS path handles it as today.

### 8.4 Why This Recommendation Best Balances the Criteria

| Criterion | Assessment |
|-----------|-----------|
| Developer productivity | High — curl, `/docs`, and any HTTP tool work immediately without Supabase |
| Maintainability | High — ~50 new lines total, no new abstractions, no new interfaces |
| Security | Dual-guarded, algorithm-separated, production path unchanged |
| Scalability | Not applicable (dev-only feature) |
| Operational safety | High — default-off flag, production flag blocks it independently |
| Test impact | Zero — no changes to test infrastructure |
| Flutter impact | Positive — removes dead code |
| Future flexibility | Preserved — if a full abstraction is ever needed, the `iss`-based routing is a stepping stone |

### 8.5 Approaches to Avoid

**Do not implement full backend authentication provider abstraction (Option A).** The added complexity — 4+ new classes, an interface, a factory, consistent implementation of all authentication concerns across multiple providers — is disproportionate to the problem of "developers need to test their API without a Supabase account."

**Do not attempt to make `AUTH_PROVIDER=mock` work with `USE_MOCK_DATA=false` as a first-class supported combination.** This requires JWT signing in the Flutter app (a dependency boundary that shouldn't exist for UI-only mock mode) or hardcoded pre-signed tokens with an expiry date that will eventually cause confusion. The combination is unsupported today and should be documented as such.

**Do not keep `LocalBackendAuthRepository` in the codebase.** It is `@Deprecated`, it calls a non-existent endpoint, and it is a trap for any developer who reads the code or uses `AUTH_PROVIDER=localBackend`. Remove it.

### 8.6 Implementation Sequence

If implementation is approved, the recommended sequence is:

1. **Delete dead code** (`LocalBackendAuthRepository`, `AuthProviderMode.localBackend`) — zero risk, reduces confusion immediately.
2. **Add config settings** (`ENABLE_DEV_AUTH`, `DEV_JWT_SECRET`) — non-functional, establishes the configuration foundation.
3. **Add `POST /dev/token` endpoint** — blocked by dual guard, cannot be accidentally activated.
4. **Extend `get_current_user`** to recognize `iss: "sentinel-dev"` and route to HS256 validation.
5. **Add tests** for both the new endpoint and the new validation path in `get_current_user`.
6. **Update documentation** — `.env.example`, development setup guide.

Each step is independently reviewable and reversible. No step modifies any existing production code path.

---

## Appendix A: Authentication Flow Diagrams

### Current Production Flow

```
┌──────────┐      (1) signIn(email, pw)     ┌──────────────────┐
│          │ ─────────────────────────────► │                  │
│  Flutter │                                │  Supabase Auth   │
│          │ ◄───────────────────────────── │                  │
└──────────┘  (2) Session { accessToken }   └──────────────────┘
     │
     │ (3) GET /incidents
     │     Authorization: Bearer <accessToken>
     ▼
┌──────────┐  (4) GET {SUPABASE_URL}/auth/v1/.well-known/jwks.json
│          │ ─────────────────────────────► ┌──────────────────┐
│  FastAPI │                                │  Supabase JWKS   │
│          │ ◄───────────────────────────── │  Endpoint        │
└──────────┘  (5) { keys: [{alg:ES256}] }  └──────────────────┘
     │
     │ (6) ES256 verify(token, key)
     │     → { user_id: "uuid", email: "..." }
     ▼
┌──────────┐
│    DB    │
└──────────┘
```

### Proposed Development Flow (Addition Only)

```
┌──────────────┐  POST /api/v1/dev/token   ┌─────────────────────────────┐
│  curl / docs │ ────────────────────────► │ FastAPI                     │
│  Flutter     │  { email: "dev@..." }     │                             │
│  (dev mode)  │                           │ GUARD 1: APP_ENV ≠ prod     │
│              │ ◄──────────────────────── │ GUARD 2: ENABLE_DEV_AUTH    │
└──────────────┘  { access_token: <jwt> }  │                             │
                                           │ Issues HS256 JWT:           │
                                           │  iss: "sentinel-dev"        │
                                           │  sub: <user_id>             │
                                           │  exp: now + 24h             │
                                           └─────────────────────────────┘

┌──────────────┐  GET /incidents           ┌─────────────────────────────┐
│  curl / docs │ ────────────────────────► │ FastAPI get_current_user    │
│              │  Bearer <hs256-jwt>       │                             │
│              │                           │ iss == "sentinel-dev"?      │
│              │                           │   YES → HS256 validation    │
│              │                           │   NO  → JWKS / ES256        │
│              │ ◄──────────────────────── │                             │
└──────────────┘  200 OK                   └─────────────────────────────┘
```

### Flutter Authentication Provider Selection (Post-Cleanup)

```
                    compile time
                  --dart-define=AUTH_PROVIDER=?

                           │
              ┌────────────┴────────────┐
              │                         │
           "mock"                   "supabase" (default)
              │                         │
              ▼                         ▼
   MockAuthRepository       SupabaseAuthRepository
   (in-process only)        (real Supabase Auth)
   USE_MOCK_DATA=true        USE_MOCK_DATA=false
   (no backend calls)        (real backend calls)
   (access token:            (access token:
    non-JWT string,           real ES256 JWT,
    only works with           verifiable by FastAPI
    mock data layer)          JWKS validation)
```

---

## Appendix B: Current State Inventory

| Item | State | Action Required |
|------|-------|-----------------|
| `app/core/auth.py` | Production-ready | Add dev token validation branch |
| `app/routers/auth.py` | Partially production | Add `POST /dev/token` endpoint |
| `app/core/config.py` | Production-ready | Add `ENABLE_DEV_AUTH`, `DEV_JWT_SECRET` |
| `AuthRepository` (Flutter) | Well-designed | No change |
| `SupabaseAuthRepository` | Production-ready | No change |
| `MockAuthRepository` | Works for mock-only mode | Clarify unsupported combinations |
| `LocalBackendAuthRepository` | Dead code, deprecated | Delete |
| `AuthProviderMode.localBackend` | Dead enum value | Delete |
| `mock_auth_accounts.dart` | Non-JWT access tokens | Document limitation |
| `auth_repository_provider.dart` | Has dead `localBackend` case | Remove case |
| Test suite auth override | Correct | No change |
| Production token validation | Correct | No change |

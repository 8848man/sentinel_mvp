# Authentication Contract

**Purpose:** Defines the interface between Flutter and FastAPI for authentication. Both the frontend and backend must satisfy this contract regardless of which authentication mechanism is active in the current environment.

**Refs:** → [Auth Overview](./00_overview.md) · [Production Auth](./02_production.md) · [Development Auth](./03_development.md)

---

## AuthUser Entity

```dart
class AuthUser {
  final String id;           // User UUID (= JWT sub claim)
  final String email;        // User email address
  final String accessToken;  // JWT satisfying the Token Format below
  final String refreshToken; // Provider-managed refresh credential — internal to the repository; never sent to FastAPI directly
}
```

`refreshToken` is managed exclusively by the provider's `AuthRepository` implementation. No other layer should read or store it. `DevAuthRepository` and `MockAuthRepository` store an empty string for this field — they do not use it.

---

## Token Format

Every authenticated API request must carry:

```
Authorization: Bearer <token>
```

The token must be a valid JWT with the following claims:

| Claim | Type | Required | Value |
|-------|------|----------|-------|
| `sub` | string | Yes | User UUID — Supabase user ID in production; deterministic dev UUID in development |
| `email` | string | No | User email address |
| `aud` | string | Yes | `"authenticated"` |
| `iss` | string | Yes | Supabase project URL (production) OR `"sentinel-dev"` (development) |
| `iat` | number | Yes | UNIX timestamp — token issue time |
| `exp` | number | Yes | UNIX timestamp — must not be in the past |

The `iss` claim is how `get_current_user()` routes the token to the correct validator. Frontend code must not manipulate or set this claim.

---

## Token Attachment

`api_client.dart` (Dio interceptor) is responsible for obtaining a valid token and attaching it as `Authorization: Bearer <token>` to every API request. It calls `authRepository.getAccessToken()` — not `getSignedInUser()` — to ensure the token is refreshed if needed before each call.

When `getAccessToken()` returns `null` (no active session), the interceptor must not add an `Authorization` header. Unauthenticated requests reach the backend and fail with `403` from `HTTPBearer`.

`AuthRepository` implementations must not set HTTP headers directly.

---

## Backend Response Contract

On successful authentication, `get_current_user()` returns:

```python
{"user_id": str, "email": str | None}
```

`user_id` is the value of the JWT `sub` claim. All downstream DB queries filter on this value.

On failure, FastAPI returns the following JSON body:

```json
{ "detail": "<message string>" }
```

| Condition | HTTP status | `detail` |
|-----------|-------------|----------|
| Missing / malformed `Authorization` header | 403 | FastAPI `HTTPBearer` default |
| Expired token | 401 | `"Token expired"` |
| Invalid signature or claims | 401 | `"Invalid token"` |
| Dev auth route called when disabled | 403 | `"Dev auth is disabled"` |
| Dev token: password provided but wrong | 401 | `"Invalid credentials"` |
| Dev token: email not found | 404 | `"User not found"` |

---

## Frontend Responsibilities (AuthRepository)

Flutter must implement `AuthRepository` (`lib/features/auth/domain/repositories/auth_repository.dart`):

| Method | Signature | Responsibility |
|--------|-----------|---------------|
| `signIn` | `Future<AuthUser> signIn(String email, String password)` | Authenticate; return `AuthUser` with a valid `accessToken` |
| `signOut` | `Future<void> signOut()` | Clear local session |
| `getSignedInUser` | `Future<AuthUser?> getSignedInUser()` | Return current `AuthUser` or `null` if no valid session; does **not** refresh |
| `getAccessToken` | `Future<String?> getAccessToken()` | Return a valid (non-expired) access token, refreshing if necessary; return `null` if no session |
| `authStateChanges` | `Stream<AuthUser?> get authStateChanges` | Emits `AuthUser` on sign-in, `null` on sign-out; does not replay state on subscription |
| `registerDirect` | `Future<AuthUser> registerDirect(String email, String password)` | Dev-only: create account and authenticate without OTP |
| `sendSignUpCode` | `Future<void> sendSignUpCode(String email, String password)` | Production step 1: initiate OTP sign-up |
| `verifySignUp` | `Future<AuthUser> verifySignUp(String email, String code)` | Production step 2: verify OTP and return authenticated `AuthUser` |

**`getSignedInUser()` vs `getAccessToken()`:** These serve different callers. `getSignedInUser()` answers "who is the current user?" for display purposes. `getAccessToken()` answers "give me a fresh credential for an API call." Only `getAccessToken()` triggers a token refresh; `getSignedInUser()` does not.

### `getAccessToken()` behavior per implementation

| Implementation | Behavior |
|----------------|----------|
| `SupabaseAuthRepository` | Check `currentSession.isExpired` → if expired, call `supabase.auth.refreshSession()`; return `currentSession?.accessToken`. If refresh fails, call `signOut()` and return `null`. |
| `DevAuthRepository` | Return stored `_accessToken`. Dev tokens have a 24h TTL; no refresh is performed. If the token is expired, the user must sign in again. |
| `MockAuthRepository` | Return `_currentUser?.accessToken`. No refresh logic needed. |

### `registerDirect` behavior per implementation

| Implementation | Behavior |
|----------------|----------|
| `SupabaseAuthRepository` | Calls `POST /api/v1/auth/register` to create local `User` row, then signs in via `supabase.auth.signInWithPassword()`. Returns `AuthUser` with a real Supabase JWT. Must not be called in production (backend returns `403`). |
| `DevAuthRepository` | Calls `POST /api/v1/auth/register` to create local `User` row, then calls `POST /api/v1/dev/token` to obtain a JWT. Returns `AuthUser`. |
| `MockAuthRepository` | Returns a mock `AuthUser` immediately — no network call. Identical behavior to `signIn()`. |

### `sendSignUpCode` / `verifySignUp` behavior per implementation

| Implementation | `sendSignUpCode` | `verifySignUp` |
|----------------|------------------|----------------|
| `SupabaseAuthRepository` | Calls `supabase.auth.signUp(email, password)` to trigger OTP email | Calls `supabase.auth.verifyOTP(email, token, type: signup)` |
| `DevAuthRepository` | Throws `Exception('Not supported in dev mode — use registerDirect()')` | Throws `Exception('Not supported in dev mode — use registerDirect()')` |
| `MockAuthRepository` | Stores `(email, password)` in pending sign-ups map | Verifies OTP against `kMockAuthAccounts` |

These methods are never called when `SKIP_EMAIL_VERIFICATION=true`, which is the required frontend configuration for both `dev` and `mock` modes.

### `signIn` failure

`signIn()` throws `Exception` on failure. The message is sourced from the provider's native error (Supabase `AuthException.message`, HTTP response `data["detail"]`, etc.). Callers must catch `Exception` and display the message to the user.

`authStateChanges` does not emit on failure. It only emits after a successful state change.

---

## Supported Environment Combinations

| `AUTH_PROVIDER` | `USE_MOCK_DATA` | Backend called | Supported |
|-----------------|-----------------|----------------|-----------|
| `supabase` | `true` | No | ✓ Mock data layer, no auth needed |
| `supabase` | `false` | Yes | ✓ **Production path** |
| `mock` | `true` | No | ✓ UI-only development |
| `mock` | `false` | Yes | ✗ **Unsupported** — mock tokens are not valid JWTs |
| `dev` | `false` | Yes | ✓ **Local full-stack development** — `ENABLE_DEV_AUTH=True` required on backend |
| `dev` | `true` | No | ✗ **Not meaningful** — dev auth exists to call the real backend |
| `localBackend` | any | — | ✗ **Removed** — do not use; `LocalBackendAuthRepository` is deleted |

---

## Frontend Independence Rule

The frontend must not depend on which mechanism the backend uses to verify tokens. Whether the backend validates via Supabase JWKS (ES256) or a local secret (HS256) is invisible to Flutter at runtime. Flutter's sole obligation is to provide a JWT that satisfies the Token Format above.

`AuthProviderMode` controls how the frontend *obtains* a token — Supabase SDK, dev backend, or mock data. It does not control how the backend *verifies* that token.

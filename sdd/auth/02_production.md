# Production Authentication

**Auth provider:** Supabase Auth  
**Refs:** → [Auth Overview](./00_overview.md) · [Auth Contract](./01_contract.md) · [API Spec](../backend/05_api_spec.md) · [Backend Architecture](../backend/09_backend_arch.md)

---

## Sign-Up Flow

```
1. Flutter: supabase.auth.signUp(email: email, password: password)
   → Supabase sends a 6-digit numeric OTP to the user's email

2. Flutter: supabase.auth.verifyOTP(email: email, token: code, type: OtpType.signup)
   → Returns Session { access_token, refresh_token }

3. Flutter stores session (SDK-managed) → navigates to /dashboard
```

## Sign-In Flow

```
1. Flutter: supabase.auth.signInWithPassword(email: email, password: password)
   → Returns Session on success
   → Throws AuthException on failure (display exception.message in the form error state)

2. Flutter stores session (SDK-managed) → navigates to /dashboard
```

---

## Session Management (Flutter)

- **Session storage:** The Supabase Flutter SDK automatically persists the session (access + refresh tokens) to platform storage. No Sentinel-specific storage code is required.
- **Access token TTL:** 3600 seconds. Supabase SDK auto-refreshes before expiry.
- **On app launch:** check `supabase.auth.currentSession` — navigate to `/dashboard` if valid, `/login` otherwise.
- **Auth state changes:** listen to `supabase.auth.onAuthStateChange`, which maps to `authStateChanges` in `SupabaseAuthRepository`.
- **Token acquisition:** `api_client.dart` Dio interceptor calls `authRepository.getAccessToken()` before every API call, which handles refresh internally.
- **Token refresh:** `SupabaseAuthRepository.getAccessToken()` checks `currentSession.isExpired`; if expired, calls `supabase.auth.refreshSession()` before returning the token.
- **Refresh failure:** if `refreshSession()` throws (e.g., refresh token revoked or expired), `getAccessToken()` must catch the exception, call `signOut()` to clear the local session, and return `null`. The `authStateChanges` stream then emits `null`, and the router redirects to `/login`. The original API call is not retried.

### `getAccessToken()` implementation

```dart
@override
Future<String?> getAccessToken() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;
    if (session.isExpired) {
        try {
            await _client.auth.refreshSession();
        } catch (_) {
            await signOut();
            return null;
        }
    }
    return _client.auth.currentSession?.accessToken;
}
```

---

## JWT Verification (FastAPI)

**File:** `app/core/auth.py`  
**Algorithm:** ES256 (ECDSA P-256) — **not** HS256  
**Key source:** Supabase JWKS endpoint — keys rotated by Supabase automatically; never stored in the codebase

```python
_jwks_client: PyJWKClient | None = None

def _get_jwks_client() -> PyJWKClient:
    global _jwks_client
    if _jwks_client is None:
        url = settings.SUPABASE_URL.rstrip("/")
        if not url:
            raise RuntimeError("SUPABASE_URL is not set.")
        _jwks_client = PyJWKClient(f"{url}/auth/v1/.well-known/jwks.json")
    return _jwks_client
```

`_jwks_client` is lazily initialized on the first call to `_validate_supabase_token()`, not at module import time. This allows the server to start without `SUPABASE_URL` when `ENABLE_DEV_AUTH=True` and Supabase validation is not needed. In production, `SUPABASE_URL` is always set; the first request triggers initialization.

**JWKS key rotation:** `PyJWKClient` fetches the signing key from the JWKS endpoint on each call to `get_signing_key_from_jwt()` (with its own internal caching). When Supabase rotates keys, the new key is fetched automatically on the next validation call. No backend restart is required.

Validation is delegated to `_validate_supabase_token()` via `_select_validator()`. See [Development Auth §Validator Composition](./03_development.md) for the dispatch architecture.

The returned identity dict is specified in [Auth Contract §Backend Response Contract](./01_contract.md).

---

## Ownership Enforcement (Backend)

Every incident read/write validates ownership:

```python
if str(incident.user_id) != current_user["user_id"]:
    raise HTTPException(403, "Forbidden")
```

Applied in `incident_service._get_owned()` and the equivalent in `ai_action_service`. This is the authorization layer — separate from the authentication layer above.

---

## Dev-Only Registration Endpoint

`POST /api/v1/auth/register` creates a `User` row in the local database for FK satisfaction during development.

- Returns `403 "This endpoint is not available in production."` when `SKIP_EMAIL_VERIFICATION=False`
- Does **not** issue tokens — authentication always goes through Supabase
- Required before using `POST /api/v1/dev/token` (see [Development Auth](./03_development.md))

---

## Environment Variables

| Variable | Where used | Required | Purpose |
|----------|------------|----------|---------|
| `SUPABASE_URL` | Backend | Yes (prod) | Derives JWKS endpoint URL: `{URL}/auth/v1/.well-known/jwks.json` |
| `SUPABASE_ANON_KEY` | Flutter `--dart-define` | Yes (prod) | Initializes Supabase client SDK |
| `SKIP_EMAIL_VERIFICATION` | Backend | No (default: `True`) | Set `False` in production to block the dev-only register endpoint |

---

## Security Notes

- JWKS public keys are fetched and cached by `PyJWKClient`; Supabase rotates them without requiring a backend redeploy
- `SUPABASE_ANON_KEY` is safe to include in Flutter build artifacts — it is not a privileged key; Supabase RLS enforces row-level access on the Supabase side
- HTTPS is enforced in all production environments (Cloud Run enforces TLS termination)
- The `sub` claim in Supabase JWTs is the Supabase user UUID — stable across sessions and safe to use as the primary identity key in application tables

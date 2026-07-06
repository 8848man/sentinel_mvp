# Development Authentication

**Purpose:** Defines the development authentication architecture. Enables local backend API testing and full Flutter + FastAPI + SQLite development without a live Supabase project or internet connection.

**Refs:** → [Auth Overview](./00_overview.md) · [Auth Contract](./01_contract.md) · [Backend Architecture](../backend/09_backend_arch.md) · [Deployment Spec](../infra/11_deployment_spec.md)

---

## Problem

The current architecture requires a valid Supabase JWT for every authenticated API call. This means:

- Backend-only development requires internet access and Supabase configuration
- The Swagger UI at `/docs` cannot be used for authenticated endpoints without a Supabase account
- `AUTH_PROVIDER=mock + USE_MOCK_DATA=false` is silently broken — `MockAuthRepository` issues opaque strings, not valid JWTs
- `LocalBackendAuthRepository` is deprecated and deleted
- `main.dart` initializes the Supabase SDK unconditionally, blocking fully local Flutter development

---

## Architecture: Validator Composition (Backend)

`get_current_user()` remains the single FastAPI dependency for all endpoints. Authentication validation is decomposed into focused functions — no interfaces, no abstract classes, no dependency injection.

```
get_current_user(credentials)
        │
        ▼
_select_validator(token)       ← pure routing; reads iss claim only; performs no validation
        │
        ├── iss == "sentinel-dev"  →  _validate_dev_token(token)
        └── default               →  _validate_supabase_token(token)
```

Adding a future validator requires: (1) one new async function, (2) one new branch in `_select_validator()`. No existing code is modified.

---

## Function Signatures

All four functions live in `app/core/auth.py`.

```python
from typing import Awaitable, Callable

def _select_validator(token: str) -> Callable[[str], Awaitable[dict]]:
    """Peek iss claim without signature verification; return the correct validator function."""

async def _validate_supabase_token(token: str) -> dict:
    """Verify ES256/JWKS signature. Return {"user_id": str, "email": str | None}."""

async def _validate_dev_token(token: str) -> dict:
    """Enforce production guards, then verify HS256. Return {"user_id": str, "email": str | None}."""

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    """Select and call the correct validator. Map exceptions to HTTP 401/403."""
```

`get_current_user()` implementation:
```python
async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    token = credentials.credentials
    validator = _select_validator(token)
    return await validator(token)
```

---

## `_select_validator()` Implementation

Peeks the JWT payload without signature verification using `options={"verify_signature": False, "verify_exp": False}`. No exception is raised for expired or invalid signatures at this stage.

```python
def _select_validator(token: str) -> Callable[[str], Awaitable[dict]]:
    try:
        payload = jwt.decode(
            token,
            options={"verify_signature": False, "verify_exp": False},
            algorithms=["HS256", "ES256"],
        )
    except jwt.DecodeError:
        # Structurally malformed token — route to Supabase validator, which will raise 401
        return _validate_supabase_token

    if payload.get("iss") == "sentinel-dev":
        return _validate_dev_token
    return _validate_supabase_token
```

**If `iss` is absent or any value other than `"sentinel-dev"`:** return `_validate_supabase_token`. There is no third branch.

---

## `_validate_supabase_token()` Implementation

`_jwks_client` must be lazily initialized (not at module load time) to allow the server to start without `SUPABASE_URL` when running in dev-only mode.

```python
_jwks_client: PyJWKClient | None = None

def _get_jwks_client() -> PyJWKClient:
    global _jwks_client
    if _jwks_client is None:
        url = settings.SUPABASE_URL.rstrip("/")
        if not url:
            raise RuntimeError(
                "SUPABASE_URL is not set. Required for Supabase JWT verification."
            )
        _jwks_client = PyJWKClient(f"{url}/auth/v1/.well-known/jwks.json")
    return _jwks_client

async def _validate_supabase_token(token: str) -> dict:
    try:
        client = _get_jwks_client()
        signing_key = client.get_signing_key_from_jwt(token)
        payload = jwt.decode(
            token,
            signing_key.key,
            algorithms=["ES256"],
            audience="authenticated",
        )
        return {"user_id": payload["sub"], "email": payload.get("email")}
    except jwt.ExpiredSignatureError:
        raise HTTPException(401, "Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(401, "Invalid token")
```

---

## `_validate_dev_token()` Implementation

Production guards are checked before any token decoding. Both must pass independently.

```python
async def _validate_dev_token(token: str) -> dict:
    if settings.APP_ENV == "production" or not settings.ENABLE_DEV_AUTH:
        raise HTTPException(403, "Dev auth is disabled")
    try:
        payload = jwt.decode(
            token,
            settings.DEV_JWT_SECRET,
            algorithms=["HS256"],
            audience="authenticated",
        )
    except jwt.ExpiredSignatureError:
        raise HTTPException(401, "Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(401, "Invalid token")
    return {"user_id": payload["sub"], "email": payload.get("email")}
```

`audience="authenticated"` is validated by `jwt.decode()`. A dev token without `aud: "authenticated"` raises `InvalidTokenError → 401`.

### Error table

| Condition | HTTP status | `detail` |
|-----------|-------------|----------|
| `APP_ENV == "production"` | 403 | `"Dev auth is disabled"` |
| `ENABLE_DEV_AUTH == False` | 403 | `"Dev auth is disabled"` |
| Token expired | 401 | `"Token expired"` |
| Invalid signature or claims | 401 | `"Invalid token"` |

---

## Dev Token Endpoint

### Router: `app/routers/dev.py`

Do NOT add this route to `app/routers/auth.py` — that router has `prefix="/auth"`, which would produce the wrong URL (`/api/v1/auth/dev/token` instead of `/api/v1/dev/token`).

```python
# app/routers/dev.py
import logging
import jwt
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.models.models import User, _user_id_for

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/dev", tags=["dev"])
```

### Conditional registration in `app/main.py`

Register the dev router only when `ENABLE_DEV_AUTH` is `True`. When `False`, the route does not exist and returns `404` — not `403`. The guard inside `_validate_dev_token()` is defense-in-depth, not the primary gate.

```python
if settings.ENABLE_DEV_AUTH:
    from app.routers import dev
    app.include_router(dev.router, prefix="/api/v1")
```

### `POST /api/v1/dev/token`

**Request body:**
```json
{ "email": "dev@sentinel.ai", "password": "Dev1234!" }
```

`password` is optional. If omitted, the token is issued without credential verification (for curl / Swagger UI usage). If provided, it must match the password stored in the `User` row.

**Endpoint logic (in order):**
1. Enforce guards: `settings.APP_ENV != "production"` AND `settings.ENABLE_DEV_AUTH`. If either fails → `403 "Dev auth is disabled"`. (Defense-in-depth — unreachable if conditional registration is correct.)
2. Normalize email: `email.strip().lower()`.
3. Look up `User` row where `User.email == email`. If not found → `404 "User not found"`.
4. If `password` is provided: compare with `user.password`. If mismatch → `401 "Invalid credentials"`.
5. Compute `user_id = _user_id_for(email)`.
6. Issue HS256 JWT (see claims table below).
7. Log: `logger.info("Dev token issued: email=%s sub=%s", email, user_id)`.
8. Return response body.

**Request model:**
```python
class DevTokenRequest(BaseModel):
    email: str
    password: str | None = None
```

**Response body:**
```json
{
  "access_token": "<hs256-jwt>",
  "token_type": "bearer",
  "expires_in": 86400
}
```

**Issued token claims:**

| Claim | Value |
|-------|-------|
| `sub` | `_user_id_for(email)` — same UUID as the User row's `user_id` |
| `email` | Normalized email address |
| `aud` | `"authenticated"` |
| `iss` | `"sentinel-dev"` |
| `iat` | Current UNIX timestamp (`int(time.time())`) |
| `exp` | `iat + 86400` |

Algorithm: HS256. Signed with `settings.DEV_JWT_SECRET`.

### Error table for `POST /api/v1/dev/token`

| Condition | HTTP status | `detail` |
|-----------|-------------|----------|
| `ENABLE_DEV_AUTH=False` or `APP_ENV=production` | 403 | `"Dev auth is disabled"` |
| Email not found in `User` table | 404 | `"User not found"` |
| `password` provided and does not match `user.password` | 401 | `"Invalid credentials"` |

---

## Frontend: DevAuthRepository

**File:** `lib/features/auth/data/repositories/dev_auth_repository.dart`

`DevAuthRepository` implements `AuthRepository` by calling the backend dev endpoints over HTTP. It returns real HS256 JWTs that are accepted by the FastAPI auth validator.

### Construction

```dart
class DevAuthRepository implements AuthRepository {
    DevAuthRepository({required String baseUrl}) : _baseUrl = baseUrl;

    final String _baseUrl;
    final _dio = Dio();
    final _controller = StreamController<AuthUser?>.broadcast();
    AuthUser? _currentUser;
    String? _accessToken;
}
```

Injected in `auth_repository_provider.dart`:
```dart
AuthProviderMode.dev => DevAuthRepository(baseUrl: ApiEndpoints.base),
```

### `signIn`

```dart
@override
Future<AuthUser> signIn(String email, String password) async {
    try {
        final r = await _dio.post(
            '$_baseUrl/api/v1/dev/token',
            data: {'email': email, 'password': password},
        );
        return _setUser(email, r.data['access_token'] as String);
    } on DioException catch (e) {
        final detail = e.response?.data['detail'] ?? 'Sign-in failed';
        throw Exception(detail);
    }
}
```

### `registerDirect`

```dart
@override
Future<AuthUser> registerDirect(String email, String password) async {
    try {
        await _dio.post(
            '$_baseUrl/api/v1/auth/register',
            data: {'email': email, 'password': password},
        );
    } on DioException catch (e) {
        // 409 = user already exists; skip registration and sign in directly
        if (e.response?.statusCode != 409) {
            final detail = e.response?.data['detail'] ?? 'Registration failed';
            throw Exception(detail);
        }
    }
    return signIn(email, password);
}
```

### `signOut`

```dart
@override
Future<void> signOut() async {
    _currentUser = null;
    _accessToken = null;
    _controller.add(null);
}
```

### `getSignedInUser`

```dart
@override
Future<AuthUser?> getSignedInUser() async => _currentUser;
```

### `getAccessToken`

```dart
@override
Future<String?> getAccessToken() async => _accessToken;
```

Dev tokens have a 24h TTL. No refresh is performed. If the token has expired, the Dio interceptor will receive `null`, the request will proceed without an `Authorization` header, and the backend will return `403` — which is the correct signal for the UI to redirect to `/login`.

### `sendSignUpCode` / `verifySignUp`

```dart
@override
Future<void> sendSignUpCode(String email, String password) async {
    throw Exception('Not supported in dev mode — use registerDirect()');
}

@override
Future<AuthUser> verifySignUp(String email, String code) async {
    throw Exception('Not supported in dev mode — use registerDirect()');
}
```

These methods are never called when `SKIP_EMAIL_VERIFICATION=true`, which is required for `AUTH_PROVIDER=dev`.

### `authStateChanges`

```dart
@override
Stream<AuthUser?> get authStateChanges => _controller.stream;
```

### Helper

```dart
String _subFromToken(String token) {
    final parts = token.split('.');
    final padded = base64Url.normalize(parts[1]);
    final payload = jsonDecode(utf8.decode(base64Url.decode(padded))) as Map;
    return payload['sub'] as String;
}

AuthUser _setUser(String email, String accessToken) {
    _accessToken = accessToken;
    final user = AuthUser(
        id: _subFromToken(accessToken),
        email: email,
        accessToken: accessToken,
        refreshToken: '',
    );
    _currentUser = user;
    _controller.add(user);
    return user;
}
```

`_subFromToken` decodes the JWT payload without verification to extract the `sub` claim. This ensures `AuthUser.id` always matches the JWT `sub` and the database `user_id` — no UUID computation needed on the Flutter side. Uses `dart:convert` only (no additional packages required).

---

## Frontend: `api_client.dart` Refactoring

**Problem:** `_resolveToken()` in `api_client.dart` has a hardcoded check for `authProvider == supabase` and reads `Supabase.instance.client.auth` directly, bypassing the `AuthRepository` abstraction.

**Fix:** Replace the provider-specific branch with a single call to `authRepository.getAccessToken()`.

**Current (`api_client.dart:38-53`):**
```dart
Future<String?> _resolveToken(Ref ref) async {
    if (AppConfig.authProvider == AuthProviderMode.supabase) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null && session.isExpired) {
            try { await Supabase.instance.client.auth.refreshSession(); } catch (_) {}
        }
        return Supabase.instance.client.auth.currentSession?.accessToken;
    }
    return ref.read(authProvider).user?.accessToken;
}
```

**Replacement:**
```dart
Future<String?> _resolveToken(Ref ref) async {
    return ref.read(authRepositoryProvider).getAccessToken();
}
```

Remove the `import 'package:supabase_flutter/supabase_flutter.dart'` from `api_client.dart`. Remove the `import '../config/app_config.dart'` if it is no longer used elsewhere in the file.

---

## Frontend: `main.dart` Changes

**Problem:** `main.dart` calls `Supabase.initialize()` unconditionally. When `AUTH_PROVIDER=dev`, `SUPABASE_URL` and `SUPABASE_ANON_KEY` are empty strings, making the Supabase client unusable.

**Fix:** Conditional initialization based on `AppConfig.authProvider`.

**Current:**
```dart
void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(
        url: const String.fromEnvironment('SUPABASE_URL'),
        anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
    runApp(const ProviderScope(child: SentinelApp()));
}
```

**Replacement:**
```dart
void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (AppConfig.authProvider == AuthProviderMode.supabase) {
        await Supabase.initialize(
            url: const String.fromEnvironment('SUPABASE_URL'),
            anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
        );
    }
    runApp(const ProviderScope(child: SentinelApp()));
}
```

---

## Frontend: `app_config.dart` Changes

Add `dev` to the `AuthProviderMode` enum and its resolution switch:

```dart
enum AuthProviderMode { mock, supabase, dev }

static AuthProviderMode get authProvider => switch (_authProviderEnv) {
    'mock' => AuthProviderMode.mock,
    'dev' => AuthProviderMode.dev,
    _ => AuthProviderMode.supabase,
};
```

---

## Frontend: `auth_repository.dart` Interface Change

Add `getAccessToken()` to the `AuthRepository` abstract interface:

```dart
abstract interface class AuthRepository {
    Future<AuthUser> signIn(String email, String password);
    Future<void> signOut();
    Future<AuthUser?> getSignedInUser();
    Future<String?> getAccessToken();
    Stream<AuthUser?> get authStateChanges;
    Future<AuthUser> registerDirect(String email, String password);
    Future<void> sendSignUpCode(String email, String password);
    Future<AuthUser> verifySignUp(String email, String code);
}
```

---

## Frontend: `auth_repository_provider.dart` Changes

Add `AuthProviderMode.dev` case:

```dart
import '../repositories/dev_auth_repository.dart';
// ...

final authRepositoryProvider = Provider<AuthRepository>((ref) {
    return switch (AppConfig.authProvider) {
        AuthProviderMode.mock => MockAuthRepository(),
        AuthProviderMode.supabase => SupabaseAuthRepository(),
        AuthProviderMode.dev => DevAuthRepository(baseUrl: ApiEndpoints.base),
    };
});
```

---

## Backend Changes Required

### 1. `app/core/config.py` (already done)

`ENABLE_DEV_AUTH: bool = False` and `DEV_JWT_SECRET: str = "dev-insecure-local-secret-change-me"` are present. `SUPABASE_JWT_SECRET` has been removed. `extra = "ignore"` is set on the Config inner class.

### 2. `app/core/auth.py` (already done)

Validator composition is implemented. Lazy JWKS initialization is implemented.

### 3. `app/routers/dev.py` (update required — add password verification)

Add `password: str | None = None` to `DevTokenRequest`. After the user lookup, add:

```python
if body.password is not None and body.password != user.password:
    raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid credentials")
```

### 4. `app/main.py` (already done)

Conditional dev router registration is implemented.

### 5. `.env.example` (already done)

Dev auth block is present, commented out.

---

## Backend Changes Required — Summary Table

| File | Status | Action |
|------|--------|--------|
| `app/core/config.py` | Done | Add ENABLE_DEV_AUTH, DEV_JWT_SECRET; remove SUPABASE_JWT_SECRET |
| `app/core/auth.py` | Done | Validator composition + lazy JWKS init |
| `app/routers/dev.py` | Update | Add optional password field + verification |
| `app/main.py` | Done | Conditional dev router registration |
| `.env.example` | Done | Add commented-out dev auth block |

---

## Frontend Changes Required — Summary Table

| File | Action |
|------|--------|
| `lib/features/auth/domain/repositories/auth_repository.dart` | Add `getAccessToken()` method |
| `lib/core/config/app_config.dart` | Add `AuthProviderMode.dev` to enum and switch |
| `lib/main.dart` | Conditional `Supabase.initialize()` |
| `lib/core/api/api_client.dart` | Replace `_resolveToken()` with single `getAccessToken()` call; remove Supabase import |
| `lib/features/auth/data/repositories/dev_auth_repository.dart` | Create — full implementation |
| `lib/features/auth/data/repositories/supabase_auth_repository.dart` | Add `getAccessToken()` with refresh logic |
| `lib/features/auth/data/repositories/mock_auth_repository.dart` | Add `getAccessToken()` returning `_currentUser?.accessToken` |
| `lib/features/auth/data/providers/auth_repository_provider.dart` | Add `AuthProviderMode.dev` case |

---

## Mock Credentials (Frontend UI Dev)

Used exclusively by `MockAuthRepository` when `USE_MOCK_DATA=true`. These strings are not sent to the real backend.

| Email | Password | OTP Code | User ID |
|-------|----------|----------|---------|
| `admin@sentinel.ai` | `Sentinel2026!` | `000000` | `mock-user-001` |
| `dev@sentinel.ai` | `Dev1234!` | `111111` | `mock-user-002` |

Token format: `mock.<type>.token.<email-slug>` — clearly fake; rejected by the backend with `401`.

---

## Dev Credentials (Flutter + Local Backend)

Default credentials for the `AUTH_PROVIDER=dev` workflow. Created via `POST /api/v1/auth/register`:

| Email | Password |
|-------|----------|
| `dev@sentinel.ai` | `Dev1234!` |

These are example values only. Any email/password pair that matches a `User` row in the local database is valid.

---

## Environment Variables

| Variable | Default | Required in prod | Purpose |
|----------|---------|-----------------|---------|
| `ENABLE_DEV_AUTH` | `False` | Must be absent / `False` | Gates dev token endpoint and HS256 validation path |
| `DEV_JWT_SECRET` | `"dev-insecure-local-secret-change-me"` | Must be absent | HS256 signing secret |

**`ENABLE_DEV_AUTH` must not appear in Cloud Run environment configuration, Secret Manager, or any production deployment artifact.**

---

## Supported Development Workflows

| Goal | Method |
|------|--------|
| Test backend API with curl or `/docs` | Start with `ENABLE_DEV_AUTH=True` → `POST /api/v1/auth/register` → `POST /api/v1/dev/token` → use JWT as Bearer |
| Run automated backend tests | `dependency_overrides[get_current_user]` in `conftest.py` — no token needed |
| Full-stack dev with Flutter | `AUTH_PROVIDER=dev` + `ENABLE_DEV_AUTH=True` + `SKIP_EMAIL_VERIFICATION=true` |
| Flutter UI dev without backend | `AUTH_PROVIDER=mock` + `USE_MOCK_DATA=true` |
| Production auth development | `AUTH_PROVIDER=supabase` with a real Supabase dev project |

---

## CI Integration

Automated tests use `dependency_overrides[get_current_user]` directly — no token issuance, no Supabase credentials required in CI.

For future E2E tests against a live server instance:
1. Start backend with `APP_ENV=development`, `ENABLE_DEV_AUTH=True`
2. `POST /api/v1/auth/register` to create a test user row
3. `POST /api/v1/dev/token` to obtain a 24-hour JWT
4. Use the JWT as the Bearer token for all E2E HTTP calls

---

## Security Notes

- The HS256 path is unreachable in production: the dev router is not registered when `ENABLE_DEV_AUTH=False`; `_validate_dev_token()` enforces both guards independently as defense-in-depth
- Dev tokens use `iss: "sentinel-dev"` — structurally distinct from Supabase tokens; `_validate_supabase_token()` never processes them
- `DEV_JWT_SECRET` defaults to a well-known string; this is acceptable because secrecy is not the security mechanism — the environment guards are
- Every token issuance logs `email` and `sub` at INFO level; an unexpected issuance log in a production environment signals misconfiguration

---

## Migration Checklist

Execute steps in this order. Each step must pass before the next begins.

### Backend

- [x] **1.** `app/core/config.py` — Add `ENABLE_DEV_AUTH`, `DEV_JWT_SECRET`; remove `SUPABASE_JWT_SECRET`; add `extra = "ignore"` to Config
- [x] **2.** `app/core/auth.py` — Replace with validator composition + lazy JWKS init
- [x] **3.** `app/routers/dev.py` — Create dev token endpoint
- [ ] **4.** `app/routers/dev.py` — Add optional `password` field and verification
- [x] **5.** `app/main.py` — Add conditional dev router registration
- [x] **6.** `.env.example` — Add commented-out dev auth block
- [x] **7.** `backend/tests/unit/test_auth.py` — Validate `_select_validator` and `_validate_dev_token`
- [x] **8.** `backend/tests/integration/test_dev_token_router.py` — Validate full round-trip
- [ ] **9.** Add tests for password verification (`401` on wrong password, `200` with correct password)

### Frontend

- [x] **10.** `lib/features/auth/data/repositories/local_backend_auth_repository.dart` — Delete
- [x] **11.** `lib/core/config/app_config.dart` — Remove `localBackend`; add `dev`
- [ ] **12.** `lib/features/auth/domain/repositories/auth_repository.dart` — Add `getAccessToken()`
- [ ] **13.** `lib/features/auth/data/repositories/supabase_auth_repository.dart` — Implement `getAccessToken()` with refresh
- [ ] **14.** `lib/features/auth/data/repositories/mock_auth_repository.dart` — Implement `getAccessToken()`
- [ ] **15.** `lib/features/auth/data/repositories/dev_auth_repository.dart` — Create full implementation
- [ ] **16.** `lib/features/auth/data/providers/auth_repository_provider.dart` — Add `AuthProviderMode.dev` case
- [x] **17.** `lib/main.dart` — Conditional `Supabase.initialize()` (also added `AppConfig.validate()` fail-fast check — see [Deployment Spec](../infra/11_deployment_spec.md))
- [x] **18.** `lib/core/api/api_client.dart` — Replace `_resolveToken()` with `getAccessToken()`

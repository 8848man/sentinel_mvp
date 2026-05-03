# 07 — Auth Specification

**Auth provider:** Supabase Auth  
**Refs:** → [Requirements](../context/01_requirements.md) · [API Spec](./05_api_spec.md) · [Backend Architecture](./09_backend_arch.md)

---

## Overview

- All authentication is handled by Supabase Auth; no custom auth server
- Supabase issues JWTs signed with project JWT secret
- FastAPI backend validates Supabase JWT on every protected request
- Flutter client stores session using Supabase Flutter SDK (secure storage)

---

## Sign-Up Flow

```
1. Flutter: supabase.auth.signUp(email: email, password: password)
   → Supabase sends OTP email to user

2. User receives OTP code in email

3. Flutter (sign_up screen): supabase.auth.verifyOTP(
     email: email,
     token: code,
     type: OtpType.signup
   )
   → Returns Session (access_token + refresh_token)

4. Flutter stores session; navigates to /dashboard
```

**Fields collected on sign_up screen:**
- Email (to identify the OTP target)
- Password (set during signUp call in step 1)
- Validation code (OTP from email, used in step 3)

---

## Sign-In Flow

```
1. Flutter: supabase.auth.signInWithPassword(email: email, password: password)
   → Returns Session on success

2. Flutter stores session; navigates to /dashboard
3. On error: display Supabase error message inline
```

---

## Session Management (Flutter)

```dart
// On app launch: check existing session
final session = supabase.auth.currentSession;
if (session != null && !session.isExpired) {
  // navigate to /dashboard
} else {
  // navigate to /login
}

// Token refresh: Supabase SDK handles automatically
// Manual refresh if needed:
await supabase.auth.refreshSession();
```

- Access token TTL: 3600 seconds (1 hour) — Supabase default
- Refresh token: Supabase SDK auto-refreshes before expiry
- On auth state change: listen to `supabase.auth.onAuthStateChange`

---

## JWT Validation (FastAPI Backend)

Every protected endpoint uses `Depends(get_current_user)`:

```python
# app/core/auth.py
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer

SUPABASE_JWT_SECRET = settings.SUPABASE_JWT_SECRET  # from env

security = HTTPBearer()

async def get_current_user(token: str = Depends(security)) -> dict:
    try:
        payload = jwt.decode(
            token.credentials,
            SUPABASE_JWT_SECRET,
            algorithms=["HS256"],
            audience="authenticated"
        )
        return {"user_id": payload["sub"], "email": payload.get("email")}
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")
```

**User ID:** Extracted from JWT `sub` claim (Supabase user UUID).  
All DB queries filter by this `user_id` for ownership enforcement.

---

## Ownership Enforcement (Backend)

All incident reads/writes validate:
```python
async def get_incident_or_403(incident_id: str, user_id: str, db: AsyncSession):
    incident = await db.get(Incident, incident_id)
    if not incident:
        raise HTTPException(404, "Incident not found")
    if incident.user_id != user_id:
        raise HTTPException(403, "Forbidden")
    return incident
```

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Public anon key (Flutter client) |
| `SUPABASE_JWT_SECRET` | JWT signing secret (FastAPI backend only, never in client) |

---

## Security Notes

- `SUPABASE_JWT_SECRET` is a backend-only secret; never sent to Flutter client
- Flutter only uses `SUPABASE_URL` and `SUPABASE_ANON_KEY`
- HTTPS is enforced in all production environments
- Supabase anon key is safe to expose in client (RLS enforced in Supabase)

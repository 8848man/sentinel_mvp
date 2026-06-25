"""
Authentication utilities for the Sentinel API.

All authentication is handled exclusively by Supabase Auth.  The Flutter client
signs in through Supabase, receives a Supabase-issued JWT access token, and
attaches it to every API request as:

    Authorization: Bearer <supabase_access_token>

This module verifies those tokens.  It does NOT issue tokens.

Supabase access tokens are ES256 JWTs verified via the project's JWKS endpoint:
    {SUPABASE_URL}/auth/v1/.well-known/jwks.json

The `sub` claim contains the Supabase user UUID; audience is always "authenticated".
"""

import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jwt import PyJWKClient

from app.core.config import settings

security = HTTPBearer()


def _make_jwks_client() -> PyJWKClient:
    """
    Build the JWKS client from SUPABASE_URL at startup.

    Raises a clear error if SUPABASE_URL is not configured so the problem is
    caught immediately at container start rather than on the first request.
    """
    url = settings.SUPABASE_URL.rstrip("/")
    if not url:
        raise RuntimeError(
            "SUPABASE_URL is not set.  "
            "Add it to your environment or Secret Manager "
            "(format: https://<ref>.supabase.co)."
        )
    jwks_url = f"{url}/auth/v1/.well-known/jwks.json"
    return PyJWKClient(jwks_url)


# Initialised once at import time; fails fast if SUPABASE_URL is missing.
_jwks_client = _make_jwks_client()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    """
    FastAPI dependency that validates a Supabase access token.

    Returns ``{"user_id": "<uuid>", "email": "<email>"}`` on success.
    Raises HTTP 401 when the token is absent, expired, or invalid.
    """
    try:
        token = credentials.credentials
        signing_key = _jwks_client.get_signing_key_from_jwt(token)
        payload = jwt.decode(
            token,
            signing_key.key,
            algorithms=["ES256"],
            audience="authenticated",
        )
        return {
            "user_id": payload["sub"],
            "email": payload.get("email"),
        }

    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")

    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")

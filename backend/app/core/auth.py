"""
Authentication utilities for the Sentinel API.

Token validation is dispatched through _select_validator(), which peeks the
`iss` claim to route each token to the correct validator:

  - iss == "sentinel-dev"  →  _validate_dev_token()   (HS256, dev-only)
  - anything else          →  _validate_supabase_token() (ES256, JWKS)

get_current_user() is the single FastAPI dependency used by all endpoints.
It returns {"user_id": str, "email": str | None} on success.
"""

import logging
from typing import Awaitable, Callable

import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import PyJWKClient

from app.core.config import settings

logger = logging.getLogger(__name__)

security = HTTPBearer()

# Lazily initialised on first call to _validate_supabase_token().
# Not initialised at module load time so the server can start without
# SUPABASE_URL when running in dev-only mode (ENABLE_DEV_AUTH=True).
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


def _select_validator(token: str) -> Callable[[str], Awaitable[dict]]:
    """Peek the JWT payload (no signature verification) and return the correct validator."""
    try:
        payload = jwt.decode(
            token,
            options={"verify_signature": False, "verify_exp": False},
            algorithms=["HS256", "ES256"],
        )
    except jwt.DecodeError:
        # Structurally malformed — route to Supabase validator, which will raise 401.
        return _validate_supabase_token

    if payload.get("iss") == "sentinel-dev":
        return _validate_dev_token
    return _validate_supabase_token


async def _validate_supabase_token(token: str) -> dict:
    """Verify an ES256 Supabase JWT via JWKS. Returns identity dict on success."""
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
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")


async def _validate_dev_token(token: str) -> dict:
    """
    Verify an HS256 dev JWT. Enforces both production guards before decoding.
    Returns identity dict on success.
    """
    if settings.APP_ENV == "production" or not settings.ENABLE_DEV_AUTH:
        raise HTTPException(status_code=403, detail="Dev auth is disabled")
    try:
        payload = jwt.decode(
            token,
            settings.DEV_JWT_SECRET,
            algorithms=["HS256"],
            audience="authenticated",
        )
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")
    return {"user_id": payload["sub"], "email": payload.get("email")}


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    """
    FastAPI dependency that validates the Bearer token from every authenticated request.

    Routes to the correct validator based on the token's iss claim:
      - iss == "sentinel-dev"  →  _validate_dev_token()
      - default                →  _validate_supabase_token()

    Returns {"user_id": str, "email": str | None} on success.
    """
    token = credentials.credentials
    validator = _select_validator(token)
    return await validator(token)

import time
import uuid

import jwt
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from app.core.config import settings

router = APIRouter(prefix="/auth", tags=["auth"])

# In-memory user store for local backend auth mode.
# Populated by /register, consumed by /login.
# Passwords are stored in plain text — acceptable for ephemeral dev-only state.
_user_store: dict[str, dict] = {}


class RegisterRequest(BaseModel):
    email: str
    password: str


class RegisterResponse(BaseModel):
    message: str
    email: str


class LoginRequest(BaseModel):
    email: str
    password: str


class LoginResponse(BaseModel):
    user_id: str
    email: str
    access_token: str
    refresh_token: str


def _require_dev() -> None:
    if not settings.SKIP_EMAIL_VERIFICATION:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This endpoint is not available in production.",
        )


def _validated_email(raw: str) -> str:
    email = raw.strip().lower()
    if not email or "@" not in email or "." not in email.split("@")[-1]:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="A valid email address is required.",
        )
    return email


def _issue_token(user_id: str, email: str) -> str:
    now = int(time.time())
    return jwt.encode(
        {"sub": user_id, "email": email, "aud": "authenticated", "iat": now, "exp": now + 3600},
        settings.SUPABASE_JWT_SECRET,
        algorithm="HS256",
    )


@router.post(
    "/register",
    response_model=RegisterResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Dev-only direct registration (email verification bypassed)",
)
async def dev_register(body: RegisterRequest) -> RegisterResponse:
    """
    Creates a local user account without email verification.

    Gated behind SKIP_EMAIL_VERIFICATION=true (dev default). Returns 403 in production.
    The registered account is held in memory and can be used immediately with /login.
    """
    _require_dev()
    email = _validated_email(body.email)
    if len(body.password) < 8:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Password must be at least 8 characters.",
        )
    if email in _user_store:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists.",
        )
    _user_store[email] = {"user_id": f"local-{uuid.uuid4()}", "password": body.password}
    return RegisterResponse(message="Registration accepted.", email=email)


@router.post(
    "/login",
    response_model=LoginResponse,
    summary="Dev-only login that issues a signed JWT",
)
async def dev_login(body: LoginRequest) -> LoginResponse:
    """
    Validates credentials against the in-memory user store and returns a signed JWT.

    The token is signed with SUPABASE_JWT_SECRET (HS256, aud='authenticated') so it
    is accepted by the backend's get_current_user dependency without modification.
    Gated behind SKIP_EMAIL_VERIFICATION=true. Returns 403 in production.
    """
    _require_dev()
    email = _validated_email(body.email)
    entry = _user_store.get(email)
    if entry is None or entry["password"] != body.password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid login credentials",
        )
    user_id = entry["user_id"]
    return LoginResponse(
        user_id=user_id,
        email=email,
        access_token=_issue_token(user_id, email),
        refresh_token=f"local-refresh-{uuid.uuid4()}",
    )

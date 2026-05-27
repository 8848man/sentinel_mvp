import time

import jwt
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import get_current_user
from app.core.config import settings
from app.core.database import get_db
from app.models.models import User, _user_id_for

router = APIRouter(prefix="/auth", tags=["auth"])


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
async def dev_register(body: RegisterRequest, db: AsyncSession = Depends(get_db)) -> RegisterResponse:
    _require_dev()
    email = _validated_email(body.email)
    if len(body.password) < 8:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Password must be at least 8 characters.",
        )
    async with db.begin():
        existing = await db.scalar(select(User).where(User.email == email))
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="An account with this email already exists.",
            )
        db.add(User(user_id=_user_id_for(email), email=email, password=body.password))
    return RegisterResponse(message="Registration accepted.", email=email)


@router.post(
    "/login",
    response_model=LoginResponse,
    summary="Dev-only login that issues a signed JWT",
)
async def dev_login(body: LoginRequest, db: AsyncSession = Depends(get_db)) -> LoginResponse:
    print('dev_login')
    _require_dev()
    email = _validated_email(body.email)
    user = await db.scalar(select(User).where(User.email == email))
    if user is None or user.password != body.password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid login credentials",
        )
    return LoginResponse(
        user_id=user.user_id,
        email=email,
        access_token=_issue_token(user.user_id, email),
        refresh_token=f"local-refresh-{user.user_id}",
    )


@router.get("/me", summary="Return the current authenticated user")
async def me(current_user: dict = Depends(get_current_user)) -> dict:
    return current_user

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


@router.post(
    "/register",
    response_model=RegisterResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Dev-only direct registration (email verification bypassed)",
)
async def dev_register(body: RegisterRequest, db: AsyncSession = Depends(get_db)) -> RegisterResponse:
    """
    Development-only endpoint to create a user record in the local DB so that
    business-logic tables (incidents, etc.) can reference a known user_id.

    Authentication itself is handled exclusively by Supabase Auth — this endpoint
    does NOT issue any tokens. The client must sign in through Supabase and attach
    the resulting access token to subsequent API requests.
    """
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


@router.get("/me", summary="Return the current authenticated user")
async def me(current_user: dict = Depends(get_current_user)) -> dict:
    """
    Validates the Supabase access token from the Authorization: Bearer header
    and returns the decoded user identity.
    """
    return current_user

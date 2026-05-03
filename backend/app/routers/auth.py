from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from app.core.config import settings

router = APIRouter(prefix="/auth", tags=["auth"])


class RegisterRequest(BaseModel):
    email: str
    password: str


class RegisterResponse(BaseModel):
    message: str
    email: str


@router.post(
    "/register",
    response_model=RegisterResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Dev-only direct registration (email verification bypassed)",
)
async def dev_register(body: RegisterRequest):
    """
    Accepts email + password and returns a success response without issuing
    or validating any email verification code.

    Gated behind SKIP_EMAIL_VERIFICATION=true (the default for local/dev).
    Returns 403 in production (SKIP_EMAIL_VERIFICATION=false).
    Email uniqueness is enforced by Supabase on the subsequent client signUp call.
    """
    if not settings.SKIP_EMAIL_VERIFICATION:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Direct registration is not available in production.",
        )

    email = body.email.strip().lower()
    if not email or "@" not in email or "." not in email.split("@")[-1]:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="A valid email address is required.",
        )
    if len(body.password) < 8:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Password must be at least 8 characters.",
        )

    return RegisterResponse(
        message="Registration accepted. Complete authentication via the Supabase client.",
        email=email,
    )

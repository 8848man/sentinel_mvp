"""
Development-only authentication endpoints.

This router is registered in app/main.py ONLY when settings.ENABLE_DEV_AUTH is True.
When disabled, these routes do not exist and return 404 — not 403.

The guard inside each endpoint is defense-in-depth and should never trigger
under correct configuration.
"""

import logging
import time

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


class DevTokenRequest(BaseModel):
    email: str
    password: str | None = None


class DevTokenResponse(BaseModel):
    access_token: str
    token_type: str
    expires_in: int


@router.post(
    "/token",
    response_model=DevTokenResponse,
    status_code=status.HTTP_200_OK,
    summary="Issue a development HS256 JWT (dev-only)",
)
async def dev_token(
    body: DevTokenRequest,
    db: AsyncSession = Depends(get_db),
) -> DevTokenResponse:
    """
    Issues a 24-hour HS256 JWT for a registered dev user.

    Requirements:
      - APP_ENV must not be "production"
      - ENABLE_DEV_AUTH must be True
      - The email must correspond to an existing User row
        (create one first via POST /api/v1/auth/register)

    The issued token satisfies the Auth Contract and is accepted by
    get_current_user() via the _validate_dev_token() path.
    """
    # Defense-in-depth guard (primary gate is conditional router registration)
    if settings.APP_ENV == "production" or not settings.ENABLE_DEV_AUTH:
        raise HTTPException(status_code=403, detail="Dev auth is disabled")

    email = body.email.strip().lower()

    async with db.begin():
        user = await db.scalar(select(User).where(User.email == email))

    if user is None:
        raise HTTPException(status_code=404, detail="User not found")

    if body.password is not None and body.password != user.password:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    user_id = _user_id_for(email)
    now = int(time.time())

    token = jwt.encode(
        {
            "sub": user_id,
            "email": email,
            "aud": "authenticated",
            "iss": "sentinel-dev",
            "iat": now,
            "exp": now + 86400,
        },
        settings.DEV_JWT_SECRET,
        algorithm="HS256",
    )

    logger.info("Dev token issued: email=%s sub=%s", email, user_id)

    return DevTokenResponse(
        access_token=token,
        token_type="bearer",
        expires_in=86400,
    )

"""Archive endpoints. Spec: sdd/05_api_spec.md §Archive"""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.auth import get_current_user
from app.core.database import get_db
from app.services import incident_service

router = APIRouter(tags=["archive"])


@router.get("/archive")
async def get_archive(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Spec: GET /archive — resolved/closed incidents with resolution_time_minutes."""
    return await incident_service.get_archive_incidents(current_user["user_id"], db)

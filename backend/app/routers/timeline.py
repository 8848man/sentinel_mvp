"""Timeline endpoints. Spec: sdd/05_api_spec.md §Timeline"""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.auth import get_current_user
from app.core.database import get_db
from app.services import incident_service

router = APIRouter(tags=["timeline"])


@router.get("/incidents/{incident_id}/timeline")
async def get_timeline(
    incident_id: str,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Spec: GET /incidents/{id}/timeline — ordered timeline events."""
    return await incident_service.get_timeline(incident_id, current_user["user_id"], db)

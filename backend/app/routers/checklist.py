"""Checklist endpoints. Spec: sdd/05_api_spec.md §Checklist Items"""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from app.core.auth import get_current_user
from app.core.database import get_db
from app.services import incident_service

router = APIRouter(tags=["checklist"])


class ChecklistPatchRequest(BaseModel):
    is_completed: bool


@router.patch("/checklist/{item_id}")
async def toggle_checklist_item(
    item_id: str,
    body: ChecklistPatchRequest,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Spec: PATCH /checklist/{item_id} — toggle completion, appends timeline event."""
    return await incident_service.toggle_checklist_item(
        item_id, body.is_completed, current_user["user_id"], db
    )

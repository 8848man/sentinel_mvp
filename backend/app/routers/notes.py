"""Notes endpoints. Spec: sdd/05_api_spec.md §Notes"""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from app.core.auth import get_current_user
from app.core.database import get_db
from app.services import incident_service

router = APIRouter(tags=["notes"])


class NoteRequest(BaseModel):
    content: str


@router.put("/incidents/{incident_id}/note")
async def upsert_note(
    incident_id: str,
    body: NoteRequest,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Spec: PUT /incidents/{id}/note — create or replace note (one per incident)."""
    return await incident_service.upsert_note(incident_id, body.content, current_user["user_id"], db)

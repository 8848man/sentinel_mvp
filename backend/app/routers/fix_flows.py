"""Fix Flow endpoints. Spec: sdd/05_api_spec.md §Fix Flows"""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from app.core.auth import get_current_user
from app.core.database import get_db
from app.services import incident_service

router = APIRouter(tags=["fix_flows"])


class AttemptedRequest(BaseModel):
    is_attempted: bool


@router.patch("/fix-flows/{flow_id}/attempted")
async def mark_attempted(
    flow_id: str,
    body: AttemptedRequest,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Spec: PATCH /fix-flows/{id}/attempted — mark fix flow as attempted."""
    return await incident_service.mark_fix_flow_attempted(
        flow_id, body.is_attempted, current_user["user_id"], db
    )

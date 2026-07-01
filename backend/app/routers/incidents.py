"""
Incident endpoints. Spec: sdd/05_api_spec.md §Incidents
"""
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import get_current_user
from app.core.database import get_db
from app.schemas.incident import (
    AIActionTriggerResponse,
    AnalysisJobTriggerResponse,
    AnalyzeMetadataRequest,
    AnalyzeMetadataResponse,
    IncidentCreateRequest,
    IncidentListResponse,
    IncidentPatchRequest,
    IncidentResponse,
)
from app.services import incident_service
from app.services import ai_action_service

router = APIRouter(tags=["incidents"])


# ── Metadata extraction ────────────────────────────────────────────────────────

@router.post("/incidents/analyze-metadata", response_model=AnalyzeMetadataResponse)
async def analyze_metadata(
    body: AnalyzeMetadataRequest,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """POST /incidents/analyze-metadata — metadata extraction only, no DB write."""
    try:
        return await incident_service.extract_metadata_for_display(body.log_text, db)
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))


# ── Create incident ────────────────────────────────────────────────────────────

@router.post("/incidents", response_model=IncidentResponse, status_code=201)
async def create_incident(
    body: IncidentCreateRequest,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Creates incident immediately (no Gemini call in request path).
    Root cause analysis fires as a background task after the response is returned.
    """
    # Derive origin_type: use client-provided value or default to manual_text.
    origin_type = body.origin_type or "manual_text"

    incident_id, action_id = await incident_service.create_incident(
        body, current_user["user_id"], db, origin_type=origin_type
    )
    background_tasks.add_task(ai_action_service.run_background, action_id)
    return await incident_service.get_incident_detail(
        incident_id, current_user["user_id"], db
    )


# ── AI Actions ─────────────────────────────────────────────────────────────────

class AIActionRequest(BaseModel):
    action_type: str


@router.post(
    "/incidents/{incident_id}/ai-actions",
    response_model=AIActionTriggerResponse,
    status_code=202,
)
async def trigger_ai_action(
    incident_id: str,
    body: AIActionRequest,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Unified AI action endpoint. Accepts any registered action_type.
    Returns 202 with action metadata; the action runs asynchronously.
    Returns 409 if an active action already exists for this incident.
    Returns 422 if action_type is unknown or preconditions are not met.
    """
    try:
        action_id, attempt_number = await ai_action_service.request_action(
            incident_id=incident_id,
            action_type=body.action_type,
            user_id=current_user["user_id"],
            db=db,
        )
    except IntegrityError:
        raise HTTPException(409, "An AI action is already active for this incident")

    background_tasks.add_task(ai_action_service.run_background, action_id)
    return AIActionTriggerResponse(
        incident_id=incident_id,
        action_id=action_id,
        action_type=body.action_type,
        attempt_number=attempt_number,
        status="pending",
    )


# ── Backward-compat: legacy reanalysis endpoint ────────────────────────────────

@router.post(
    "/incidents/{incident_id}/analyze",
    response_model=AnalysisJobTriggerResponse,
    status_code=202,
    deprecated=True,
)
async def trigger_reanalysis_legacy(
    incident_id: str,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Deprecated. Use POST /incidents/{id}/ai-actions with action_type=root_cause_analysis.
    Kept for backward compatibility with clients that haven't migrated.
    """
    try:
        action_id, attempt_number = await ai_action_service.request_action(
            incident_id=incident_id,
            action_type="root_cause_analysis",
            user_id=current_user["user_id"],
            db=db,
        )
    except IntegrityError:
        raise HTTPException(409, "Analysis already active")

    background_tasks.add_task(ai_action_service.run_background, action_id)
    return AnalysisJobTriggerResponse(
        incident_id=incident_id,
        job_id=action_id,
        attempt_number=attempt_number,
        analysis_status="pending",
    )


# ── Read ───────────────────────────────────────────────────────────────────────

@router.get("/incidents", response_model=IncidentListResponse)
async def list_incidents(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """GET /incidents — returns all non-closed incidents for current user."""
    return await incident_service.get_dashboard_incidents(current_user["user_id"], db)


@router.get("/incidents/{incident_id}", response_model=IncidentResponse)
async def get_incident(
    incident_id: str,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """GET /incidents/{id} — full incident detail including primary_action."""
    return await incident_service.get_incident_detail(
        incident_id, current_user["user_id"], db
    )


# ── Mutations ──────────────────────────────────────────────────────────────────

@router.patch("/incidents/{incident_id}", response_model=IncidentResponse)
async def patch_incident(
    incident_id: str,
    body: IncidentPatchRequest,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """PATCH /incidents/{id} — attach fix flow or update status."""
    return await incident_service.patch_incident(
        incident_id, body, current_user["user_id"], db
    )


@router.patch("/incidents/{incident_id}/resolve")
async def resolve_incident(
    incident_id: str,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """PATCH /incidents/{id}/resolve — mark as resolved."""
    return await incident_service.resolve_incident(
        incident_id, current_user["user_id"], db
    )


@router.patch("/incidents/{incident_id}/reopen")
async def reopen_incident(
    incident_id: str,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """PATCH /incidents/{id}/reopen — transition resolved→in_progress."""
    return await incident_service.reopen_incident(
        incident_id, current_user["user_id"], db
    )


@router.patch("/incidents/{incident_id}/close")
async def close_incident(
    incident_id: str,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """PATCH /incidents/{id}/close — transition resolved→closed."""
    return await incident_service.close_incident(
        incident_id, current_user["user_id"], db
    )

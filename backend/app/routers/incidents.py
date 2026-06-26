"""
Incident endpoints. Spec: sdd/05_api_spec.md §Incidents
"""
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.auth import get_current_user
from app.core.database import get_db
from app.schemas.incident import (
    AnalyzeMetadataRequest, AnalyzeMetadataResponse,
    AnalysisJobTriggerResponse,
    IncidentCreateRequest, IncidentResponse,
    IncidentListResponse, IncidentPatchRequest,
)
from app.services import incident_service

router = APIRouter(tags=["incidents"])


@router.post("/incidents/analyze-metadata", response_model=AnalyzeMetadataResponse)
async def analyze_metadata(
    body: AnalyzeMetadataRequest,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Spec: POST /incidents/analyze-metadata — metadata extraction only, no DB write."""
    try:
        return await incident_service.extract_metadata_for_display(body.log_text, db)
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))


@router.post("/incidents", response_model=IncidentResponse, status_code=201)
async def create_incident(
    body: IncidentCreateRequest,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Creates incident immediately (no Gemini call in request path).
    Analysis fires as a background task after the response is returned.
    """
    incident_id, job_id = await incident_service.create_incident(
        body, current_user["user_id"], db
    )
    background_tasks.add_task(incident_service.execute_analysis, job_id)
    return await incident_service.get_incident_detail(
        incident_id, current_user["user_id"], db
    )


@router.post(
    "/incidents/{incident_id}/analyze",
    response_model=AnalysisJobTriggerResponse,
    status_code=202,
)
async def trigger_reanalysis(
    incident_id: str,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Triggers a new analysis run for an existing incident.
    Returns 409 if an active (non-orphaned) analysis job already exists.
    """
    try:
        job_id, attempt_number = await incident_service.trigger_reanalysis(
            incident_id, current_user["user_id"], db
        )
    except IntegrityError:
        # DB partial unique index fired — race condition between two concurrent requests
        raise HTTPException(status_code=409, detail="Analysis already active")
    background_tasks.add_task(incident_service.execute_analysis, job_id)
    return AnalysisJobTriggerResponse(
        incident_id=incident_id,
        job_id=job_id,
        attempt_number=attempt_number,
        analysis_status="pending",
    )


@router.get("/incidents", response_model=IncidentListResponse)
async def list_incidents(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Spec: GET /incidents — returns all non-closed incidents for current user."""
    return await incident_service.get_dashboard_incidents(current_user["user_id"], db)


@router.get("/incidents/{incident_id}", response_model=IncidentResponse)
async def get_incident(
    incident_id: str,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Spec: GET /incidents/{id} — full incident detail including analysis_status."""
    return await incident_service.get_incident_detail(incident_id, current_user["user_id"], db)


@router.patch("/incidents/{incident_id}", response_model=IncidentResponse)
async def patch_incident(
    incident_id: str,
    body: IncidentPatchRequest,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Spec: PATCH /incidents/{id} — attach fix flow or update status."""
    return await incident_service.patch_incident(incident_id, body, current_user["user_id"], db)


@router.patch("/incidents/{incident_id}/resolve")
async def resolve_incident(
    incident_id: str,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Spec: PATCH /incidents/{id}/resolve — mark as resolved."""
    return await incident_service.resolve_incident(incident_id, current_user["user_id"], db)


@router.patch("/incidents/{incident_id}/close")
async def close_incident(
    incident_id: str,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """PATCH /incidents/{id}/close — transition resolved incident to closed."""
    return await incident_service.close_incident(incident_id, current_user["user_id"], db)

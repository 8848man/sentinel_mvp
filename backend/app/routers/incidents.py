"""
Incident endpoints. Spec: sdd/05_api_spec.md §Incidents
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.auth import get_current_user
from app.core.database import get_db
from app.schemas.incident import (
    AnalyzeMetadataRequest, AnalyzeMetadataResponse,
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
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Spec: POST /incidents — creates incident + runs full AI analysis."""
    try:
        return await incident_service.create_and_analyze(body, current_user["user_id"], db)
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))


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
    """Spec: GET /incidents/{id} — full incident detail."""
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

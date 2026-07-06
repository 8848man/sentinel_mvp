from pydantic import BaseModel, Field, model_validator, ConfigDict
from typing import Any, Literal
from datetime import datetime
from uuid import UUID


SeverityEnum = Literal["critical", "major", "minor"]
StatusEnum = Literal["open", "in_progress", "resolved", "closed"]


# ── AI Action CTA ──────────────────────────────────────────────────────────────

class ActionDescriptor(BaseModel):
    """Renderable action descriptor. The frontend calls endpoint with payload.
    No knowledge of action type or AI capabilities required by the frontend."""
    label: str
    description: str | None = None
    endpoint: str
    payload: dict = {}


# ── Analyze metadata ───────────────────────────────────────────────────────────

class AnalyzeMetadataRequest(BaseModel):
    log_text: str = Field(..., min_length=10)


class AnalyzeMetadataResponse(BaseModel):
    suggested_id: str
    suggested_title: str
    suggested_severity: SeverityEnum
    detected_components: list[str]


# ── Create ─────────────────────────────────────────────────────────────────────

class IncidentCreateRequest(BaseModel):
    log_text: str = Field(..., min_length=10)
    title: str = Field(..., max_length=255)
    severity: SeverityEnum
    components: list[str] = []
    # Forward-compat: client may declare the origin (e.g. "ocr_image").
    # Optional; defaults to "manual_text" in the router when absent.
    origin_type: str | None = None


# ── Sub-responses ──────────────────────────────────────────────────────────────

class ChecklistItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    step_number: int
    description: str
    is_completed: bool
    updated_at: datetime


class FixFlowResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    title: str
    confidence: float
    is_attempted: bool
    generation: int
    checklist_items: list[ChecklistItemResponse]


class TimelineEventResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    actor_type: str
    event_type: str | None
    event: str
    ai_action_id: UUID | None = None
    occurred_at: datetime


class SimilarIncidentResponse(BaseModel):
    """
    Represents a resolved incident that is similar to the current one.
    model_validator remaps ORM SimilarIncident attributes to the response shape.
    """
    incident_id: str
    incident_code: str
    match_score: float

    @model_validator(mode="before")
    @classmethod
    def _from_orm(cls, v: Any) -> Any:
        if hasattr(v, "similar_to_id"):
            similar_to = v.similar_to
            return {
                "incident_id": str(v.similar_to_id),
                "incident_code": similar_to.incident_code if similar_to else "",
                "match_score": float(v.match_score),
            }
        return v


class NoteResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    incident_id: UUID
    content: str
    updated_at: datetime


# ── Full incident response ─────────────────────────────────────────────────────

class IncidentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    incident_code: str
    title: str
    description: str | None
    severity: SeverityEnum
    status: StatusEnum
    components: list[str]
    log_text: str
    root_cause: str | None
    confidence: float | None
    selected_fix_flow_id: UUID | None
    analysis_status: str
    analysis_error: str | None = None
    origin_type: str | None = None
    resolved_at: datetime | None
    created_at: datetime
    fix_flows: list[FixFlowResponse] = []
    similar_incidents: list[SimilarIncidentResponse] = []
    timeline: list[TimelineEventResponse] = []
    note: NoteResponse | None = None

    # AI Platform CTA fields — computed by incident_service, not from ORM.
    # primary_action: the single next action for the operator. None when AI is
    # working (show spinner based on analysis_status) or no action needed.
    primary_action: ActionDescriptor | None = None
    # secondary_actions: at most 2 available-but-non-primary actions.
    secondary_actions: list[ActionDescriptor] = []


# ── AI Action trigger response ─────────────────────────────────────────────────

class AIActionTriggerResponse(BaseModel):
    incident_id: str
    action_id: str
    action_type: str
    attempt_number: int
    status: str


# ── List schemas ───────────────────────────────────────────────────────────────

class IncidentListItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    incident_code: str
    title: str
    description: str | None
    severity: SeverityEnum
    status: StatusEnum
    analysis_status: str
    created_at: datetime


class IncidentListResponse(BaseModel):
    data: list[IncidentListItem]
    total: int


# ── Patch ──────────────────────────────────────────────────────────────────────

class IncidentPatchRequest(BaseModel):
    selected_fix_flow_id: UUID | None = None
    status: StatusEnum | None = None


# ── Backward-compat alias (deprecated, kept for existing callers) ──────────────

class AnalysisJobTriggerResponse(BaseModel):
    """Deprecated. Use AIActionTriggerResponse. Kept for backward compatibility."""
    incident_id: str
    job_id: str
    attempt_number: int
    analysis_status: str

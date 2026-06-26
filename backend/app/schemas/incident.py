from pydantic import BaseModel, Field, model_validator
from typing import Any, Literal
from datetime import datetime
from uuid import UUID


SeverityEnum = Literal["critical", "major", "minor"]
StatusEnum = Literal["open", "in_progress", "resolved", "closed"]


class AnalyzeMetadataRequest(BaseModel):
    log_text: str = Field(..., min_length=10)


class AnalyzeMetadataResponse(BaseModel):
    suggested_id: str
    suggested_title: str
    suggested_severity: SeverityEnum
    detected_components: list[str]


class IncidentCreateRequest(BaseModel):
    log_text: str = Field(..., min_length=10)
    title: str = Field(..., max_length=255)
    severity: SeverityEnum
    components: list[str] = []


class ChecklistItemResponse(BaseModel):
    id: UUID
    step_number: int
    description: str
    is_completed: bool
    updated_at: datetime

    class Config:
        from_attributes = True


class FixFlowResponse(BaseModel):
    id: UUID
    title: str
    confidence: float
    is_attempted: bool
    checklist_items: list[ChecklistItemResponse]

    class Config:
        from_attributes = True


class TimelineEventResponse(BaseModel):
    id: UUID
    event: str
    occurred_at: datetime

    class Config:
        from_attributes = True


class SimilarIncidentResponse(BaseModel):
    """
    Represents a resolved incident that is similar to the current one.

    Source is a SimilarIncident ORM row. The ORM has:
      - similar_to_id  → the ID of the referenced incident  (→ incident_id here)
      - similar_to     → the full Incident object            (→ incident_code here)
      - match_score    → similarity score

    The model_validator runs before field validation so we can remap ORM
    attributes to the expected response shape without any field aliasing.
    """

    incident_id: str
    incident_code: str
    match_score: float

    @model_validator(mode="before")
    @classmethod
    def _from_orm(cls, v: Any) -> Any:
        # When coming from an ORM SimilarIncident object, remap to the expected dict.
        if hasattr(v, "similar_to_id"):
            similar_to = v.similar_to  # must be eagerly loaded via selectinload
            return {
                "incident_id": str(v.similar_to_id),
                "incident_code": similar_to.incident_code if similar_to else "",
                "match_score": float(v.match_score),
            }
        return v


class NoteResponse(BaseModel):
    id: UUID
    incident_id: UUID
    content: str
    updated_at: datetime

    class Config:
        from_attributes = True


class IncidentResponse(BaseModel):
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
    resolved_at: datetime | None
    created_at: datetime
    fix_flows: list[FixFlowResponse] = []
    similar_incidents: list[SimilarIncidentResponse] = []
    timeline: list[TimelineEventResponse] = []
    note: NoteResponse | None = None

    class Config:
        from_attributes = True


class AnalysisJobTriggerResponse(BaseModel):
    incident_id: str
    job_id: str
    attempt_number: int
    analysis_status: str


class IncidentListItem(BaseModel):
    id: UUID
    incident_code: str
    title: str
    description: str | None
    severity: SeverityEnum
    status: StatusEnum
    created_at: datetime

    class Config:
        from_attributes = True


class IncidentPatchRequest(BaseModel):
    selected_fix_flow_id: UUID | None = None
    status: StatusEnum | None = None


class IncidentListResponse(BaseModel):
    data: list[IncidentListItem]
    total: int

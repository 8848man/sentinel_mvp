from pydantic import BaseModel, Field
from typing import Literal
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
    incident_id: UUID
    incident_code: str
    match_score: float


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
    resolved_at: datetime | None
    created_at: datetime
    fix_flows: list[FixFlowResponse] = []
    similar_incidents: list[SimilarIncidentResponse] = []
    timeline: list[TimelineEventResponse] = []
    note: NoteResponse | None = None

    class Config:
        from_attributes = True


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

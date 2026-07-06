"""SQLAlchemy ORM models. Must match sdd/06_database_schema.md exactly."""
from datetime import datetime, timezone
from uuid import uuid4, uuid5, NAMESPACE_URL
from sqlalchemy import (
    DateTime, String, Text, Numeric, Boolean, SmallInteger, Integer,
    JSON, ForeignKey, UniqueConstraint, TypeDecorator, Index, text,
)
from sqlalchemy.dialects.postgresql import ARRAY as PG_ARRAY
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.core.database import Base


def _uuid():
    return str(uuid4())


def _now():
    return datetime.now(timezone.utc)


def _user_id_for(email: str) -> str:
    """Deterministic UUID5 so the same email always maps to the same user_id."""
    return str(uuid5(NAMESPACE_URL, f"sentinel-local-user:{email.strip().lower()}"))


class TextListType(TypeDecorator):
    """Stores list[str] as PostgreSQL TEXT[] or JSON in SQLite/other databases."""
    impl = JSON
    cache_ok = True

    def load_dialect_impl(self, dialect):
        if dialect.name == "postgresql":
            return dialect.type_descriptor(PG_ARRAY(Text))
        return dialect.type_descriptor(JSON())

    def process_bind_param(self, value, dialect):
        return value if value is not None else []

    def process_result_value(self, value, dialect):
        return value if value is not None else []


class IncidentSequence(Base):
    __tablename__ = "incident_sequence"
    year: Mapped[int] = mapped_column(SmallInteger, primary_key=True)
    next_seq: Mapped[int] = mapped_column(default=1)


class User(Base):
    __tablename__ = "users"
    user_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    password: Mapped[str] = mapped_column(String(255), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class Incident(Base):
    __tablename__ = "incidents"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(String(36), nullable=False, index=True)
    incident_code: Mapped[str] = mapped_column(String(20), unique=True, nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    log_text: Mapped[str] = mapped_column(Text, nullable=False)
    severity: Mapped[str] = mapped_column(String(20), nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="open", index=True)
    components: Mapped[list[str]] = mapped_column(TextListType, default=list)
    root_cause: Mapped[str | None] = mapped_column(Text)
    confidence: Mapped[float | None] = mapped_column(Numeric(4, 3))
    # FK constraint deferred to SQL migration to avoid circular dependency.
    selected_fix_flow_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    analysis_status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="pending"
    )
    analysis_error: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Amendment A: forward-compat hook for Origin concept.
    # Values: "manual_text" | "ocr_image" | "webhook" | None (unknown/legacy).
    origin_type: Mapped[str | None] = mapped_column(String(50), nullable=True)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, onupdate=_now)

    fix_flows: Mapped[list["FixFlow"]] = relationship(
        "FixFlow",
        foreign_keys="FixFlow.incident_id",
        back_populates="incident",
        cascade="all, delete-orphan",
        order_by="FixFlow.generation, FixFlow.sort_order",
    )
    timeline: Mapped[list["TimelineEvent"]] = relationship(
        back_populates="incident",
        cascade="all, delete-orphan",
        order_by="TimelineEvent.occurred_at",
    )
    similar_incidents: Mapped[list["SimilarIncident"]] = relationship(
        foreign_keys="SimilarIncident.incident_id",
        back_populates="incident",
        cascade="all, delete-orphan",
    )
    note: Mapped["Note | None"] = relationship(
        back_populates="incident",
        cascade="all, delete-orphan",
        uselist=False,
    )
    ai_actions: Mapped[list["AIAction"]] = relationship(
        "AIAction",
        back_populates="incident",
        cascade="all, delete-orphan",
        order_by="AIAction.created_at",
    )


class FixFlow(Base):
    __tablename__ = "fix_flows"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    incident_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("incidents.id", ondelete="CASCADE"), nullable=False, index=True
    )
    # Which AIAction produced this fix flow. Nullable for pre-platform rows.
    source_action_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("ai_actions.id", ondelete="SET NULL"), nullable=True
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    confidence: Mapped[float] = mapped_column(Numeric(4, 3), nullable=False)
    is_attempted: Mapped[bool] = mapped_column(Boolean, default=False)
    # Generation counter: 1 = initial analysis, 2 = first improved, etc.
    # Fix flows are never deleted — new analyses add a higher generation.
    generation: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=1)
    sort_order: Mapped[int] = mapped_column(SmallInteger, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    incident: Mapped["Incident"] = relationship(
        "Incident", foreign_keys=[incident_id], back_populates="fix_flows"
    )
    checklist_items: Mapped[list["ChecklistItem"]] = relationship(
        back_populates="fix_flow",
        cascade="all, delete-orphan",
        order_by="ChecklistItem.step_number",
    )
    source_action: Mapped["AIAction | None"] = relationship(
        "AIAction", foreign_keys=[source_action_id], back_populates="produced_fix_flows"
    )


class ChecklistItem(Base):
    __tablename__ = "checklist_items"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    fix_flow_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("fix_flows.id", ondelete="CASCADE"), nullable=False, index=True
    )
    step_number: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, onupdate=_now)

    fix_flow: Mapped["FixFlow"] = relationship(back_populates="checklist_items")


class Note(Base):
    __tablename__ = "notes"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    incident_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("incidents.id", ondelete="CASCADE"), nullable=False, unique=True
    )
    content: Mapped[str] = mapped_column(Text, default="")
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, onupdate=_now)

    incident: Mapped["Incident"] = relationship(back_populates="note")


class TimelineEvent(Base):
    """
    Unified history of all human, system, and AI events on an incident.

    Responsibility split:
      - actor_type="ai": projection of an AIAction. Source of truth is the
        AIAction record; this event is a derived display summary. Linked via
        ai_action_id.
      - actor_type="operator": operator action (fix flow selection, note save,
        checklist toggle, status change).
      - actor_type="system": automated system transitions (incident created,
        analysis queued, etc.).

    The `event` text field is the human-readable summary used for display.
    It is backward-compatible with pre-platform events which have no actor_type.
    """
    __tablename__ = "timeline_events"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    incident_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("incidents.id", ondelete="CASCADE"), nullable=False, index=True
    )
    actor_type: Mapped[str] = mapped_column(
        String(20), nullable=False, default="system"
    )
    # Typed slug for structured processing. Nullable for pre-platform rows.
    event_type: Mapped[str | None] = mapped_column(String(100), nullable=True)
    # Human-readable display string. Always present (backward compat).
    event: Mapped[str] = mapped_column(Text, nullable=False)
    # Present when actor_type="ai". References the AIAction that produced this event.
    ai_action_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("ai_actions.id", ondelete="SET NULL"), nullable=True
    )
    # Optional lightweight display metadata (e.g. action display name).
    # Column name is "metadata" in DB; attribute renamed to avoid SQLAlchemy reserved word.
    event_metadata: Mapped[dict | None] = mapped_column("metadata", JSON, nullable=True)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    incident: Mapped["Incident"] = relationship(back_populates="timeline")
    ai_action: Mapped["AIAction | None"] = relationship(
        "AIAction", foreign_keys=[ai_action_id], back_populates="timeline_events"
    )


class SimilarIncident(Base):
    __tablename__ = "similar_incidents"
    __table_args__ = (UniqueConstraint("incident_id", "similar_to_id"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    incident_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("incidents.id", ondelete="CASCADE"), nullable=False, index=True
    )
    similar_to_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("incidents.id", ondelete="CASCADE"), nullable=False
    )
    match_score: Mapped[float] = mapped_column(Numeric(4, 3), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    incident: Mapped["Incident"] = relationship(
        "Incident", foreign_keys=[incident_id], back_populates="similar_incidents"
    )
    similar_to: Mapped["Incident"] = relationship(
        "Incident", foreign_keys=[similar_to_id]
    )


class AIAction(Base):
    """
    Source of truth for every AI action run on an incident.

    Intent fields (what was requested):
        incident_id, action_type, requested_by, parent_action_id, created_at

    Execution fields (how it ran — logical boundary for future AIActionExecution split):
        status, attempt_number, input_snapshot, output, output_schema_version,
        model_id, error_message, started_at, completed_at

    Legacy fields (from analysis_jobs era — kept for historical rows):
        is_inferred: True for rows backfilled by migration; never set on new rows.

    Invariant: incidents.analysis_status is a denormalized cache of this table.
    """
    __tablename__ = "ai_actions"
    __table_args__ = (
        # At most one active (pending or processing) action per incident.
        # DB-level enforcement; application SELECT check is a fast-path only.
        Index(
            "uix_ai_actions_incident_active",
            "incident_id",
            unique=True,
            sqlite_where=text("status IN ('pending', 'processing')"),
            postgresql_where=text("status IN ('pending', 'processing')"),
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    incident_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("incidents.id", ondelete="CASCADE"), nullable=False, index=True
    )
    # ── Intent fields ──────────────────────────────────────────────────────────
    action_type: Mapped[str] = mapped_column(
        String(100), nullable=False, default="root_cause_analysis"
    )
    requested_by: Mapped[str] = mapped_column(
        String(20), nullable=False, default="system"
    )
    parent_action_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("ai_actions.id", ondelete="SET NULL"), nullable=True
    )
    # ── Execution fields ───────────────────────────────────────────────────────
    attempt_number: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="pending")
    # Structured snapshot of what was fed to the model (metadata, not raw text).
    input_snapshot: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    # Raw parsed model output. Structure varies by action_type; see handler.
    output: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    # Handler-declared schema version. Bump when parse_output structure changes.
    output_schema_version: Mapped[str | None] = mapped_column(String(20), nullable=True)
    model_id: Mapped[str | None] = mapped_column(String(100), nullable=True)
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    # ── Legacy field ───────────────────────────────────────────────────────────
    # True for rows backfilled by a1b2c3d4e5f6 migration. Never set on new rows.
    is_inferred: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    # Legacy from analysis_jobs era. Superseded by input_snapshot.
    input_char_count: Mapped[int | None] = mapped_column(Integer, nullable=True)

    incident: Mapped["Incident"] = relationship("Incident", back_populates="ai_actions")
    produced_fix_flows: Mapped[list["FixFlow"]] = relationship(
        "FixFlow",
        foreign_keys="FixFlow.source_action_id",
        back_populates="source_action",
    )
    timeline_events: Mapped[list["TimelineEvent"]] = relationship(
        "TimelineEvent",
        foreign_keys="TimelineEvent.ai_action_id",
        back_populates="ai_action",
    )
    parent_action: Mapped["AIAction | None"] = relationship(
        "AIAction", remote_side="AIAction.id", foreign_keys=[parent_action_id]
    )

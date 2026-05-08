"""SQLAlchemy ORM models. Must match sdd/06_database_schema.md exactly."""
from datetime import datetime, timezone
from uuid import uuid4, uuid5, NAMESPACE_URL
from sqlalchemy import String, Text, Numeric, Boolean, SmallInteger, JSON, ForeignKey, UniqueConstraint, TypeDecorator
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
    created_at: Mapped[datetime] = mapped_column(default=_now)


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
    # FK constraint is deferred to the SQL migration (001_initial_schema.sql) to avoid
    # the circular dependency between incidents↔fix_flows that requires ALTER TABLE,
    # which SQLite does not support.
    selected_fix_flow_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    resolved_at: Mapped[datetime | None] = mapped_column(nullable=True)
    created_at: Mapped[datetime] = mapped_column(default=_now)
    updated_at: Mapped[datetime] = mapped_column(default=_now, onupdate=_now)

    fix_flows: Mapped[list["FixFlow"]] = relationship("FixFlow", foreign_keys="FixFlow.incident_id", back_populates="incident", cascade="all, delete-orphan")
    timeline: Mapped[list["TimelineEvent"]] = relationship(back_populates="incident", cascade="all, delete-orphan", order_by="TimelineEvent.occurred_at")
    similar_incidents: Mapped[list["SimilarIncident"]] = relationship(foreign_keys="SimilarIncident.incident_id", back_populates="incident", cascade="all, delete-orphan")
    note: Mapped["Note | None"] = relationship(back_populates="incident", cascade="all, delete-orphan", uselist=False)


class FixFlow(Base):
    __tablename__ = "fix_flows"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    incident_id: Mapped[str] = mapped_column(String(36), ForeignKey("incidents.id", ondelete="CASCADE"), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    confidence: Mapped[float] = mapped_column(Numeric(4, 3), nullable=False)
    is_attempted: Mapped[bool] = mapped_column(Boolean, default=False)
    sort_order: Mapped[int] = mapped_column(SmallInteger, default=0)
    created_at: Mapped[datetime] = mapped_column(default=_now)

    incident: Mapped["Incident"] = relationship("Incident", foreign_keys=[incident_id], back_populates="fix_flows")
    checklist_items: Mapped[list["ChecklistItem"]] = relationship(back_populates="fix_flow", cascade="all, delete-orphan", order_by="ChecklistItem.step_number")


class ChecklistItem(Base):
    __tablename__ = "checklist_items"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    fix_flow_id: Mapped[str] = mapped_column(String(36), ForeignKey("fix_flows.id", ondelete="CASCADE"), nullable=False, index=True)
    step_number: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False)
    updated_at: Mapped[datetime] = mapped_column(default=_now, onupdate=_now)

    fix_flow: Mapped["FixFlow"] = relationship(back_populates="checklist_items")


class Note(Base):
    __tablename__ = "notes"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    incident_id: Mapped[str] = mapped_column(String(36), ForeignKey("incidents.id", ondelete="CASCADE"), nullable=False, unique=True)
    content: Mapped[str] = mapped_column(Text, default="")
    updated_at: Mapped[datetime] = mapped_column(default=_now, onupdate=_now)

    incident: Mapped["Incident"] = relationship(back_populates="note")


class TimelineEvent(Base):
    __tablename__ = "timeline_events"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    incident_id: Mapped[str] = mapped_column(String(36), ForeignKey("incidents.id", ondelete="CASCADE"), nullable=False, index=True)
    event: Mapped[str] = mapped_column(Text, nullable=False)
    occurred_at: Mapped[datetime] = mapped_column(default=_now)

    incident: Mapped["Incident"] = relationship(back_populates="timeline")


class SimilarIncident(Base):
    __tablename__ = "similar_incidents"
    __table_args__ = (UniqueConstraint("incident_id", "similar_to_id"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    incident_id: Mapped[str] = mapped_column(String(36), ForeignKey("incidents.id", ondelete="CASCADE"), nullable=False, index=True)
    similar_to_id: Mapped[str] = mapped_column(String(36), ForeignKey("incidents.id", ondelete="CASCADE"), nullable=False)
    match_score: Mapped[float] = mapped_column(Numeric(4, 3), nullable=False)
    created_at: Mapped[datetime] = mapped_column(default=_now)

    incident: Mapped["Incident"] = relationship("Incident", foreign_keys=[incident_id], back_populates="similar_incidents")
    similar_to: Mapped["Incident"] = relationship("Incident", foreign_keys=[similar_to_id])

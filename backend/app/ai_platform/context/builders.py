"""Primitive async context builder functions.

Each function returns one typed context object. Handlers compose them.
All functions are pure relative to their inputs — no side effects beyond DB reads.

Truncation: log_text is truncated here using the same head+tail strategy as
the legacy _truncate_log helper. The truncated text and metadata are captured
in CoreIncidentContext for use in input_snapshot and prompt construction.
"""
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.models import Incident, FixFlow, Note, SimilarIncident
from app.ai_platform.context.types import (
    CoreIncidentContext,
    RootCauseContext,
    AttemptedFlowSummary,
    AttemptedFlowsContext,
    OperatorNotesContext,
    SimilarIncidentSummary,
    SimilarIncidentsContext,
)


def build_core_context(incident: Incident) -> CoreIncidentContext:
    """Truncates log and captures core incident fields. No DB access."""
    log_text, char_count, truncated = _truncate_log(incident.log_text)
    return CoreIncidentContext(
        log_text=log_text,
        log_truncated=truncated,
        char_count=char_count,
        title=incident.title,
        severity=incident.severity,
        components=list(incident.components),
        origin_type=incident.origin_type,
    )


def build_root_cause_context(incident: Incident) -> RootCauseContext:
    """Reads cached root cause from the incident. No DB access."""
    return RootCauseContext(
        root_cause=incident.root_cause,
        confidence=float(incident.confidence) if incident.confidence is not None else None,
        source_action_id=None,  # not tracked on the incident cache; use AIAction query if needed
    )


def build_attempted_flows_context(incident: Incident) -> AttemptedFlowsContext:
    """Reads attempted fix flows from the eagerly-loaded relationship. No DB access."""
    attempted = [f for f in incident.fix_flows if f.is_attempted]
    summaries = [
        AttemptedFlowSummary(
            title=flow.title,
            steps=[item.description for item in flow.checklist_items],
            generation=flow.generation,
        )
        for flow in attempted
    ]
    return AttemptedFlowsContext(flows=summaries)


async def build_operator_notes_context(
    incident: Incident, db: AsyncSession
) -> OperatorNotesContext:
    """Fetches operator note. Returns empty string when no note exists."""
    result = await db.execute(
        select(Note).where(Note.incident_id == incident.id)
    )
    note = result.scalar_one_or_none()
    return OperatorNotesContext(content=note.content if note else "")


async def build_similar_incidents_context(
    incident: Incident, db: AsyncSession
) -> SimilarIncidentsContext:
    """Finds resolved/closed incidents sharing at least one component. Limit 3."""
    if not incident.components:
        return SimilarIncidentsContext(pairs=[], formatted="None available.")

    result = await db.execute(
        select(Incident)
        .where(
            Incident.user_id == incident.user_id,
            Incident.status.in_(["resolved", "closed"]),
            Incident.id != incident.id,
        )
        .order_by(Incident.created_at.desc())
        .limit(10)
    )
    candidates = result.scalars().all()
    matches = [
        SimilarIncidentSummary(incident_id=str(c.id), incident_code=c.incident_code)
        for c in candidates
        if any(comp in c.components for comp in incident.components)
    ][:3]

    if not matches:
        return SimilarIncidentsContext(pairs=[], formatted="None available.")

    formatted = "\n".join(f"- {m.incident_code}" for m in matches)
    return SimilarIncidentsContext(pairs=matches, formatted=formatted)


# ── Internal helper ───────────────────────────────────────────────────────────

def _truncate_log(log_text: str) -> tuple[str, int, bool]:
    """Returns (text, char_count, was_truncated)."""
    max_chars = settings.MAX_ANALYSIS_INPUT_CHARS
    if len(log_text) <= max_chars:
        return log_text, len(log_text), False
    half = max_chars // 2
    omitted = len(log_text) - max_chars
    truncated = (
        log_text[:half]
        + f"\n\n[...{omitted} characters omitted for analysis...]\n\n"
        + log_text[-half:]
    )
    return truncated, len(truncated), True

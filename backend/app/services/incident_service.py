"""
Business logic for all incident operations.
Routers call these functions; never call gemini_service directly from routers.

AI execution is delegated to ai_action_service. compute_primary_action and
compute_secondary_actions drive the frontend's primary CTA without the frontend
needing to understand AI capabilities.
"""
from datetime import datetime, timezone
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import select, delete, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import settings
from app.models.models import (
    Incident, FixFlow, ChecklistItem, Note, TimelineEvent,
    SimilarIncident, IncidentSequence, AIAction,
)
from app.schemas.incident import IncidentCreateRequest, IncidentPatchRequest, IncidentResponse
from app.services import gemini_service


# ── Metadata extraction (no DB write) ─────────────────────────────────────────

async def extract_metadata_for_display(log_text: str, db: AsyncSession) -> dict:
    ai_result = await gemini_service.extract_metadata(log_text)
    year = datetime.now(timezone.utc).year
    suggested_id = await _next_incident_code(year, db, commit=False)
    return {
        "suggested_id": suggested_id,
        "suggested_title": ai_result.get("suggested_title", ""),
        "suggested_severity": ai_result.get("suggested_severity", "minor"),
        "detected_components": ai_result.get("detected_components", []),
    }


# ── Create Incident ────────────────────────────────────────────────────────────

async def create_incident(
    body: IncidentCreateRequest,
    user_id: str,
    db: AsyncSession,
    origin_type: str | None = None,
) -> tuple[str, str]:
    """
    Creates incident + first AIAction row in a single atomic transaction.
    Returns (incident_id, action_id). Caller fires ai_action_service.run_background
    as a background task.
    """
    async with db.begin():
        year = datetime.now(timezone.utc).year
        incident_code = await _next_incident_code(year, db, commit=True)

        incident = Incident(
            user_id=user_id,
            incident_code=incident_code,
            title=body.title,
            log_text=body.log_text,
            severity=body.severity,
            components=body.components,
            analysis_status="pending",
            origin_type=origin_type,
        )
        db.add(incident)
        await db.flush()

        db.add(TimelineEvent(
            incident_id=incident.id,
            actor_type="system",
            event_type="incident_created",
            event="Alert triggered",
        ))

        from app.ai_platform.registry import get_handler as _get_handler
        handler = _get_handler("root_cause_analysis")
        display = handler.display_name.lower() if handler else "root cause analysis"

        action = AIAction(
            incident_id=incident.id,
            action_type="root_cause_analysis",
            requested_by="system",
            attempt_number=1,
            status="pending",
        )
        db.add(action)
        db.add(TimelineEvent(
            incident_id=incident.id,
            actor_type="ai",
            event_type="ai_action_queued",
            event=f"AI {display} queued",
            ai_action_id=action.id,
            event_metadata={"action_type": "root_cause_analysis"},
        ))
        await db.flush()

        incident_id = str(incident.id)
        action_id = str(action.id)

    return incident_id, action_id


# ── Detail (returns IncidentResponse with computed CTA fields) ─────────────────

async def get_incident_detail(
    incident_id: str, user_id: str, db: AsyncSession
) -> IncidentResponse:
    result = await db.execute(
        select(Incident)
        .options(
            selectinload(Incident.fix_flows).selectinload(FixFlow.checklist_items),
            selectinload(Incident.timeline),
            selectinload(Incident.similar_incidents).selectinload(
                SimilarIncident.similar_to
            ),
            selectinload(Incident.note),
        )
        .where(Incident.id == incident_id)
    )
    incident = result.scalar_one_or_none()
    if not incident:
        raise HTTPException(404, "Incident not found")
    if str(incident.user_id) != user_id:
        raise HTTPException(403, "Forbidden")

    base = IncidentResponse.model_validate(incident)
    return base.model_copy(update={
        "primary_action": compute_primary_action(incident),
        "secondary_actions": compute_secondary_actions(incident),
    })


# ── Primary and secondary action computation ───────────────────────────────────

def compute_primary_action(incident: Incident) -> dict | None:
    """
    Pure function: (Incident state) → renderable primary_action descriptor.
    Returns None when AI is working (spinner) or no action is appropriate.
    Called at serialization time; fix_flows must be eagerly loaded.
    """
    from app.ai_platform.registry import PRIORITY_ORDER

    # AI is actively working — show spinner, no button.
    if incident.analysis_status in ("pending", "processing"):
        return None

    # AI handlers compete for the primary slot in priority order.
    for handler in PRIORITY_ORDER:
        if handler.is_primary_for(incident):
            return handler.primary_action_descriptor(incident)

    # Lifecycle fallback.
    return _lifecycle_primary_action(incident)


def compute_secondary_actions(incident: Incident) -> list[dict]:
    """
    Returns at most two secondary action descriptors for the current state.
    Always computed alongside compute_primary_action; fix_flows must be loaded.
    """
    from app.ai_platform.registry import PRIORITY_ORDER

    # If a handler is primary, collect its secondary actions.
    for handler in PRIORITY_ORDER:
        if handler.is_primary_for(incident):
            actions = handler.secondary_actions_for(incident)
            return actions[:2]

    # Lifecycle secondaries.
    return _lifecycle_secondary_actions(incident)


def _lifecycle_primary_action(incident: Incident) -> dict | None:
    sid = str(incident.id)
    if incident.status == "in_progress":
        return {
            "label": "Mark Resolved",
            "description": None,
            "endpoint": f"/api/v1/incidents/{sid}/resolve",
            "payload": {},
        }
    if incident.status == "resolved":
        return {
            "label": "Close Incident",
            "description": None,
            "endpoint": f"/api/v1/incidents/{sid}/close",
            "payload": {},
        }
    return None


def _lifecycle_secondary_actions(incident: Incident) -> list[dict]:
    sid = str(incident.id)
    actions = []
    if incident.status == "resolved":
        actions.append({
            "label": "Mark In Progress",
            "description": None,
            "endpoint": f"/api/v1/incidents/{sid}/reopen",
            "payload": {},
        })
    return actions[:2]


# ── Dashboard list ─────────────────────────────────────────────────────────────

async def get_dashboard_incidents(user_id: str, db: AsyncSession) -> dict:
    result = await db.execute(
        select(Incident)
        .where(Incident.user_id == user_id, Incident.status != "closed")
        .order_by(Incident.created_at.desc())
    )
    incidents = result.scalars().all()
    return {"data": incidents, "total": len(incidents)}


# ── Patch ──────────────────────────────────────────────────────────────────────

async def patch_incident(
    incident_id: str,
    body: IncidentPatchRequest,
    user_id: str,
    db: AsyncSession,
) -> IncidentResponse:
    async with db.begin():
        incident = await _get_owned(incident_id, user_id, db)
        if body.selected_fix_flow_id:
            fix_flow_id = str(body.selected_fix_flow_id)
            incident.selected_fix_flow_id = fix_flow_id
            flow = await db.get(FixFlow, fix_flow_id)
            if flow:
                db.add(TimelineEvent(
                    incident_id=incident.id,
                    actor_type="operator",
                    event_type="fix_flow_selected",
                    event=f"Fix Flow attached: {flow.title}",
                ))
                # Auto-transition to in_progress when a fix flow is selected.
                if incident.status == "open":
                    incident.status = "in_progress"
        if body.status:
            incident.status = body.status
    return await get_incident_detail(incident_id, user_id, db)


async def resolve_incident(
    incident_id: str, user_id: str, db: AsyncSession
) -> dict:
    async with db.begin():
        incident = await _get_owned(incident_id, user_id, db)
        incident.status = "resolved"
        incident.resolved_at = datetime.now(timezone.utc)
        db.add(TimelineEvent(
            incident_id=incident.id,
            actor_type="operator",
            event_type="incident_resolved",
            event="Incident resolved",
        ))

    # ── Lifecycle hook: fire system-triggered actions post-commit ──────────────
    await _fire_lifecycle_hooks("incident.resolved", incident_id)

    return {
        "id": incident_id,
        "status": "resolved",
        "resolved_at": incident.resolved_at,
    }


async def reopen_incident(
    incident_id: str, user_id: str, db: AsyncSession
) -> dict:
    async with db.begin():
        incident = await _get_owned(incident_id, user_id, db)
        incident.status = "in_progress"
        db.add(TimelineEvent(
            incident_id=incident.id,
            actor_type="operator",
            event_type="incident_reopened",
            event="Incident reopened",
        ))
    return {"id": incident_id, "status": "in_progress"}


async def close_incident(
    incident_id: str, user_id: str, db: AsyncSession
) -> dict:
    async with db.begin():
        incident = await _get_owned(incident_id, user_id, db)
        incident.status = "closed"
        db.add(TimelineEvent(
            incident_id=incident.id,
            actor_type="operator",
            event_type="incident_closed",
            event="Incident closed",
        ))
    return {"id": incident_id, "status": "closed"}


# ── Checklist ──────────────────────────────────────────────────────────────────

async def toggle_checklist_item(
    item_id: str, is_completed: bool, user_id: str, db: AsyncSession
):
    async with db.begin():
        item = await db.get(ChecklistItem, item_id)
        if not item:
            raise HTTPException(404, "Checklist item not found")
        flow = await db.get(FixFlow, item.fix_flow_id)
        incident = await _get_owned(str(flow.incident_id), user_id, db)
        item.is_completed = is_completed
        if is_completed:
            db.add(TimelineEvent(
                incident_id=incident.id,
                actor_type="operator",
                event_type="checklist_step_completed",
                event=f"Step '{item.description[:60]}' completed",
            ))
    return {"id": item.id, "is_completed": item.is_completed, "updated_at": item.updated_at}


# ── Notes ──────────────────────────────────────────────────────────────────────

async def upsert_note(
    incident_id: str, content: str, user_id: str, db: AsyncSession
):
    async with db.begin():
        await _get_owned(incident_id, user_id, db)
        result = await db.execute(select(Note).where(Note.incident_id == incident_id))
        note = result.scalar_one_or_none()
        if note:
            note.content = content
            note.updated_at = datetime.now(timezone.utc)
        else:
            note = Note(incident_id=incident_id, content=content)
            db.add(note)
    return note


# ── Timeline ───────────────────────────────────────────────────────────────────

async def get_timeline(incident_id: str, user_id: str, db: AsyncSession):
    await _get_owned(incident_id, user_id, db)
    result = await db.execute(
        select(TimelineEvent)
        .where(TimelineEvent.incident_id == incident_id)
        .order_by(TimelineEvent.occurred_at)
    )
    events = result.scalars().all()
    return {"data": events}


# ── Fix flow attempted ─────────────────────────────────────────────────────────

async def mark_fix_flow_attempted(
    flow_id: str, is_attempted: bool, user_id: str, db: AsyncSession
):
    async with db.begin():
        flow = await db.get(FixFlow, flow_id)
        if not flow:
            raise HTTPException(404, "Fix flow not found")
        incident = await _get_owned(str(flow.incident_id), user_id, db)
        flow.is_attempted = is_attempted
        if is_attempted:
            db.add(TimelineEvent(
                incident_id=incident.id,
                actor_type="operator",
                event_type="fix_flow_attempted",
                event=f"Fix flow '{flow.title[:60]}' marked attempted",
            ))
    return {"id": flow.id, "is_attempted": flow.is_attempted}


# ── Archive ────────────────────────────────────────────────────────────────────

async def get_archive_incidents(user_id: str, db: AsyncSession):
    result = await db.execute(
        select(Incident)
        .where(Incident.user_id == user_id, Incident.status == "closed")
        .order_by(Incident.resolved_at.desc())
    )
    incidents = result.scalars().all()
    data = []
    for inc in incidents:
        mins = None
        if inc.resolved_at and inc.created_at:
            delta = inc.resolved_at - inc.created_at
            mins = int(delta.total_seconds() / 60)
        data.append({
            "id": inc.id,
            "incident_code": inc.incident_code,
            "title": inc.title,
            "severity": inc.severity,
            "status": inc.status,
            "resolved_at": inc.resolved_at,
            "resolution_time_minutes": mins,
        })
    return {"data": data, "total": len(data)}


# ── Lifecycle hooks ────────────────────────────────────────────────────────────

async def _fire_lifecycle_hooks(event: str, incident_id: str) -> None:
    """Check the handler registry for system-triggered actions on this event."""
    from app.ai_platform.registry import all_system_triggers
    from app.services.ai_action_service import create_system_action, run_background

    for handler in all_system_triggers(event):
        action_id = await create_system_action(incident_id, handler.action_type)
        if action_id:
            import asyncio
            asyncio.create_task(run_background(action_id))


# ── Helpers ────────────────────────────────────────────────────────────────────

async def _get_owned(
    incident_id: str, user_id: str, db: AsyncSession
) -> Incident:
    incident = await db.get(Incident, incident_id)
    if not incident:
        raise HTTPException(404, "Incident not found")
    if str(incident.user_id) != user_id:
        raise HTTPException(403, "Forbidden")
    return incident


async def _next_incident_code(year: int, db: AsyncSession, commit: bool) -> str:
    result = await db.execute(
        select(IncidentSequence).where(IncidentSequence.year == year).with_for_update()
    )
    seq_row = result.scalar_one_or_none()
    if seq_row:
        seq = seq_row.next_seq
        seq_row.next_seq += 1
    else:
        seq = 1
        db.add(IncidentSequence(year=year, next_seq=2))
    return f"INC-{year}-{str(seq).zfill(3)}"

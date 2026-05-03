"""
Business logic for all incident operations.
Routers call these functions; never call gemini_service directly from routers.
"""
from datetime import datetime, timezone
from uuid import UUID
from fastapi import HTTPException
from sqlalchemy import select, extract
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from app.models.models import Incident, FixFlow, ChecklistItem, Note, TimelineEvent, SimilarIncident, IncidentSequence
from app.schemas.incident import IncidentCreateRequest, IncidentPatchRequest
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


# ── Create + Analyze ───────────────────────────────────────────────────────────

async def create_and_analyze(body: IncidentCreateRequest, user_id: str, db: AsyncSession) -> Incident:
    async with db.begin():
        year = datetime.now(timezone.utc).year
        incident_code = await _next_incident_code(year, db, commit=True)

        similar_ctx, similar_pairs = await _build_similar_context(body.components, user_id, db)
        ai = await gemini_service.analyze_incident(
            body.log_text, body.title, body.severity, body.components, similar_ctx
        )

        incident = Incident(
            user_id=user_id,
            incident_code=incident_code,
            title=body.title,
            description=ai.get("impact_summary"),
            log_text=body.log_text,
            severity=body.severity,
            components=body.components,
            root_cause=ai.get("root_cause"),
            confidence=ai.get("confidence"),
        )
        db.add(incident)
        await db.flush()

        db.add(TimelineEvent(incident_id=incident.id, event="Alert triggered"))
        db.add(TimelineEvent(incident_id=incident.id, event="AI analysis completed"))

        for i, flow_data in enumerate(ai.get("fix_flows", [])):
            flow = FixFlow(
                incident_id=incident.id,
                title=flow_data["title"],
                confidence=flow_data["confidence"],
                sort_order=i,
            )
            db.add(flow)
            await db.flush()
            for j, step in enumerate(flow_data.get("checklist_items", []), start=1):
                db.add(ChecklistItem(fix_flow_id=flow.id, step_number=j, description=step))

        for sim_id, sim_code in similar_pairs[:3]:
            score = next((s["match_score"] for s in ai.get("similar_incidents", [])
                          if s.get("incident_code") == sim_code), 0.80)
            db.add(SimilarIncident(incident_id=incident.id, similar_to_id=sim_id, match_score=score))

    return await get_incident_detail(str(incident.id), user_id, db)


# ── Dashboard list ─────────────────────────────────────────────────────────────

async def get_dashboard_incidents(user_id: str, db: AsyncSession) -> dict:
    result = await db.execute(
        select(Incident)
        .where(Incident.user_id == user_id, Incident.status != "closed")
        .order_by(Incident.created_at.desc())
    )
    incidents = result.scalars().all()
    return {"data": incidents, "total": len(incidents)}


# ── Detail ─────────────────────────────────────────────────────────────────────

async def get_incident_detail(incident_id: str, user_id: str, db: AsyncSession) -> Incident:
    result = await db.execute(
        select(Incident)
        .options(
            selectinload(Incident.fix_flows).selectinload(FixFlow.checklist_items),
            selectinload(Incident.timeline_events),
            selectinload(Incident.similar_incidents),
            selectinload(Incident.note),
        )
        .where(Incident.id == incident_id)
    )
    incident = result.scalar_one_or_none()
    if not incident:
        raise HTTPException(404, "Incident not found")
    if str(incident.user_id) != user_id:
        raise HTTPException(403, "Forbidden")
    return incident


# ── Patch ──────────────────────────────────────────────────────────────────────

async def patch_incident(incident_id: str, body: IncidentPatchRequest, user_id: str, db: AsyncSession):
    async with db.begin():
        incident = await _get_owned(incident_id, user_id, db)
        if body.selected_fix_flow_id:
            incident.selected_fix_flow_id = body.selected_fix_flow_id
            flow = await db.get(FixFlow, body.selected_fix_flow_id)
            if flow:
                db.add(TimelineEvent(incident_id=incident.id, event=f"Fix Flow attached: {flow.title}"))
        if body.status:
            incident.status = body.status
    return await get_incident_detail(incident_id, user_id, db)


async def resolve_incident(incident_id: str, user_id: str, db: AsyncSession):
    async with db.begin():
        incident = await _get_owned(incident_id, user_id, db)
        incident.status = "resolved"
        incident.resolved_at = datetime.now(timezone.utc)
        db.add(TimelineEvent(incident_id=incident.id, event="Incident resolved"))
    return {"id": incident.id, "status": "resolved", "resolved_at": incident.resolved_at}


# ── Checklist ──────────────────────────────────────────────────────────────────

async def toggle_checklist_item(item_id: str, is_completed: bool, user_id: str, db: AsyncSession):
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
                event=f"Step '{item.description}' completed"
            ))
    return {"id": item.id, "is_completed": item.is_completed, "updated_at": item.updated_at}


# ── Notes ──────────────────────────────────────────────────────────────────────

async def upsert_note(incident_id: str, content: str, user_id: str, db: AsyncSession):
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

async def mark_fix_flow_attempted(flow_id: str, is_attempted: bool, user_id: str, db: AsyncSession):
    async with db.begin():
        flow = await db.get(FixFlow, flow_id)
        if not flow:
            raise HTTPException(404, "Fix flow not found")
        await _get_owned(str(flow.incident_id), user_id, db)
        flow.is_attempted = is_attempted
    return {"id": flow.id, "is_attempted": flow.is_attempted}


# ── Archive ────────────────────────────────────────────────────────────────────

async def get_archive_incidents(user_id: str, db: AsyncSession):
    result = await db.execute(
        select(Incident)
        .where(Incident.user_id == user_id, Incident.status.in_(["resolved", "closed"]))
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
            "id": inc.id, "incident_code": inc.incident_code,
            "title": inc.title, "severity": inc.severity, "status": inc.status,
            "resolved_at": inc.resolved_at, "resolution_time_minutes": mins,
        })
    return {"data": data, "total": len(data)}


# ── Helpers ────────────────────────────────────────────────────────────────────

async def _get_owned(incident_id: str, user_id: str, db: AsyncSession) -> Incident:
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


async def _build_similar_context(components: list[str], user_id: str, db: AsyncSession):
    if not components:
        return "None available.", []
    result = await db.execute(
        select(Incident)
        .where(Incident.user_id == user_id, Incident.status.in_(["resolved", "closed"]))
        .order_by(Incident.created_at.desc())
        .limit(10)
    )
    candidates = result.scalars().all()
    matches = [(str(i.id), i.incident_code) for i in candidates
               if any(c in i.components for c in components)][:3]
    if not matches:
        return "None available.", []
    context = "\n".join(f"- {code}" for _, code in matches)
    return context, matches

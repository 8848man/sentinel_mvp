"""
Business logic for all incident operations.
Routers call these functions; never call gemini_service directly from routers.
"""
import asyncio
from datetime import datetime, timezone
from uuid import UUID
from fastapi import HTTPException
from sqlalchemy import select, extract, delete, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from app.core.config import settings
from app.core.database import AsyncSessionFactory
from app.models.models import (
    Incident, FixFlow, ChecklistItem, Note, TimelineEvent,
    SimilarIncident, IncidentSequence, AnalysisJob,
)
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


# ── Create Incident (fast path — no Gemini) ───────────────────────────────────

async def create_incident(
    body: IncidentCreateRequest, user_id: str, db: AsyncSession
) -> tuple[str, str]:
    """
    Creates incident + first analysis_jobs row in a single atomic transaction.
    Returns (incident_id, job_id). Caller fires execute_analysis as a background task.
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
        )
        db.add(incident)
        await db.flush()

        db.add(TimelineEvent(incident_id=incident.id, event="Alert triggered"))

        job = AnalysisJob(
            incident_id=incident.id,
            attempt_number=1,
            status="pending",
        )
        db.add(job)
        await db.flush()

        incident_id = str(incident.id)
        job_id = str(job.id)

    return incident_id, job_id


# ── Background Worker ──────────────────────────────────────────────────────────

async def execute_analysis(job_id: str) -> None:
    """
    Background worker — opens its own DB session.
    Idempotent: if job is not 'pending' on entry, aborts silently.
    All transitions write analysis_jobs and incidents.analysis_status in the same transaction.
    """
    async with AsyncSessionFactory() as db:

        # ── T1: Claim job (SELECT FOR UPDATE + set processing) ─────────────────
        job = None
        incident = None
        incident_id: str = ""
        user_id: str = ""
        log_text: str = ""
        title: str = ""
        severity: str = ""
        components: list[str] = []

        async with db.begin():
            result = await db.execute(
                select(AnalysisJob)
                .where(AnalysisJob.id == job_id)
                .with_for_update()
            )
            job = result.scalar_one_or_none()
            if not job or job.status != "pending":
                return  # duplicate execution guard

            result2 = await db.execute(
                select(Incident).where(Incident.id == job.incident_id)
            )
            incident = result2.scalar_one_or_none()
            if not incident:
                job.status = "failed"
                job.error_message = "Incident not found"
                return

            # Capture all data needed outside this transaction
            incident_id = str(incident.id)
            user_id = str(incident.user_id)
            log_text = incident.log_text
            title = incident.title
            severity = incident.severity
            components = list(incident.components)

            job.status = "processing"
            job.started_at = datetime.now(timezone.utc)
            incident.analysis_status = "processing"
        # T1 commits — job=processing, incident.analysis_status=processing in DB

        # ── Between T1 and T2: build context, truncate, call Gemini ───────────
        similar_ctx = "None available."
        similar_pairs: list[tuple[str, str]] = []
        ai: dict | None = None
        error_msg: str | None = None
        truncated_log = log_text
        char_count = len(log_text)

        try:
            async with db.begin():
                similar_ctx, similar_pairs = await _build_similar_context(
                    components, user_id, db
                )

            truncated_log, char_count = _truncate_log(log_text)

            ai = await gemini_service.analyze_incident(
                truncated_log,
                title,
                severity,
                components,
                similar_ctx,
                timeout=settings.ANALYSIS_TIMEOUT_SECONDS,
            )
        except Exception as exc:
            error_msg = str(exc) or type(exc).__name__

        # ── T2: Persist results ────────────────────────────────────────────────
        if error_msg is not None:
            async with db.begin():
                job.status = "failed"
                job.error_message = error_msg
                incident.analysis_status = "failed"
                incident.analysis_error = error_msg
                db.add(TimelineEvent(incident_id=incident_id, event="AI analysis failed"))
        else:
            async with db.begin():
                # Replace old AI results (re-analysis case)
                await db.execute(
                    delete(FixFlow).where(FixFlow.incident_id == incident_id)
                )
                await db.execute(
                    delete(SimilarIncident).where(
                        SimilarIncident.incident_id == incident_id
                    )
                )

                for i, flow_data in enumerate(ai.get("fix_flows", [])):
                    flow = FixFlow(
                        incident_id=incident_id,
                        title=flow_data["title"],
                        confidence=flow_data["confidence"],
                        sort_order=i,
                    )
                    db.add(flow)
                    await db.flush()
                    for j, step in enumerate(
                        flow_data.get("checklist_items", []), start=1
                    ):
                        db.add(
                            ChecklistItem(
                                fix_flow_id=flow.id,
                                step_number=j,
                                description=step,
                            )
                        )

                for sim_id, sim_code in similar_pairs[:3]:
                    score = next(
                        (
                            s["match_score"]
                            for s in ai.get("similar_incidents", [])
                            if s.get("incident_code") == sim_code
                        ),
                        0.80,
                    )
                    db.add(
                        SimilarIncident(
                            incident_id=incident_id,
                            similar_to_id=sim_id,
                            match_score=score,
                        )
                    )

                db.add(
                    TimelineEvent(
                        incident_id=incident_id, event="AI analysis completed"
                    )
                )

                incident.root_cause = ai.get("root_cause")
                incident.confidence = ai.get("confidence")
                incident.description = ai.get("impact_summary")
                incident.analysis_status = "completed"
                incident.analysis_error = None

                job.status = "completed"
                job.completed_at = datetime.now(timezone.utc)
                job.input_char_count = char_count


# ── Manual Re-analysis ─────────────────────────────────────────────────────────

async def trigger_reanalysis(
    incident_id: str, user_id: str, db: AsyncSession
) -> tuple[str, int]:
    """
    Creates a new analysis_jobs row and resets incident cache.
    Returns (job_id, attempt_number). Caller fires execute_analysis as a background task.
    Raises 409 if an active (non-orphaned) job exists.
    IntegrityError from the DB unique constraint (race condition) propagates to caller.
    """
    async with db.begin():
        incident = await _get_owned(incident_id, user_id, db)

        result = await db.execute(
            select(AnalysisJob).where(
                AnalysisJob.incident_id == incident_id,
                AnalysisJob.status.in_(["pending", "processing"]),
            )
        )
        active_job = result.scalar_one_or_none()

        if active_job:
            if active_job.status == "processing" and active_job.started_at:
                elapsed = (
                    datetime.now(timezone.utc) - active_job.started_at
                ).total_seconds()
                orphan_threshold = settings.ANALYSIS_TIMEOUT_SECONDS * 2
                if elapsed > orphan_threshold:
                    # Orphaned — mark failed so the partial index releases the slot
                    active_job.status = "failed"
                    active_job.error_message = (
                        f"Orphaned: no completion after {int(elapsed)}s"
                    )
                    incident.analysis_status = "failed"
                    incident.analysis_error = active_job.error_message
                else:
                    raise HTTPException(409, "Analysis already active")
            else:
                raise HTTPException(409, "Analysis already queued")

        result2 = await db.execute(
            select(func.max(AnalysisJob.attempt_number)).where(
                AnalysisJob.incident_id == incident_id
            )
        )
        max_attempt = result2.scalar() or 0

        new_job = AnalysisJob(
            incident_id=incident_id,
            attempt_number=max_attempt + 1,
            status="pending",
        )
        db.add(new_job)
        incident.analysis_status = "pending"
        incident.analysis_error = None
        await db.flush()

        job_id = str(new_job.id)
        attempt_number = int(new_job.attempt_number)

    return job_id, attempt_number


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
            selectinload(Incident.timeline),
            selectinload(Incident.similar_incidents).selectinload(SimilarIncident.similar_to),
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
            fix_flow_id = str(body.selected_fix_flow_id)  # UUID → str for SQLite binding
            incident.selected_fix_flow_id = fix_flow_id
            flow = await db.get(FixFlow, fix_flow_id)
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


async def close_incident(incident_id: str, user_id: str, db: AsyncSession):
    async with db.begin():
        incident = await _get_owned(incident_id, user_id, db)
        incident.status = "closed"
        db.add(TimelineEvent(incident_id=incident.id, event="Incident closed"))
    return {"id": incident.id, "status": "closed"}


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


def _truncate_log(log_text: str) -> tuple[str, int]:
    max_chars = settings.MAX_ANALYSIS_INPUT_CHARS
    if len(log_text) <= max_chars:
        return log_text, len(log_text)
    half = max_chars // 2
    omitted = len(log_text) - max_chars
    truncated = (
        log_text[:half]
        + f"\n\n[...{omitted} characters omitted for analysis...]\n\n"
        + log_text[-half:]
    )
    return truncated, len(truncated)


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

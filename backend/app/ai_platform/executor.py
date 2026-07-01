"""AI action background executor.

Owns all transaction boundaries, error handling, and timeline event writing.
Handlers contain only business logic (context, prompt, parse, persist).

Transaction structure:
  T1: Claim job — SELECT FOR UPDATE, set status=processing, write input_snapshot.
      All data needed between T1 and T2 is captured before T1 commits so no
      session is held open during the (slow) Gemini API call.
  T2: Persist results — handler.persist_results + timeline event + incident cache.
      Single atomic commit: either everything lands or nothing does.

Idempotency: if status != 'pending' on entry, the executor aborts silently.
This guards against duplicate background task firings.
"""
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import settings
from app.core.database import AsyncSessionFactory
from app.models.models import AIAction, FixFlow, Incident, TimelineEvent
from app.services import gemini_service


async def execute(action_id: str, registry: dict) -> None:
    """
    Background worker entry point. Opens its own DB session.
    registry: the live handler registry dict from ai_platform.registry.
    """
    async with AsyncSessionFactory() as db:
        await _run(action_id, registry, db)


async def _run(action_id: str, registry: dict, db: AsyncSession) -> None:
    handler = None
    incident_id = ""
    incident = None
    context = None

    # ── T1: Claim job ──────────────────────────────────────────────────────────
    async with db.begin():
        result = await db.execute(
            select(AIAction).where(AIAction.id == action_id).with_for_update()
        )
        action = result.scalar_one_or_none()
        if not action or action.status != "pending":
            return  # duplicate execution guard

        handler = registry.get(action.action_type)
        if not handler:
            action.status = "failed"
            action.error_message = f"Unknown action_type: {action.action_type!r}"
            return

        result2 = await db.execute(
            select(Incident)
            .options(
                selectinload(Incident.fix_flows).selectinload(FixFlow.checklist_items),
            )
            .where(Incident.id == action.incident_id)
        )
        incident = result2.scalar_one_or_none()
        if not incident:
            action.status = "failed"
            action.error_message = "Incident not found"
            return

        # Gather context inside T1 — this reads the DB but commits with the claim.
        # This ensures input_snapshot is written even if the model call fails.
        try:
            context = await handler.gather_context(incident, db)
        except Exception as exc:
            action.status = "failed"
            action.error_message = f"Context gathering failed: {exc}"
            incident.analysis_status = "failed"
            incident.analysis_error = action.error_message
            return

        action.status = "processing"
        action.started_at = datetime.now(timezone.utc)
        action.input_snapshot = handler.build_input_snapshot(context)
        action.output_schema_version = handler.output_schema_version
        action.model_id = settings.GEMINI_MODEL
        incident_id = str(incident.id)
        incident.analysis_status = "processing"
        incident.analysis_error = None
    # T1 commits — action=processing, incident.analysis_status=processing in DB

    # ── Between T1 and T2: build prompt and call model ────────────────────────
    output: dict | None = None
    error_msg: str | None = None

    try:
        prompt = handler.build_prompt(context)
        timeout = (
            handler.timeout_seconds
            if handler.timeout_seconds is not None
            else settings.ANALYSIS_TIMEOUT_SECONDS
        )
        response_text = await gemini_service.generate(prompt, timeout=timeout)
        output = handler.parse_output(response_text)
    except Exception as exc:
        error_msg = str(exc) or type(exc).__name__

    # ── T2: Persist results ────────────────────────────────────────────────────
    async with AsyncSessionFactory() as db2:
        async with db2.begin():
            result = await db2.execute(
                select(AIAction).where(AIAction.id == action_id).with_for_update()
            )
            action = result.scalar_one_or_none()
            if not action:
                return

            result2 = await db2.execute(
                select(Incident).where(Incident.id == incident_id)
            )
            incident = result2.scalar_one_or_none()
            if not incident:
                return

            if error_msg is not None:
                action.status = "failed"
                action.error_message = error_msg
                incident.analysis_status = "failed"
                incident.analysis_error = error_msg
                db2.add(TimelineEvent(
                    incident_id=incident_id,
                    actor_type="ai",
                    event_type="ai_action_failed",
                    event=f"AI {handler.display_name.lower()} failed",
                    ai_action_id=action.id,
                    event_metadata={"action_type": action.action_type, "error": error_msg[:200]},
                ))
            else:
                # Let the handler persist its domain outputs (FixFlow rows, etc.)
                await handler.persist_results(action, incident, output, db2)

                action.status = "completed"
                action.completed_at = datetime.now(timezone.utc)
                action.output = output
                incident.analysis_status = "completed"
                incident.analysis_error = None

                db2.add(TimelineEvent(
                    incident_id=incident_id,
                    actor_type="ai",
                    event_type="ai_action_completed",
                    event=handler.timeline_event_text(output),
                    ai_action_id=action.id,
                    event_metadata={"action_type": action.action_type},
                ))

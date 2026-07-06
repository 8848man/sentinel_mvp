"""AI Action Service — orchestrates AIAction lifecycle.

The router calls request_action() to validate, create, and return the action ID.
The router then fires execute() as a BackgroundTask.
incident_service calls create_system_action() for lifecycle-triggered actions.

This service does NOT own transaction boundaries for execution — that is the
executor's responsibility. It owns only the creation transaction.
"""
from datetime import datetime, timezone

from fastapi import HTTPException
from sqlalchemy import select, func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.ai_platform import registry as _registry_module
from app.ai_platform.executor import execute as _execute
from app.core.database import AsyncSessionFactory
from app.models.models import AIAction, FixFlow, Incident, TimelineEvent


async def request_action(
    incident_id: str,
    action_type: str,
    user_id: str,
    db: AsyncSession,
) -> tuple[str, int]:
    """
    Validates preconditions, creates an AIAction row, returns (action_id, attempt_number).
    Does NOT fire the background task — the router adds it via BackgroundTasks.

    Raises:
        404: incident not found
        403: not owned by user
        409: active action already exists (or DB unique index fires)
        422: action_type unknown or handler preconditions unmet
    """
    handler = _registry_module.get_handler(action_type)
    if not handler:
        raise HTTPException(422, f"Unknown action type: {action_type!r}")

    async with db.begin():
        # Load fix_flows eagerly — required by handler.validate() and is_primary_for()
        # for ImprovedFixFlowHandler; harmless overhead for other handlers.
        result0 = await db.execute(
            select(Incident)
            .options(selectinload(Incident.fix_flows))
            .where(Incident.id == incident_id)
        )
        incident = result0.scalar_one_or_none()
        if not incident:
            raise HTTPException(404, "Incident not found")
        if str(incident.user_id) != user_id:
            raise HTTPException(403, "Forbidden")

        # Check for active action (fast-path; DB index is the enforcement).
        result = await db.execute(
            select(AIAction).where(
                AIAction.incident_id == incident_id,
                AIAction.status.in_(["pending", "processing"]),
            )
        )
        active = result.scalar_one_or_none()
        if active:
            _check_orphan_or_raise(active)

        # Handler precondition check.
        handler.validate(incident)

        attempt_number = await _next_attempt(incident_id, action_type, db)

        action = AIAction(
            incident_id=incident_id,
            action_type=action_type,
            requested_by="operator",
            attempt_number=attempt_number,
            status="pending",
        )
        db.add(action)
        db.add(TimelineEvent(
            incident_id=incident_id,
            actor_type="ai",
            event_type="ai_action_queued",
            event=f"AI {handler.display_name.lower()} queued",
            ai_action_id=action.id,
            event_metadata={"action_type": action_type},
        ))
        incident.analysis_status = "pending"
        incident.analysis_error = None
        await db.flush()

        return str(action.id), attempt_number


async def create_system_action(
    incident_id: str,
    action_type: str,
) -> str:
    """
    Creates an AIAction with requested_by='system'. Used by lifecycle hooks.
    Returns action_id. Does NOT fire the background task — caller does that.
    Opens its own session (called from incident_service after its session commits).
    """
    handler = _registry_module.get_handler(action_type)
    if not handler:
        return ""  # unknown handler — skip silently

    async with AsyncSessionFactory() as db:
        async with db.begin():
            result = await db.execute(
                select(AIAction).where(
                    AIAction.incident_id == incident_id,
                    AIAction.status.in_(["pending", "processing"]),
                )
            )
            if result.scalar_one_or_none():
                return ""  # active action exists — skip

            attempt_number = await _next_attempt(incident_id, action_type, db)
            action = AIAction(
                incident_id=incident_id,
                action_type=action_type,
                requested_by="system",
                attempt_number=attempt_number,
                status="pending",
            )
            db.add(action)
            db.add(TimelineEvent(
                incident_id=incident_id,
                actor_type="ai",
                event_type="ai_action_queued",
                event=f"AI {handler.display_name.lower()} queued",
                ai_action_id=action.id,
                event_metadata={"action_type": action_type},
            ))
            await db.flush()
            return str(action.id)


async def run_background(action_id: str) -> None:
    """Entry point for BackgroundTasks. Delegates to executor."""
    await _execute(action_id, _registry_module.REGISTRY)


# ── Helpers ───────────────────────────────────────────────────────────────────

async def _get_owned(incident_id: str, user_id: str, db: AsyncSession) -> Incident:
    incident = await db.get(Incident, incident_id)
    if not incident:
        raise HTTPException(404, "Incident not found")
    if str(incident.user_id) != user_id:
        raise HTTPException(403, "Forbidden")
    return incident


def _check_orphan_or_raise(active: AIAction) -> None:
    """Raise 409 unless the active job is orphaned (processing too long)."""
    from app.core.config import settings
    if active.status == "processing" and active.started_at:
        elapsed = (datetime.now(timezone.utc) - active.started_at).total_seconds()
        if elapsed > settings.ANALYSIS_TIMEOUT_SECONDS * 2:
            # Mark orphaned inline — the caller's transaction will commit this.
            active.status = "failed"
            active.error_message = f"Orphaned: no completion after {int(elapsed)}s"
            return
    raise HTTPException(409, "An AI action is already active for this incident")


async def _next_attempt(
    incident_id: str, action_type: str, db: AsyncSession
) -> int:
    result = await db.execute(
        select(func.max(AIAction.attempt_number)).where(
            AIAction.incident_id == incident_id,
            AIAction.action_type == action_type,
        )
    )
    return (result.scalar() or 0) + 1

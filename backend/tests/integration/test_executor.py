"""Integration tests for the AI Platform executor.

Calls executor.execute() directly with the test database and mocked Gemini.
Tests the T1/T2 transaction pattern, success paths, failure paths, and known bugs.
"""
import json
import pytest
from datetime import datetime, timezone
from sqlalchemy import select
from unittest.mock import AsyncMock, patch

from app.ai_platform import registry as _registry_module
from app.ai_platform.executor import execute
from app.core.database import AsyncSessionFactory
from app.models.models import AIAction, ChecklistItem, FixFlow, Incident, TimelineEvent
from tests.conftest import TEST_USER_ID, RCA_OUTPUT, IFF_OUTPUT


async def _create_rca_row(db, incident_id: str, status="pending") -> str:
    """Insert an AIAction row with the given status, return action_id."""
    action = AIAction(
        incident_id=incident_id,
        action_type="root_cause_analysis",
        requested_by="system",
        attempt_number=1,
        status=status,
    )
    db.add(action)
    await db.flush()
    action_id = str(action.id)
    await db.commit()
    return action_id


async def _create_test_incident(db) -> str:
    """Insert a minimal incident row, return incident_id."""
    from app.models.models import IncidentSequence

    # Ensure a sequence row exists.
    seq = await db.get(IncidentSequence, 2026)
    if not seq:
        db.add(IncidentSequence(year=2026, next_seq=1))
        await db.flush()

    inc = Incident(
        user_id=TEST_USER_ID,
        incident_code="INC-2026-001",
        title="DB Connection Pool Exhausted",
        log_text="ERROR: FATAL: remaining connection slots reserved",
        severity="critical",
        components=["PostgreSQL"],
        analysis_status="pending",
        origin_type="manual_text",
    )
    db.add(inc)
    await db.flush()
    incident_id = str(inc.id)
    await db.commit()
    return incident_id


# ── RCA happy path ─────────────────────────────────────────────────────────────


async def test_rca_completes_action(db, mock_gemini_rca):
    incident_id = await _create_test_incident(db)
    action_id = await _create_rca_row(db, incident_id)

    await execute(action_id, _registry_module.REGISTRY)

    async with AsyncSessionFactory() as s:
        result = await s.execute(select(AIAction).where(AIAction.id == action_id))
        action = result.scalar_one()
    assert action.status == "completed"


async def test_rca_updates_incident_analysis_status(db, mock_gemini_rca):
    incident_id = await _create_test_incident(db)
    action_id = await _create_rca_row(db, incident_id)

    await execute(action_id, _registry_module.REGISTRY)

    async with AsyncSessionFactory() as s:
        inc = await s.get(Incident, incident_id)
    assert inc.analysis_status == "completed"


async def test_rca_creates_fix_flow_rows(db, mock_gemini_rca):
    incident_id = await _create_test_incident(db)
    action_id = await _create_rca_row(db, incident_id)

    await execute(action_id, _registry_module.REGISTRY)

    async with AsyncSessionFactory() as s:
        result = await s.execute(
            select(FixFlow).where(FixFlow.incident_id == incident_id)
        )
        flows = result.scalars().all()
    assert len(flows) == len(RCA_OUTPUT["fix_flows"])


async def test_rca_creates_checklist_items(db, mock_gemini_rca):
    incident_id = await _create_test_incident(db)
    action_id = await _create_rca_row(db, incident_id)

    await execute(action_id, _registry_module.REGISTRY)

    async with AsyncSessionFactory() as s:
        result = await s.execute(
            select(ChecklistItem)
            .join(FixFlow, ChecklistItem.fix_flow_id == FixFlow.id)
            .where(FixFlow.incident_id == incident_id)
        )
        items = result.scalars().all()
    total_expected = sum(
        len(f["checklist_items"]) for f in RCA_OUTPUT["fix_flows"]
    )
    assert len(items) == total_expected


async def test_rca_updates_incident_root_cause(db, mock_gemini_rca):
    incident_id = await _create_test_incident(db)
    action_id = await _create_rca_row(db, incident_id)

    await execute(action_id, _registry_module.REGISTRY)

    async with AsyncSessionFactory() as s:
        inc = await s.get(Incident, incident_id)
    assert inc.root_cause == RCA_OUTPUT["root_cause"]


async def test_rca_writes_completed_timeline_event(db, mock_gemini_rca):
    incident_id = await _create_test_incident(db)
    action_id = await _create_rca_row(db, incident_id)

    await execute(action_id, _registry_module.REGISTRY)

    async with AsyncSessionFactory() as s:
        result = await s.execute(
            select(TimelineEvent).where(
                TimelineEvent.incident_id == incident_id,
                TimelineEvent.event_type == "ai_action_completed",
            )
        )
        event = result.scalar_one_or_none()
    assert event is not None


async def test_rca_records_input_snapshot(db, mock_gemini_rca):
    incident_id = await _create_test_incident(db)
    action_id = await _create_rca_row(db, incident_id)

    await execute(action_id, _registry_module.REGISTRY)

    async with AsyncSessionFactory() as s:
        result = await s.execute(select(AIAction).where(AIAction.id == action_id))
        action = result.scalar_one()
    assert action.input_snapshot is not None
    assert action.input_snapshot["action_type"] == "root_cause_analysis"


async def test_rca_fix_flows_have_generation_1(db, mock_gemini_rca):
    incident_id = await _create_test_incident(db)
    action_id = await _create_rca_row(db, incident_id)

    await execute(action_id, _registry_module.REGISTRY)

    async with AsyncSessionFactory() as s:
        result = await s.execute(
            select(FixFlow).where(FixFlow.incident_id == incident_id)
        )
        flows = result.scalars().all()
    assert all(f.generation == 1 for f in flows)


# ── Failure path ───────────────────────────────────────────────────────────────


async def test_gemini_failure_marks_action_failed(db):
    incident_id = await _create_test_incident(db)
    action_id = await _create_rca_row(db, incident_id)

    with patch(
        "app.services.gemini_service.generate",
        new=AsyncMock(side_effect=RuntimeError("Gemini API timeout after 5s")),
    ):
        await execute(action_id, _registry_module.REGISTRY)

    async with AsyncSessionFactory() as s:
        result = await s.execute(select(AIAction).where(AIAction.id == action_id))
        action = result.scalar_one()
    assert action.status == "failed"
    assert "timeout" in action.error_message.lower()


async def test_gemini_failure_updates_incident_status(db):
    incident_id = await _create_test_incident(db)
    action_id = await _create_rca_row(db, incident_id)

    with patch(
        "app.services.gemini_service.generate",
        new=AsyncMock(side_effect=RuntimeError("Gemini API timeout after 5s")),
    ):
        await execute(action_id, _registry_module.REGISTRY)

    async with AsyncSessionFactory() as s:
        inc = await s.get(Incident, incident_id)
    assert inc.analysis_status == "failed"


async def test_gemini_failure_writes_failed_timeline_event(db):
    incident_id = await _create_test_incident(db)
    action_id = await _create_rca_row(db, incident_id)

    with patch(
        "app.services.gemini_service.generate",
        new=AsyncMock(side_effect=RuntimeError("Gemini API timeout after 5s")),
    ):
        await execute(action_id, _registry_module.REGISTRY)

    async with AsyncSessionFactory() as s:
        result = await s.execute(
            select(TimelineEvent).where(
                TimelineEvent.incident_id == incident_id,
                TimelineEvent.event_type == "ai_action_failed",
            )
        )
        event = result.scalar_one_or_none()
    assert event is not None


async def test_gemini_failure_sets_analysis_error_on_incident(db):
    incident_id = await _create_test_incident(db)
    action_id = await _create_rca_row(db, incident_id)

    with patch(
        "app.services.gemini_service.generate",
        new=AsyncMock(side_effect=RuntimeError("Connection refused")),
    ):
        await execute(action_id, _registry_module.REGISTRY)

    async with AsyncSessionFactory() as s:
        inc = await s.get(Incident, incident_id)
    assert inc.analysis_error is not None


# ── Idempotency / duplicate guard ─────────────────────────────────────────────


async def test_duplicate_execute_is_noop(db, mock_gemini_rca):
    """Second execute() on same action_id is silently ignored."""
    incident_id = await _create_test_incident(db)
    action_id = await _create_rca_row(db, incident_id)

    await execute(action_id, _registry_module.REGISTRY)
    # Second call: action is now 'completed', not 'pending' — should be a no-op.
    await execute(action_id, _registry_module.REGISTRY)

    # Gemini should have been called exactly once.
    assert mock_gemini_rca.call_count == 1


# ── Unknown action_type (F4 bug) ───────────────────────────────────────────────


async def test_unknown_action_type_marks_action_failed(db):
    """Executor marks action failed when action_type is not in registry."""
    incident_id = await _create_test_incident(db)

    # Create an action with an unknown action_type directly.
    action = AIAction(
        incident_id=incident_id,
        action_type="nonexistent_handler",
        requested_by="system",
        attempt_number=1,
        status="pending",
    )
    async with AsyncSessionFactory() as s:
        async with s.begin():
            s.add(action)
            await s.flush()
            action_id = str(action.id)

    registry_without_handler = {}
    await execute(action_id, registry_without_handler)

    async with AsyncSessionFactory() as s:
        result = await s.execute(select(AIAction).where(AIAction.id == action_id))
        fetched = result.scalar_one()
    assert fetched.status == "failed"
    assert "Unknown action_type" in fetched.error_message


async def test_unknown_action_type_does_not_update_incident_status(db):
    """Documents F4 bug: incident.analysis_status NOT updated on unknown handler."""
    incident_id = await _create_test_incident(db)

    # Set incident to processing to make the bug visible.
    async with AsyncSessionFactory() as s:
        async with s.begin():
            inc = await s.get(Incident, incident_id)
            inc.analysis_status = "processing"

    action = AIAction(
        incident_id=incident_id,
        action_type="nonexistent_handler",
        requested_by="system",
        attempt_number=1,
        status="pending",
    )
    async with AsyncSessionFactory() as s:
        async with s.begin():
            s.add(action)
            await s.flush()
            action_id = str(action.id)

    registry_without_handler = {}
    await execute(action_id, registry_without_handler)

    async with AsyncSessionFactory() as s:
        inc = await s.get(Incident, incident_id)
    # BUG F4: incident.analysis_status is NOT updated — it stays "processing".
    # This test documents the existing behaviour. Fix this if F4 is resolved.
    assert inc.analysis_status == "processing"


# ── RCA re-run: generation cleanup ───────────────────────────────────────────


async def test_rca_rerun_deletes_gen1_fix_flows(db, mock_gemini_rca):
    """On RCA re-run, old gen=1 fix flows are replaced."""
    incident_id = await _create_test_incident(db)
    action_id = await _create_rca_row(db, incident_id)
    await execute(action_id, _registry_module.REGISTRY)

    # Verify gen=1 flows exist.
    async with AsyncSessionFactory() as s:
        result = await s.execute(
            select(FixFlow).where(FixFlow.incident_id == incident_id, FixFlow.generation == 1)
        )
        first_flows = result.scalars().all()
    assert len(first_flows) == len(RCA_OUTPUT["fix_flows"])

    # Second RCA run (retry scenario).
    action2 = AIAction(
        incident_id=incident_id,
        action_type="root_cause_analysis",
        requested_by="operator",
        attempt_number=2,
        status="pending",
    )
    async with AsyncSessionFactory() as s:
        async with s.begin():
            s.add(action2)
            await s.flush()
            action2_id = str(action2.id)

    await execute(action2_id, _registry_module.REGISTRY)

    async with AsyncSessionFactory() as s:
        result = await s.execute(
            select(FixFlow).where(FixFlow.incident_id == incident_id, FixFlow.generation == 1)
        )
        second_flows = result.scalars().all()
    # Should have same count (old gen=1 deleted, new gen=1 written).
    assert len(second_flows) == len(RCA_OUTPUT["fix_flows"])


# ── IFF happy path ─────────────────────────────────────────────────────────────


async def test_iff_creates_new_generation(db, mock_gemini_rca, mock_gemini_iff):
    """IFF writes fix flows at generation = max(existing) + 1."""
    incident_id = await _create_test_incident(db)

    # Run RCA first to get gen=1 flows and set up incident state.
    action1 = AIAction(
        incident_id=incident_id,
        action_type="root_cause_analysis",
        requested_by="system",
        attempt_number=1,
        status="pending",
    )
    async with AsyncSessionFactory() as s:
        async with s.begin():
            s.add(action1)
            await s.flush()
            a1_id = str(action1.id)

    await execute(a1_id, _registry_module.REGISTRY)

    # Set incident to in_progress and mark all gen=1 flows as attempted.
    async with AsyncSessionFactory() as s:
        async with s.begin():
            inc = await s.get(Incident, incident_id)
            inc.status = "in_progress"
            inc.analysis_status = "completed"
            result = await s.execute(
                select(FixFlow).where(FixFlow.incident_id == incident_id)
            )
            for flow in result.scalars().all():
                flow.is_attempted = True

    # Run IFF.
    action2 = AIAction(
        incident_id=incident_id,
        action_type="improved_fix_flow",
        requested_by="operator",
        attempt_number=1,
        status="pending",
    )
    async with AsyncSessionFactory() as s:
        async with s.begin():
            s.add(action2)
            await s.flush()
            a2_id = str(action2.id)

    with patch(
        "app.services.gemini_service.generate",
        new=AsyncMock(return_value=json.dumps(IFF_OUTPUT)),
    ):
        await execute(a2_id, _registry_module.REGISTRY)

    async with AsyncSessionFactory() as s:
        result = await s.execute(
            select(FixFlow)
            .where(FixFlow.incident_id == incident_id)
            .order_by(FixFlow.generation)
        )
        all_flows = result.scalars().all()

    generations = {f.generation for f in all_flows}
    assert 1 in generations  # gen=1 preserved (RCA)
    assert 2 in generations  # gen=2 written (IFF)


async def test_iff_preserves_gen1_flows(db, mock_gemini_rca):
    """IFF does NOT delete gen=1 fix flows written by RCA."""
    incident_id = await _create_test_incident(db)
    action1 = AIAction(
        incident_id=incident_id,
        action_type="root_cause_analysis",
        requested_by="system",
        attempt_number=1,
        status="pending",
    )
    async with AsyncSessionFactory() as s:
        async with s.begin():
            s.add(action1)
            await s.flush()
            a1_id = str(action1.id)
    await execute(a1_id, _registry_module.REGISTRY)

    async with AsyncSessionFactory() as s:
        async with s.begin():
            inc = await s.get(Incident, incident_id)
            inc.status = "in_progress"
            inc.analysis_status = "completed"
            result = await s.execute(
                select(FixFlow).where(FixFlow.incident_id == incident_id)
            )
            for flow in result.scalars().all():
                flow.is_attempted = True

    action2 = AIAction(
        incident_id=incident_id,
        action_type="improved_fix_flow",
        requested_by="operator",
        attempt_number=1,
        status="pending",
    )
    async with AsyncSessionFactory() as s:
        async with s.begin():
            s.add(action2)
            await s.flush()
            a2_id = str(action2.id)

    with patch(
        "app.services.gemini_service.generate",
        new=AsyncMock(return_value=json.dumps(IFF_OUTPUT)),
    ):
        await execute(a2_id, _registry_module.REGISTRY)

    async with AsyncSessionFactory() as s:
        result = await s.execute(
            select(FixFlow).where(
                FixFlow.incident_id == incident_id,
                FixFlow.generation == 1,
            )
        )
        gen1_flows = result.scalars().all()

    assert len(gen1_flows) == len(RCA_OUTPUT["fix_flows"])


# ── SimilarIncident known gap (F3) ───────────────────────────────────────────


async def test_similar_incidents_never_written(db, mock_gemini_rca):
    """Documents F3 bug: SimilarIncident rows are never written by RCA persist_results."""
    from app.models.models import SimilarIncident

    incident_id = await _create_test_incident(db)
    action_id = await _create_rca_row(db, incident_id)

    await execute(action_id, _registry_module.REGISTRY)

    async with AsyncSessionFactory() as s:
        result = await s.execute(
            select(SimilarIncident).where(SimilarIncident.incident_id == incident_id)
        )
        similar = result.scalars().all()
    # BUG F3: similar_incidents always empty despite RCA completing.
    assert len(similar) == 0

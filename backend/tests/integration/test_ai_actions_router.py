"""Integration tests for the AI action trigger endpoints.

Covers POST /incidents/{id}/ai-actions (unified endpoint),
POST /incidents/{id}/analyze (deprecated backward-compat),
and precondition enforcement.
"""
import pytest
from sqlalchemy import select

from app.models.models import AIAction, Incident, TimelineEvent
from tests.conftest import TEST_USER_ID_2, SAMPLE_INCIDENT


async def _create_incident(client, mock_run_background, extra=None):
    body = {**SAMPLE_INCIDENT, **(extra or {})}
    resp = await client.post("/incidents", json=body)
    assert resp.status_code == 201
    return resp.json()["id"]


# ── POST /incidents/{id}/ai-actions ──────────────────────────────────────────


async def test_trigger_ai_action_returns_202(client, db, mock_run_background):
    # First complete the existing pending action so we can create a new one.
    incident_id = await _create_incident(client, mock_run_background)

    # Mark the pending action as failed so it's no longer active.
    result = await db.execute(
        select(AIAction).where(AIAction.incident_id == incident_id)
    )
    action = result.scalar_one()
    action.status = "failed"
    await db.commit()

    resp = await client.post(
        f"/incidents/{incident_id}/ai-actions",
        json={"action_type": "root_cause_analysis"},
    )
    assert resp.status_code == 202


async def test_trigger_ai_action_response_fields(client, db, mock_run_background):
    incident_id = await _create_incident(client, mock_run_background)

    result = await db.execute(select(AIAction).where(AIAction.incident_id == incident_id))
    action = result.scalar_one()
    action.status = "failed"
    await db.commit()

    resp = await client.post(
        f"/incidents/{incident_id}/ai-actions",
        json={"action_type": "root_cause_analysis"},
    )
    body = resp.json()
    assert body["incident_id"] == incident_id
    assert body["action_type"] == "root_cause_analysis"
    assert body["status"] == "pending"
    assert "action_id" in body
    assert "attempt_number" in body


async def test_trigger_ai_action_creates_db_row(client, db, mock_run_background):
    incident_id = await _create_incident(client, mock_run_background)

    result = await db.execute(select(AIAction).where(AIAction.incident_id == incident_id))
    action = result.scalar_one()
    action.status = "failed"
    await db.commit()

    await client.post(
        f"/incidents/{incident_id}/ai-actions",
        json={"action_type": "root_cause_analysis"},
    )

    result2 = await db.execute(
        select(AIAction).where(
            AIAction.incident_id == incident_id,
            AIAction.status == "pending",
        )
    )
    assert result2.scalar_one_or_none() is not None


async def test_trigger_ai_action_increments_attempt_number(client, db, mock_run_background):
    incident_id = await _create_incident(client, mock_run_background)

    # Fail the first attempt.
    result = await db.execute(select(AIAction).where(AIAction.incident_id == incident_id))
    first = result.scalar_one()
    assert first.attempt_number == 1
    first.status = "failed"
    await db.commit()

    resp = await client.post(
        f"/incidents/{incident_id}/ai-actions",
        json={"action_type": "root_cause_analysis"},
    )
    assert resp.json()["attempt_number"] == 2


async def test_trigger_ai_action_queues_timeline_event(client, db, mock_run_background):
    incident_id = await _create_incident(client, mock_run_background)

    result = await db.execute(select(AIAction).where(AIAction.incident_id == incident_id))
    action = result.scalar_one()
    action.status = "failed"
    await db.commit()

    await client.post(
        f"/incidents/{incident_id}/ai-actions",
        json={"action_type": "root_cause_analysis"},
    )

    result2 = await db.execute(
        select(TimelineEvent).where(
            TimelineEvent.incident_id == incident_id,
            TimelineEvent.event_type == "ai_action_queued",
        )
    )
    # Two ai_action_queued events: one from create_incident, one from request_action.
    events = result2.scalars().all()
    assert len(events) == 2


async def test_trigger_ai_action_409_when_active(client, mock_run_background):
    """Returns 409 when a pending action already exists."""
    incident_id = await _create_incident(client, mock_run_background)

    resp = await client.post(
        f"/incidents/{incident_id}/ai-actions",
        json={"action_type": "root_cause_analysis"},
    )
    assert resp.status_code == 409


async def test_trigger_ai_action_422_unknown_type(client, mock_run_background):
    incident_id = await _create_incident(client, mock_run_background)
    resp = await client.post(
        f"/incidents/{incident_id}/ai-actions",
        json={"action_type": "nonexistent_action"},
    )
    assert resp.status_code == 422


async def test_trigger_ai_action_422_iff_when_preconditions_unmet(client, db, mock_run_background):
    """IFF requires in_progress status + all fix flows attempted."""
    incident_id = await _create_incident(client, mock_run_background)

    # Fail the pending RCA action first (so no active action).
    result = await db.execute(select(AIAction).where(AIAction.incident_id == incident_id))
    action = result.scalar_one()
    action.status = "failed"
    await db.commit()

    # IFF on an "open" incident should fail precondition check.
    resp = await client.post(
        f"/incidents/{incident_id}/ai-actions",
        json={"action_type": "improved_fix_flow"},
    )
    assert resp.status_code == 422


async def test_trigger_ai_action_404_unknown_incident(client):
    resp = await client.post(
        "/incidents/nonexistent-id/ai-actions",
        json={"action_type": "root_cause_analysis"},
    )
    assert resp.status_code == 404


async def test_trigger_ai_action_403_other_user(app, mock_run_background):
    from app.core.auth import get_current_user

    async with __import__("httpx").AsyncClient(
        transport=__import__("httpx").ASGITransport(app=app),
        base_url="http://test/api/v1",
    ) as c:
        create = await c.post("/incidents", json=SAMPLE_INCIDENT)
    incident_id = create.json()["id"]

    async def _user_b():
        return {"user_id": TEST_USER_ID_2, "email": "b@test.com"}

    app.dependency_overrides[get_current_user] = _user_b
    async with __import__("httpx").AsyncClient(
        transport=__import__("httpx").ASGITransport(app=app),
        base_url="http://test/api/v1",
    ) as c_b:
        resp = await c_b.post(
            f"/incidents/{incident_id}/ai-actions",
            json={"action_type": "root_cause_analysis"},
        )

    from tests.conftest import TEST_USER_ID
    async def _user_a():
        return {"user_id": TEST_USER_ID, "email": "a@test.com"}
    app.dependency_overrides[get_current_user] = _user_a

    assert resp.status_code == 403


# ── POST /incidents/{id}/analyze (deprecated) ────────────────────────────────


async def test_legacy_analyze_returns_202(client, db, mock_run_background):
    incident_id = await _create_incident(client, mock_run_background)

    result = await db.execute(select(AIAction).where(AIAction.incident_id == incident_id))
    action = result.scalar_one()
    action.status = "failed"
    await db.commit()

    resp = await client.post(f"/incidents/{incident_id}/analyze")
    assert resp.status_code == 202


async def test_legacy_analyze_response_has_job_id(client, db, mock_run_background):
    incident_id = await _create_incident(client, mock_run_background)

    result = await db.execute(select(AIAction).where(AIAction.incident_id == incident_id))
    action = result.scalar_one()
    action.status = "failed"
    await db.commit()

    resp = await client.post(f"/incidents/{incident_id}/analyze")
    body = resp.json()
    assert "job_id" in body
    assert body["analysis_status"] == "pending"

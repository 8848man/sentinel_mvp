"""Integration tests for incident CRUD endpoints.

Background tasks (run_background) are mocked so the executor does not run.
This isolates router behavior from the AI Platform execution path.
"""
import pytest
from sqlalchemy import select

from app.models.models import AIAction, Incident, TimelineEvent
from tests.conftest import TEST_USER_ID, TEST_USER_ID_2, SAMPLE_INCIDENT


# ── POST /incidents ────────────────────────────────────────────────────────────


async def test_create_incident_returns_201(client, mock_run_background):
    resp = await client.post("/incidents", json=SAMPLE_INCIDENT)
    assert resp.status_code == 201


async def test_create_incident_analysis_status_pending(client, mock_run_background):
    resp = await client.post("/incidents", json=SAMPLE_INCIDENT)
    assert resp.json()["analysis_status"] == "pending"


async def test_create_incident_default_origin_type(client, mock_run_background):
    resp = await client.post("/incidents", json=SAMPLE_INCIDENT)
    assert resp.json()["origin_type"] == "manual_text"


async def test_create_incident_custom_origin_type(client, mock_run_background):
    body = {**SAMPLE_INCIDENT, "origin_type": "ocr_image"}
    resp = await client.post("/incidents", json=body)
    assert resp.json()["origin_type"] == "ocr_image"


async def test_create_incident_primary_action_null_while_pending(client, mock_run_background):
    resp = await client.post("/incidents", json=SAMPLE_INCIDENT)
    assert resp.json()["primary_action"] is None


async def test_create_incident_missing_title_422(client, mock_run_background):
    body = {k: v for k, v in SAMPLE_INCIDENT.items() if k != "title"}
    resp = await client.post("/incidents", json=body)
    assert resp.status_code == 422


async def test_create_incident_short_log_422(client, mock_run_background):
    body = {**SAMPLE_INCIDENT, "log_text": "short"}
    resp = await client.post("/incidents", json=body)
    assert resp.status_code == 422


async def test_create_incident_creates_ai_action_in_db(client, db, mock_run_background):
    resp = await client.post("/incidents", json=SAMPLE_INCIDENT)
    incident_id = resp.json()["id"]

    result = await db.execute(
        select(AIAction).where(AIAction.incident_id == incident_id)
    )
    action = result.scalar_one_or_none()
    assert action is not None
    assert action.status == "pending"
    assert action.action_type == "root_cause_analysis"


async def test_create_incident_timeline_has_two_events(client, db, mock_run_background):
    resp = await client.post("/incidents", json=SAMPLE_INCIDENT)
    incident_id = resp.json()["id"]

    result = await db.execute(
        select(TimelineEvent).where(TimelineEvent.incident_id == incident_id)
    )
    events = result.scalars().all()
    event_types = {e.event_type for e in events}
    assert "incident_created" in event_types
    assert "ai_action_queued" in event_types


async def test_create_incident_incident_code_format(client, mock_run_background):
    resp = await client.post("/incidents", json=SAMPLE_INCIDENT)
    code = resp.json()["incident_code"]
    assert code.startswith("INC-")


async def test_create_incident_fires_background_task(client, mock_run_background):
    resp = await client.post("/incidents", json=SAMPLE_INCIDENT)
    assert resp.status_code == 201
    mock_run_background.assert_called_once()


# ── GET /incidents ─────────────────────────────────────────────────────────────


async def test_list_incidents_returns_200(client, mock_run_background):
    await client.post("/incidents", json=SAMPLE_INCIDENT)
    resp = await client.get("/incidents")
    assert resp.status_code == 200


async def test_list_incidents_returns_created_incident(client, mock_run_background):
    await client.post("/incidents", json=SAMPLE_INCIDENT)
    resp = await client.get("/incidents")
    data = resp.json()
    assert data["total"] == 1
    assert len(data["data"]) == 1


async def test_list_incidents_excludes_closed(client, db, mock_run_background):
    create_resp = await client.post("/incidents", json=SAMPLE_INCIDENT)
    incident_id = create_resp.json()["id"]

    # Close the incident directly in DB.
    result = await db.execute(select(Incident).where(Incident.id == incident_id))
    inc = result.scalar_one()
    inc.status = "closed"
    await db.commit()

    resp = await client.get("/incidents")
    assert resp.json()["total"] == 0


async def test_list_incidents_user_isolation(app, mock_run_background):
    """User A's incidents are not visible to User B."""
    from app.core.auth import get_current_user

    # Create incident as User A (default test client).
    async with __import__("httpx").AsyncClient(
        transport=__import__("httpx").ASGITransport(app=app),
        base_url="http://test/api/v1",
    ) as c_a:
        await c_a.post("/incidents", json=SAMPLE_INCIDENT)

    # Temporarily override to User B.
    async def _user_b():
        return {"user_id": TEST_USER_ID_2, "email": "other@test.com"}

    app.dependency_overrides[get_current_user] = _user_b
    async with __import__("httpx").AsyncClient(
        transport=__import__("httpx").ASGITransport(app=app),
        base_url="http://test/api/v1",
    ) as c_b:
        resp = await c_b.get("/incidents")
    # Restore
    from tests.conftest import TEST_USER_ID as UID
    async def _user_a():
        return {"user_id": UID, "email": "test@test.com"}
    app.dependency_overrides[get_current_user] = _user_a

    assert resp.json()["total"] == 0


# ── GET /incidents/{id} ────────────────────────────────────────────────────────


async def test_get_incident_returns_200(client, mock_run_background):
    create = await client.post("/incidents", json=SAMPLE_INCIDENT)
    incident_id = create.json()["id"]
    resp = await client.get(f"/incidents/{incident_id}")
    assert resp.status_code == 200


async def test_get_incident_has_required_fields(client, mock_run_background):
    create = await client.post("/incidents", json=SAMPLE_INCIDENT)
    incident_id = create.json()["id"]
    resp = await client.get(f"/incidents/{incident_id}")
    body = resp.json()
    for field in ("id", "incident_code", "title", "severity", "status", "analysis_status"):
        assert field in body


async def test_get_incident_other_user_403(app, mock_run_background):
    from app.core.auth import get_current_user

    async with __import__("httpx").AsyncClient(
        transport=__import__("httpx").ASGITransport(app=app),
        base_url="http://test/api/v1",
    ) as c:
        create = await c.post("/incidents", json=SAMPLE_INCIDENT)
    incident_id = create.json()["id"]

    async def _user_b():
        return {"user_id": TEST_USER_ID_2, "email": "other@test.com"}

    app.dependency_overrides[get_current_user] = _user_b
    async with __import__("httpx").AsyncClient(
        transport=__import__("httpx").ASGITransport(app=app),
        base_url="http://test/api/v1",
    ) as c_b:
        resp = await c_b.get(f"/incidents/{incident_id}")

    async def _user_a():
        return {"user_id": TEST_USER_ID, "email": "test@test.com"}
    app.dependency_overrides[get_current_user] = _user_a

    assert resp.status_code == 403


async def test_get_incident_not_found_404(client):
    resp = await client.get("/incidents/nonexistent-id")
    assert resp.status_code == 404


# ── PATCH /incidents/{id}/resolve ─────────────────────────────────────────────


async def test_resolve_incident_returns_200(client, mock_run_background):
    create = await client.post("/incidents", json=SAMPLE_INCIDENT)
    incident_id = create.json()["id"]
    resp = await client.patch(f"/incidents/{incident_id}/resolve")
    assert resp.status_code == 200


async def test_resolve_incident_sets_resolved_at(client, db, mock_run_background):
    create = await client.post("/incidents", json=SAMPLE_INCIDENT)
    incident_id = create.json()["id"]
    await client.patch(f"/incidents/{incident_id}/resolve")

    result = await db.execute(select(Incident).where(Incident.id == incident_id))
    inc = result.scalar_one()
    assert inc.resolved_at is not None
    assert inc.status == "resolved"


async def test_resolve_incident_timeline_event(client, db, mock_run_background):
    create = await client.post("/incidents", json=SAMPLE_INCIDENT)
    incident_id = create.json()["id"]
    await client.patch(f"/incidents/{incident_id}/resolve")

    result = await db.execute(
        select(TimelineEvent).where(
            TimelineEvent.incident_id == incident_id,
            TimelineEvent.event_type == "incident_resolved",
        )
    )
    assert result.scalar_one_or_none() is not None


# ── PATCH /incidents/{id}/reopen ──────────────────────────────────────────────


async def test_reopen_incident_returns_in_progress(client, db, mock_run_background):
    create = await client.post("/incidents", json=SAMPLE_INCIDENT)
    incident_id = create.json()["id"]
    await client.patch(f"/incidents/{incident_id}/resolve")
    resp = await client.patch(f"/incidents/{incident_id}/reopen")
    assert resp.status_code == 200
    assert resp.json()["status"] == "in_progress"


async def test_reopen_preserves_resolved_at(client, db, mock_run_background):
    create = await client.post("/incidents", json=SAMPLE_INCIDENT)
    incident_id = create.json()["id"]
    await client.patch(f"/incidents/{incident_id}/resolve")

    # Capture resolved_at before reopen.
    result = await db.execute(select(Incident).where(Incident.id == incident_id))
    inc = result.scalar_one()
    resolved_at_before = inc.resolved_at
    await db.refresh(inc)

    await client.patch(f"/incidents/{incident_id}/reopen")

    await db.refresh(inc)
    # resolved_at must NOT be cleared on reopen.
    assert inc.resolved_at == resolved_at_before


async def test_reopen_creates_timeline_event(client, db, mock_run_background):
    create = await client.post("/incidents", json=SAMPLE_INCIDENT)
    incident_id = create.json()["id"]
    await client.patch(f"/incidents/{incident_id}/resolve")
    await client.patch(f"/incidents/{incident_id}/reopen")

    result = await db.execute(
        select(TimelineEvent).where(
            TimelineEvent.incident_id == incident_id,
            TimelineEvent.event_type == "incident_reopened",
        )
    )
    assert result.scalar_one_or_none() is not None

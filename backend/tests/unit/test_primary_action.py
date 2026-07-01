"""Unit tests for compute_primary_action and compute_secondary_actions.

Uses SimpleNamespace to simulate Incident and FixFlow without DB access.
These are pure-function tests — no async, no database.
"""
from types import SimpleNamespace

from app.services.incident_service import compute_primary_action, compute_secondary_actions

INC_ID = "aaaaaaaa-0000-0000-0000-000000000001"


def _incident(**kwargs) -> SimpleNamespace:
    defaults = dict(
        id=INC_ID,
        user_id="user-1",
        status="open",
        analysis_status="completed",
        fix_flows=[],
        root_cause=None,
        confidence=None,
    )
    return SimpleNamespace(**{**defaults, **kwargs})


def _fix_flow(is_attempted=False) -> SimpleNamespace:
    return SimpleNamespace(is_attempted=is_attempted)


# ── Pending / processing → always None ────────────────────────────────────────


def test_pending_returns_none():
    inc = _incident(analysis_status="pending")
    assert compute_primary_action(inc) is None


def test_processing_returns_none():
    inc = _incident(analysis_status="processing")
    assert compute_primary_action(inc) is None


# ── Failed → RCA retry button ─────────────────────────────────────────────────


def test_failed_returns_rca_descriptor():
    inc = _incident(analysis_status="failed")
    pa = compute_primary_action(inc)
    assert pa is not None
    assert pa["label"] == "Root Cause Analysis"
    assert f"/incidents/{INC_ID}/ai-actions" in pa["endpoint"]
    assert pa["payload"]["action_type"] == "root_cause_analysis"


def test_failed_secondary_actions_empty():
    inc = _incident(analysis_status="failed")
    sa = compute_secondary_actions(inc)
    assert sa == []


# ── Completed + open (no fix flows selected yet) → no CTA ────────────────────


def test_completed_open_no_fix_flows_returns_none():
    inc = _incident(status="open", analysis_status="completed", fix_flows=[])
    assert compute_primary_action(inc) is None


# ── Completed + in_progress + NOT all attempted → lifecycle Mark Resolved ─────


def test_in_progress_not_all_attempted_returns_lifecycle():
    flows = [_fix_flow(is_attempted=True), _fix_flow(is_attempted=False)]
    inc = _incident(status="in_progress", analysis_status="completed", fix_flows=flows)
    pa = compute_primary_action(inc)
    assert pa is not None
    assert pa["label"] == "Mark Resolved"
    assert f"/incidents/{INC_ID}/resolve" in pa["endpoint"]


def test_in_progress_no_fix_flows_returns_lifecycle():
    inc = _incident(status="in_progress", analysis_status="completed", fix_flows=[])
    pa = compute_primary_action(inc)
    assert pa is not None
    assert pa["label"] == "Mark Resolved"


# ── Completed + in_progress + ALL attempted → IFF button ─────────────────────


def test_in_progress_all_attempted_returns_iff_descriptor():
    flows = [_fix_flow(is_attempted=True), _fix_flow(is_attempted=True)]
    inc = _incident(status="in_progress", analysis_status="completed", fix_flows=flows)
    pa = compute_primary_action(inc)
    assert pa is not None
    assert pa["label"] == "Generate Improved Fix Flow"
    assert f"/incidents/{INC_ID}/ai-actions" in pa["endpoint"]
    assert pa["payload"]["action_type"] == "improved_fix_flow"


def test_in_progress_all_attempted_secondary_has_resolve():
    flows = [_fix_flow(is_attempted=True)]
    inc = _incident(status="in_progress", analysis_status="completed", fix_flows=flows)
    sa = compute_secondary_actions(inc)
    assert len(sa) == 1
    assert sa[0]["label"] == "Mark Resolved Anyway"
    assert f"/incidents/{INC_ID}/resolve" in sa[0]["endpoint"]


# ── Resolved → Close Incident ─────────────────────────────────────────────────


def test_resolved_returns_close_incident():
    inc = _incident(status="resolved", analysis_status="completed")
    pa = compute_primary_action(inc)
    assert pa is not None
    assert pa["label"] == "Close Incident"
    assert f"/incidents/{INC_ID}/close" in pa["endpoint"]


def test_resolved_secondary_has_reopen():
    inc = _incident(status="resolved", analysis_status="completed")
    sa = compute_secondary_actions(inc)
    assert any(a["label"] == "Mark In Progress" for a in sa)


# ── Closed → no CTA ──────────────────────────────────────────────────────────


def test_closed_returns_none():
    inc = _incident(status="closed", analysis_status="completed")
    assert compute_primary_action(inc) is None


def test_closed_secondary_empty():
    inc = _incident(status="closed", analysis_status="completed")
    assert compute_secondary_actions(inc) == []


# ── IFF pending / processing inside in_progress ───────────────────────────────


def test_iff_pending_blocks_primary():
    flows = [_fix_flow(is_attempted=True)]
    inc = _incident(status="in_progress", analysis_status="pending", fix_flows=flows)
    assert compute_primary_action(inc) is None


def test_iff_processing_blocks_primary():
    flows = [_fix_flow(is_attempted=True)]
    inc = _incident(status="in_progress", analysis_status="processing", fix_flows=flows)
    assert compute_primary_action(inc) is None

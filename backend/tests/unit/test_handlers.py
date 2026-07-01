"""Unit tests for RootCauseAnalysisHandler and ImprovedFixFlowHandler.

Tests is_primary_for, validate, parse_output, build_input_snapshot, and
timeline_event_text. No DB access needed — handlers receive mock Incident objects.
"""
import json
import pytest
from types import SimpleNamespace

from app.ai_platform.handlers.root_cause_analysis import RootCauseAnalysisHandler
from app.ai_platform.handlers.improved_fix_flow import ImprovedFixFlowHandler
from app.ai_platform.context.types import (
    CoreIncidentContext,
    RootCauseContext,
    AttemptedFlowSummary,
    AttemptedFlowsContext,
    OperatorNotesContext,
    SimilarIncidentsContext,
    RootCauseAnalysisContext,
    ImprovedFixFlowContext,
)

rca = RootCauseAnalysisHandler()
iff = ImprovedFixFlowHandler()

INC_ID = "test-00000000-0000"


def _incident(**kwargs):
    defaults = dict(
        id=INC_ID,
        status="open",
        analysis_status="completed",
        fix_flows=[],
        root_cause=None,
        confidence=None,
    )
    return SimpleNamespace(**{**defaults, **kwargs})


def _fix_flow(is_attempted=False, generation=1):
    return SimpleNamespace(is_attempted=is_attempted, generation=generation)


def _make_rca_context(log="some log", similar_formatted="None available."):
    core = CoreIncidentContext(
        log_text=log,
        log_truncated=False,
        char_count=len(log),
        title="Test",
        severity="critical",
        components=["Postgres"],
        origin_type="manual_text",
    )
    similar = SimilarIncidentsContext(pairs=[], formatted=similar_formatted)
    return RootCauseAnalysisContext(core=core, similar=similar)


def _make_iff_context(attempted_count=1):
    core = CoreIncidentContext(
        log_text="log text",
        log_truncated=False,
        char_count=8,
        title="Test",
        severity="major",
        components=[],
        origin_type=None,
    )
    root_cause = RootCauseContext(root_cause="Disk full", confidence=0.8, source_action_id=None)
    flows = [
        AttemptedFlowSummary(title=f"Flow {i}", steps=["Step 1"], generation=1)
        for i in range(attempted_count)
    ]
    attempted = AttemptedFlowsContext(flows=flows)
    notes = OperatorNotesContext(content="")
    similar = SimilarIncidentsContext(pairs=[], formatted="None available.")
    return ImprovedFixFlowContext(
        core=core, root_cause=root_cause, attempted_flows=attempted,
        notes=notes, similar=similar,
    )


# ── RCA: is_primary_for ───────────────────────────────────────────────────────


def test_rca_is_primary_for_failed():
    assert rca.is_primary_for(_incident(analysis_status="failed")) is True


def test_rca_is_primary_for_completed_false():
    assert rca.is_primary_for(_incident(analysis_status="completed")) is False


def test_rca_is_primary_for_pending_false():
    assert rca.is_primary_for(_incident(analysis_status="pending")) is False


def test_rca_is_primary_for_processing_false():
    assert rca.is_primary_for(_incident(analysis_status="processing")) is False


# ── RCA: validate ──────────────────────────────────────────────────────────────


def test_rca_validate_never_raises():
    # RCA can always be requested (DB lock enforces deduplication).
    rca.validate(_incident(status="open"))
    rca.validate(_incident(status="in_progress"))
    rca.validate(_incident(status="resolved"))


# ── RCA: parse_output ─────────────────────────────────────────────────────────


def test_rca_parse_output_plain_json():
    payload = {"root_cause": "DB full", "confidence": 0.9, "fix_flows": []}
    result = rca.parse_output(json.dumps(payload))
    assert result["root_cause"] == "DB full"


def test_rca_parse_output_code_fenced_json():
    payload = {"root_cause": "DB full", "fix_flows": []}
    raw = f"```json\n{json.dumps(payload)}\n```"
    result = rca.parse_output(raw)
    assert result["root_cause"] == "DB full"


def test_rca_parse_output_invalid_raises_runtime_error():
    with pytest.raises(RuntimeError, match="invalid JSON"):
        rca.parse_output("not json at all")


# ── RCA: build_input_snapshot ────────────────────────────────────────────────


def test_rca_build_input_snapshot_keys():
    ctx = _make_rca_context()
    snap = rca.build_input_snapshot(ctx)
    assert snap["action_type"] == "root_cause_analysis"
    assert snap["similar_incident_count"] == 0
    assert snap["attempted_flow_count"] == 0
    assert snap["operator_notes_present"] is False
    assert "log_char_count" in snap
    assert "log_truncated" in snap


def test_rca_output_schema_version():
    # Documents F6 divergence: spec says "rca_v1", implementation uses "1.0"
    assert rca.output_schema_version == "1.0"


# ── RCA: build_prompt ─────────────────────────────────────────────────────────


def test_rca_build_prompt_contains_title():
    ctx = _make_rca_context()
    prompt = rca.build_prompt(ctx)
    assert "Test" in prompt


def test_rca_build_prompt_contains_severity():
    ctx = _make_rca_context()
    prompt = rca.build_prompt(ctx)
    assert "critical" in prompt


def test_rca_build_prompt_contains_similar_context():
    ctx = _make_rca_context(similar_formatted="INC-2026-001")
    prompt = rca.build_prompt(ctx)
    assert "INC-2026-001" in prompt


# ── IFF: is_primary_for ───────────────────────────────────────────────────────


def test_iff_is_primary_for_all_attempted_in_progress():
    flows = [_fix_flow(is_attempted=True), _fix_flow(is_attempted=True)]
    inc = _incident(status="in_progress", fix_flows=flows)
    assert iff.is_primary_for(inc) is True


def test_iff_is_primary_for_status_open_false():
    flows = [_fix_flow(is_attempted=True)]
    inc = _incident(status="open", fix_flows=flows)
    assert iff.is_primary_for(inc) is False


def test_iff_is_primary_for_no_fix_flows_false():
    inc = _incident(status="in_progress", fix_flows=[])
    assert iff.is_primary_for(inc) is False


def test_iff_is_primary_for_not_all_attempted_false():
    flows = [_fix_flow(is_attempted=True), _fix_flow(is_attempted=False)]
    inc = _incident(status="in_progress", fix_flows=flows)
    assert iff.is_primary_for(inc) is False


def test_iff_is_primary_for_resolved_false():
    flows = [_fix_flow(is_attempted=True)]
    inc = _incident(status="resolved", fix_flows=flows)
    assert iff.is_primary_for(inc) is False


# ── IFF: validate ─────────────────────────────────────────────────────────────


def test_iff_validate_valid_does_not_raise():
    flows = [_fix_flow(is_attempted=True)]
    inc = _incident(status="in_progress", fix_flows=flows)
    iff.validate(inc)  # should not raise


def test_iff_validate_not_in_progress_raises_422():
    from fastapi import HTTPException
    flows = [_fix_flow(is_attempted=True)]
    inc = _incident(status="open", fix_flows=flows)
    with pytest.raises(HTTPException) as exc_info:
        iff.validate(inc)
    assert exc_info.value.status_code == 422


def test_iff_validate_no_fix_flows_raises_422():
    from fastapi import HTTPException
    inc = _incident(status="in_progress", fix_flows=[])
    with pytest.raises(HTTPException) as exc_info:
        iff.validate(inc)
    assert exc_info.value.status_code == 422


def test_iff_validate_not_all_attempted_raises_422():
    from fastapi import HTTPException
    flows = [_fix_flow(is_attempted=True), _fix_flow(is_attempted=False)]
    inc = _incident(status="in_progress", fix_flows=flows)
    with pytest.raises(HTTPException) as exc_info:
        iff.validate(inc)
    assert exc_info.value.status_code == 422


# ── IFF: parse_output ─────────────────────────────────────────────────────────


def test_iff_parse_output_plain_json():
    payload = {"root_cause": "Updated hypothesis", "confidence": 0.9, "fix_flows": []}
    result = iff.parse_output(json.dumps(payload))
    assert result["root_cause"] == "Updated hypothesis"


def test_iff_parse_output_code_fenced():
    payload = {"root_cause": "X", "fix_flows": []}
    raw = f"```json\n{json.dumps(payload)}\n```"
    result = iff.parse_output(raw)
    assert result["root_cause"] == "X"


def test_iff_parse_output_invalid_raises_runtime_error():
    with pytest.raises(RuntimeError, match="invalid JSON"):
        iff.parse_output("not valid json")


# ── IFF: build_input_snapshot ────────────────────────────────────────────────


def test_iff_build_input_snapshot_attempted_flow_count():
    ctx = _make_iff_context(attempted_count=3)
    snap = iff.build_input_snapshot(ctx)
    assert snap["attempted_flow_count"] == 3
    assert snap["action_type"] == "improved_fix_flow"


def test_iff_output_schema_version():
    # Documents F6 divergence: spec says "iff_v1", implementation uses "1.0"
    assert iff.output_schema_version == "1.0"


# ── IFF: timeline_event_text ─────────────────────────────────────────────────


def test_iff_timeline_text_singular():
    text = iff.timeline_event_text({"fix_flows": [{"title": "x"}]})
    assert "1 improved fix flow" in text


def test_iff_timeline_text_plural():
    text = iff.timeline_event_text({"fix_flows": [{"title": "x"}, {"title": "y"}]})
    assert "2 improved fix flows" in text


def test_iff_timeline_text_zero():
    text = iff.timeline_event_text({"fix_flows": []})
    assert "0 improved fix flows" in text


# ── IFF: secondary_actions_for ────────────────────────────────────────────────


def test_iff_secondary_actions_has_resolve():
    inc = _incident(id="some-id", status="in_progress")
    actions = iff.secondary_actions_for(inc)
    assert len(actions) == 1
    assert actions[0]["label"] == "Mark Resolved Anyway"
    assert "/resolve" in actions[0]["endpoint"]

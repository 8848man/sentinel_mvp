"""Unit tests for AI Platform context builder functions."""
import pytest
from types import SimpleNamespace

from app.ai_platform.context.builders import (
    build_core_context,
    build_root_cause_context,
    build_attempted_flows_context,
)
from app.ai_platform.context.types import (
    OperatorNotesContext,
    AttemptedFlowSummary,
    AttemptedFlowsContext,
    SimilarIncidentsContext,
)
from app.core.config import settings


def _incident(**kwargs):
    defaults = dict(
        id="test-id",
        title="Test incident",
        severity="critical",
        components=["PostgreSQL", "Redis"],
        log_text="ERROR: something bad happened",
        origin_type="manual_text",
        root_cause=None,
        confidence=None,
        fix_flows=[],
    )
    return SimpleNamespace(**{**defaults, **kwargs})


def _fix_flow(title="Fix A", is_attempted=False, generation=1, checklist_items=None):
    return SimpleNamespace(
        title=title,
        is_attempted=is_attempted,
        generation=generation,
        checklist_items=checklist_items or [],
    )


def _checklist_item(description):
    return SimpleNamespace(description=description)


# ── build_core_context ─────────────────────────────────────────────────────────


def test_core_context_captures_fields():
    inc = _incident(title="DB crash", severity="major", components=["Postgres"])
    ctx = build_core_context(inc)
    assert ctx.title == "DB crash"
    assert ctx.severity == "major"
    assert ctx.components == ["Postgres"]
    assert ctx.origin_type == "manual_text"


def test_core_context_short_log_not_truncated():
    log = "Short log text"
    inc = _incident(log_text=log)
    ctx = build_core_context(inc)
    assert ctx.log_text == log
    assert ctx.log_truncated is False
    assert ctx.char_count == len(log)


def test_core_context_long_log_truncated():
    max_chars = settings.MAX_ANALYSIS_INPUT_CHARS
    long_log = "X" * (max_chars + 100)
    inc = _incident(log_text=long_log)
    ctx = build_core_context(inc)
    assert ctx.log_truncated is True
    assert "omitted" in ctx.log_text


def test_core_context_truncated_log_contains_omission_marker():
    max_chars = settings.MAX_ANALYSIS_INPUT_CHARS
    long_log = "A" * (max_chars // 2 + 10) + "B" * (max_chars // 2 + 10)
    inc = _incident(log_text=long_log)
    ctx = build_core_context(inc)
    assert "characters omitted" in ctx.log_text


def test_core_context_empty_components():
    inc = _incident(components=[])
    ctx = build_core_context(inc)
    assert ctx.components == []


# ── build_root_cause_context ──────────────────────────────────────────────────


def test_root_cause_context_reads_incident():
    inc = _incident(root_cause="Disk full", confidence=0.95)
    ctx = build_root_cause_context(inc)
    assert ctx.root_cause == "Disk full"
    assert abs(ctx.confidence - 0.95) < 0.001


def test_root_cause_context_none_values():
    inc = _incident(root_cause=None, confidence=None)
    ctx = build_root_cause_context(inc)
    assert ctx.root_cause is None
    assert ctx.confidence is None


def test_root_cause_context_source_action_id_is_none():
    # source_action_id is always None — not tracked on the incident cache.
    inc = _incident(root_cause="Something", confidence=0.8)
    ctx = build_root_cause_context(inc)
    assert ctx.source_action_id is None


# ── build_attempted_flows_context ─────────────────────────────────────────────


def test_attempted_flows_empty():
    inc = _incident(fix_flows=[])
    ctx = build_attempted_flows_context(inc)
    assert ctx.count == 0
    assert ctx.flows == []


def test_attempted_flows_filters_unattempted():
    flows = [
        _fix_flow(is_attempted=True, title="Tried"),
        _fix_flow(is_attempted=False, title="Not tried"),
    ]
    inc = _incident(fix_flows=flows)
    ctx = build_attempted_flows_context(inc)
    assert ctx.count == 1
    assert ctx.flows[0].title == "Tried"


def test_attempted_flows_includes_steps():
    items = [_checklist_item("Step 1"), _checklist_item("Step 2")]
    flow = _fix_flow(is_attempted=True, checklist_items=items)
    inc = _incident(fix_flows=[flow])
    ctx = build_attempted_flows_context(inc)
    assert ctx.flows[0].steps == ["Step 1", "Step 2"]


def test_attempted_flows_generation_preserved():
    flow = _fix_flow(is_attempted=True, generation=2)
    inc = _incident(fix_flows=[flow])
    ctx = build_attempted_flows_context(inc)
    assert ctx.flows[0].generation == 2


# ── OperatorNotesContext.is_present ───────────────────────────────────────────


def test_operator_notes_empty_not_present():
    assert OperatorNotesContext(content="").is_present is False


def test_operator_notes_whitespace_not_present():
    assert OperatorNotesContext(content="   \n").is_present is False


def test_operator_notes_content_present():
    assert OperatorNotesContext(content="Some note").is_present is True


# ── SimilarIncidentsContext.count ─────────────────────────────────────────────


def test_similar_incidents_count():
    ctx = SimilarIncidentsContext(pairs=["a", "b", "c"], formatted="x")
    assert ctx.count == 3


def test_similar_incidents_empty_count():
    ctx = SimilarIncidentsContext(pairs=[], formatted="None available.")
    assert ctx.count == 0


# ── AttemptedFlowsContext.count ───────────────────────────────────────────────


def test_attempted_flows_count():
    flows = [AttemptedFlowSummary(title="A", steps=[], generation=1)]
    ctx = AttemptedFlowsContext(flows=flows)
    assert ctx.count == 1

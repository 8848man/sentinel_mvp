"""Unit tests for the AI Platform handler registry."""
from app.ai_platform import registry
from app.ai_platform.handlers.root_cause_analysis import RootCauseAnalysisHandler
from app.ai_platform.handlers.improved_fix_flow import ImprovedFixFlowHandler


def test_registry_contains_rca():
    assert "root_cause_analysis" in registry.REGISTRY


def test_registry_contains_iff():
    assert "improved_fix_flow" in registry.REGISTRY


def test_registry_rca_instance():
    assert isinstance(registry.REGISTRY["root_cause_analysis"], RootCauseAnalysisHandler)


def test_registry_iff_instance():
    assert isinstance(registry.REGISTRY["improved_fix_flow"], ImprovedFixFlowHandler)


def test_get_handler_rca():
    h = registry.get_handler("root_cause_analysis")
    assert isinstance(h, RootCauseAnalysisHandler)


def test_get_handler_iff():
    h = registry.get_handler("improved_fix_flow")
    assert isinstance(h, ImprovedFixFlowHandler)


def test_get_handler_unknown_returns_none():
    assert registry.get_handler("nonexistent_action") is None


def test_priority_order_rca_before_iff():
    types = [h.action_type for h in registry.PRIORITY_ORDER]
    assert types.index("root_cause_analysis") < types.index("improved_fix_flow")


def test_priority_values():
    rca = registry.REGISTRY["root_cause_analysis"]
    iff = registry.REGISTRY["improved_fix_flow"]
    assert rca.priority < iff.priority


def test_all_system_triggers_no_match():
    result = registry.all_system_triggers("nonexistent.event")
    assert result == []


def test_all_system_triggers_no_current_handlers_trigger():
    # Neither current handler auto-fires — both are operator-only.
    result = registry.all_system_triggers("incident.resolved")
    assert result == []


def test_handler_action_type_matches_registry_key():
    for key, handler in registry.REGISTRY.items():
        assert handler.action_type == key


def test_handler_display_name_set():
    for handler in registry.REGISTRY.values():
        assert handler.display_name

"""Handler registry.

REGISTRY is the single source of truth for all registered AI action types.
Adding a new capability: instantiate the handler and add it here.

compute_primary_action and compute_secondary_actions iterate PRIORITY_ORDER
(handlers sorted by priority ascending) to find the first handler that
claims the primary slot for the current incident state.
"""
from __future__ import annotations
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from app.models.models import Incident
    from app.ai_platform.handlers.base import AIActionHandler

# Populated at module import time. Handlers imported here to avoid circularity.
from app.ai_platform.handlers.root_cause_analysis import RootCauseAnalysisHandler
from app.ai_platform.handlers.improved_fix_flow import ImprovedFixFlowHandler

REGISTRY: dict[str, "AIActionHandler"] = {
    "root_cause_analysis": RootCauseAnalysisHandler(),
    "improved_fix_flow": ImprovedFixFlowHandler(),
}

# Sorted by priority (ascending) for primary action selection.
PRIORITY_ORDER: list["AIActionHandler"] = sorted(
    REGISTRY.values(), key=lambda h: h.priority
)


def get_handler(action_type: str) -> "AIActionHandler | None":
    return REGISTRY.get(action_type)


def all_system_triggers(event: str) -> list["AIActionHandler"]:
    """Return handlers that auto-fire on the given lifecycle event slug."""
    return [h for h in REGISTRY.values() if event in h.system_triggers]

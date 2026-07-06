"""Abstract base class for all AI action handlers.

Adding a new AI capability = subclass AIActionHandler, implement the abstract
methods, set the class attributes, and register an instance in registry.py.
Nothing else changes.

Primary action selection:
  Handlers compete for the primary_action slot via is_primary_for(). The
  executor iterates handlers in priority order (lower number = higher priority)
  and returns the first match. Lifecycle actions (resolve, close) are the
  fallback when no handler claims the slot.

System triggers:
  system_triggers lists lifecycle event slugs that auto-fire this handler
  without operator input (e.g. "incident.resolved" → postmortem generation).
  Empty list means operator-only.
"""
from __future__ import annotations

from abc import ABC, abstractmethod
from typing import TYPE_CHECKING, Any

from sqlalchemy.ext.asyncio import AsyncSession

if TYPE_CHECKING:
    from app.models.models import AIAction, Incident


class AIActionHandler(ABC):
    # ── Class-level identity ───────────────────────────────────────────────────
    action_type: str          # registry key and DB value
    display_name: str         # operator-facing label fragment
    description: str          # shown in primary_action.description
    output_schema_version: str

    # ── Registry metadata ──────────────────────────────────────────────────────
    priority: int = 50        # lower = higher priority in primary action selection
    system_triggers: list[str] = []  # lifecycle event slugs that auto-fire this
    timeout_seconds: int | None = None  # None → use settings.ANALYSIS_TIMEOUT_SECONDS

    # ── Primary action interface ───────────────────────────────────────────────

    def is_primary_for(self, incident: "Incident") -> bool:
        """True if this handler should be the primary CTA for the incident now."""
        return False

    def primary_action_descriptor(self, incident: "Incident") -> dict:
        """Renderable primary_action dict. Called only when is_primary_for is True."""
        return {
            "label": self.display_name,
            "description": self.description,
            "endpoint": f"/api/v1/incidents/{incident.id}/ai-actions",
            "payload": {"action_type": self.action_type},
        }

    def secondary_actions_for(self, incident: "Incident") -> list[dict]:
        """Optional secondary actions relevant when this handler is primary."""
        return []

    # ── Precondition validation ────────────────────────────────────────────────

    def validate(self, incident: "Incident") -> None:
        """Raise HTTPException(422) if the action cannot run on this incident."""
        pass

    # ── Execution contract ─────────────────────────────────────────────────────

    @abstractmethod
    async def gather_context(self, incident: "Incident", db: AsyncSession) -> Any:
        """Collect all inputs needed. Returns a typed context dataclass."""
        ...

    @abstractmethod
    def build_prompt(self, context: Any) -> str:
        """Construct the Gemini prompt string from the typed context."""
        ...

    @abstractmethod
    def parse_output(self, response_text: str) -> dict:
        """Parse the model response into a structured dict."""
        ...

    @abstractmethod
    async def persist_results(
        self,
        action: "AIAction",
        incident: "Incident",
        output: dict,
        db: AsyncSession,
    ) -> None:
        """Write action outputs to domain tables within the caller's transaction."""
        ...

    def build_input_snapshot(self, context: Any) -> dict:
        """Build the input_snapshot dict from the gathered context. Override per handler."""
        return {"action_type": self.action_type, "output_schema_version": self.output_schema_version}

    def timeline_event_text(self, output: dict) -> str:
        """Human-readable timeline event string for the completed action."""
        return f"AI {self.display_name.lower()} completed"

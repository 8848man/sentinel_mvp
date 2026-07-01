"""Typed context dataclasses for AI action handlers.

Context objects are immutable (frozen=True). Handlers compose them from
primitive builder functions in builders.py. Prompt templates receive typed
objects, not raw dicts — type errors surface at import time, not at runtime.

Contract: the `log_text` field in CoreIncidentContext is the canonical AI
input for all current action types. It is produced by the incident creation
flow regardless of origin (manual entry normalizes directly; OCR flow runs
extract+cleanup then places the result here). If incident.origin_type is set,
handlers MAY vary their behavior, but log_text remains the primary input.
"""
from dataclasses import dataclass, field


@dataclass(frozen=True)
class CoreIncidentContext:
    """Always included in every AI action. Captures the primary input."""
    log_text: str          # canonical AI input — see module docstring
    log_truncated: bool
    char_count: int
    title: str
    severity: str
    components: list[str]
    origin_type: str | None  # Amendment A: forwarded to handlers that may use it


@dataclass(frozen=True)
class RootCauseContext:
    """AI's prior root cause hypothesis. Included in follow-on actions."""
    root_cause: str | None
    confidence: float | None
    source_action_id: str | None  # which AIAction produced this


@dataclass(frozen=True)
class AttemptedFlowSummary:
    """One attempted fix flow, summarized for prompt injection."""
    title: str
    steps: list[str]
    generation: int


@dataclass(frozen=True)
class AttemptedFlowsContext:
    """Fix flows that were tried and failed. Core input for improved_fix_flow."""
    flows: list[AttemptedFlowSummary]

    @property
    def count(self) -> int:
        return len(self.flows)


@dataclass(frozen=True)
class OperatorNotesContext:
    """Free-text operator notes. Empty string when no note exists."""
    content: str

    @property
    def is_present(self) -> bool:
        return bool(self.content.strip())


@dataclass(frozen=True)
class SimilarIncidentSummary:
    incident_id: str
    incident_code: str


@dataclass(frozen=True)
class SimilarIncidentsContext:
    """Resolved incidents with component overlap. Used for historical context."""
    pairs: list[SimilarIncidentSummary]
    formatted: str  # pre-formatted string ready for prompt injection

    @property
    def count(self) -> int:
        return len(self.pairs)


# ── Composed context types (one per handler) ──────────────────────────────────

@dataclass(frozen=True)
class RootCauseAnalysisContext:
    core: CoreIncidentContext
    similar: SimilarIncidentsContext


@dataclass(frozen=True)
class ImprovedFixFlowContext:
    core: CoreIncidentContext
    root_cause: RootCauseContext
    attempted_flows: AttemptedFlowsContext
    notes: OperatorNotesContext
    similar: SimilarIncidentsContext

"""Improved Fix Flow handler.

Triggered when all fix flows on an in-progress incident have been attempted
but the incident remains unresolved. The AI receives the prior root cause,
the log, what was tried, and operator notes — then generates new approaches.

Produces: new FixFlow rows at generation = (max_existing_generation + 1).
          Updates incident.root_cause and incident.confidence caches.

Does NOT delete prior fix flows. All generations are preserved.
"""
from __future__ import annotations

import json
from typing import TYPE_CHECKING

from fastapi import HTTPException
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai_platform.context.builders import (
    build_core_context,
    build_root_cause_context,
    build_attempted_flows_context,
    build_operator_notes_context,
    build_similar_incidents_context,
)
from app.ai_platform.context.types import ImprovedFixFlowContext
from app.ai_platform.handlers.base import AIActionHandler
from app.models.models import FixFlow, ChecklistItem
from app.services.gemini_service import IMPROVED_FIX_FLOW_PROMPT

if TYPE_CHECKING:
    from app.models.models import AIAction, Incident


class ImprovedFixFlowHandler(AIActionHandler):
    action_type = "improved_fix_flow"
    display_name = "Generate Improved Fix Flow"
    description = (
        "All fix flows were attempted without resolution. "
        "AI will generate new approaches based on what you tried."
    )
    output_schema_version = "1.0"
    priority = 20

    # ── Primary action ─────────────────────────────────────────────────────────

    def is_primary_for(self, incident: "Incident") -> bool:
        if incident.status != "in_progress":
            return False
        if not incident.fix_flows:
            return False
        return all(f.is_attempted for f in incident.fix_flows)

    def primary_action_descriptor(self, incident: "Incident") -> dict:
        return {
            "label": self.display_name,
            "description": self.description,
            "endpoint": f"/api/v1/incidents/{incident.id}/ai-actions",
            "payload": {"action_type": self.action_type},
        }

    def secondary_actions_for(self, incident: "Incident") -> list[dict]:
        return [
            {
                "label": "Mark Resolved Anyway",
                "description": "Resolve the incident without generating new fix flows.",
                "endpoint": f"/api/v1/incidents/{incident.id}/resolve",
                "payload": {},
            }
        ]

    def validate(self, incident: "Incident") -> None:
        if incident.status != "in_progress":
            raise HTTPException(
                422, "Improved fix flow requires incident to be in_progress"
            )
        if not incident.fix_flows:
            raise HTTPException(
                422, "No fix flows exist to improve upon"
            )
        if not all(f.is_attempted for f in incident.fix_flows):
            raise HTTPException(
                422, "All fix flows must be attempted before requesting improved analysis"
            )

    # ── Execution ──────────────────────────────────────────────────────────────

    async def gather_context(
        self, incident: "Incident", db: AsyncSession
    ) -> ImprovedFixFlowContext:
        return ImprovedFixFlowContext(
            core=build_core_context(incident),
            root_cause=build_root_cause_context(incident),
            attempted_flows=build_attempted_flows_context(incident),
            notes=await build_operator_notes_context(incident, db),
            similar=await build_similar_incidents_context(incident, db),
        )

    def build_prompt(self, context: ImprovedFixFlowContext) -> str:
        attempted_text = _format_attempted_flows(context.attempted_flows.flows)
        return IMPROVED_FIX_FLOW_PROMPT.format(
            title=context.core.title,
            severity=context.core.severity,
            components=", ".join(context.core.components) or "Unknown",
            root_cause=context.root_cause.root_cause or "Unknown",
            log_text=context.core.log_text,
            attempted_flows=attempted_text,
            operator_notes=context.notes.content or "None provided.",
            similar_context=context.similar.formatted,
        )

    def parse_output(self, response_text: str) -> dict:
        clean = response_text.strip()
        if clean.startswith("```"):
            clean = clean.split("\n", 1)[-1].rsplit("```", 1)[0]
        try:
            return json.loads(clean)
        except json.JSONDecodeError:
            raise RuntimeError("Gemini returned invalid JSON for improved fix flow")

    async def persist_results(
        self,
        action: "AIAction",
        incident: "Incident",
        output: dict,
        db: AsyncSession,
    ) -> None:
        incident_id = str(incident.id)

        # Find the current max generation to write the next one.
        result = await db.execute(
            select(func.max(FixFlow.generation)).where(FixFlow.incident_id == incident_id)
        )
        max_gen = result.scalar() or 0
        next_generation = max_gen + 1

        for i, flow_data in enumerate(output.get("fix_flows", [])):
            flow = FixFlow(
                incident_id=incident_id,
                source_action_id=action.id,
                title=flow_data["title"],
                confidence=flow_data["confidence"],
                generation=next_generation,
                sort_order=i,
            )
            db.add(flow)
            await db.flush()
            for j, step in enumerate(flow_data.get("checklist_items", []), start=1):
                db.add(ChecklistItem(
                    fix_flow_id=flow.id,
                    step_number=j,
                    description=step,
                ))

        # Update incident root_cause cache with the refined hypothesis.
        if output.get("root_cause"):
            incident.root_cause = output["root_cause"]
        if output.get("confidence") is not None:
            incident.confidence = output["confidence"]

    def build_input_snapshot(self, context: ImprovedFixFlowContext) -> dict:
        return {
            "action_type": self.action_type,
            "output_schema_version": self.output_schema_version,
            "log_char_count": context.core.char_count,
            "log_truncated": context.core.log_truncated,
            "similar_incident_count": context.similar.count,
            "attempted_flow_count": context.attempted_flows.count,
            "operator_notes_present": context.notes.is_present,
            "origin_type": context.core.origin_type,
        }

    def timeline_event_text(self, output: dict) -> str:
        count = len(output.get("fix_flows", []))
        return f"AI generated {count} improved fix flow{'s' if count != 1 else ''}"


# ── Prompt formatting helper ───────────────────────────────────────────────────

def _format_attempted_flows(flows) -> str:
    if not flows:
        return "None."
    parts = []
    for flow in flows:
        steps = "\n".join(f"  - {s}" for s in flow.steps)
        parts.append(f"Fix flow: {flow.title}\nSteps attempted:\n{steps}")
    return "\n\n".join(parts)

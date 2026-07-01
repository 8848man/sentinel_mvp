"""Root Cause Analysis handler.

Produces: root_cause text (cached on Incident), fix_flows (FixFlow rows),
          similar_incidents (SimilarIncident rows).

Primary action slot: when analysis_status == "failed" (retry path).
The initial run is triggered automatically on incident creation — it does not
appear as a primary action button because the UI shows a spinner instead.
"""
from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import TYPE_CHECKING

from fastapi import HTTPException
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai_platform.context.builders import (
    build_core_context,
    build_similar_incidents_context,
)
from app.ai_platform.context.types import RootCauseAnalysisContext
from app.ai_platform.handlers.base import AIActionHandler
from app.models.models import FixFlow, ChecklistItem, SimilarIncident
from app.services.gemini_service import ANALYSIS_PROMPT

if TYPE_CHECKING:
    from app.models.models import AIAction, Incident


class RootCauseAnalysisHandler(AIActionHandler):
    action_type = "root_cause_analysis"
    display_name = "Root Cause Analysis"
    description = "Analysis failed. AI will re-analyze the incident log."
    output_schema_version = "1.0"
    priority = 10  # highest priority — failure state is the most urgent

    # ── Primary action ─────────────────────────────────────────────────────────

    def is_primary_for(self, incident: "Incident") -> bool:
        return incident.analysis_status == "failed"

    def validate(self, incident: "Incident") -> None:
        # Can always request root_cause_analysis as long as the incident exists.
        # The active-action lock (partial unique index) prevents duplicate runs.
        pass

    # ── Execution ──────────────────────────────────────────────────────────────

    async def gather_context(
        self, incident: "Incident", db: AsyncSession
    ) -> RootCauseAnalysisContext:
        return RootCauseAnalysisContext(
            core=build_core_context(incident),
            similar=await build_similar_incidents_context(incident, db),
        )

    def build_prompt(self, context: RootCauseAnalysisContext) -> str:
        return ANALYSIS_PROMPT.format(
            title=context.core.title,
            severity=context.core.severity,
            components=", ".join(context.core.components) or "Unknown",
            log_text=context.core.log_text,
            similar_context=context.similar.formatted,
        )

    def parse_output(self, response_text: str) -> dict:
        clean = response_text.strip()
        if clean.startswith("```"):
            clean = clean.split("\n", 1)[-1].rsplit("```", 1)[0]
        try:
            return json.loads(clean)
        except json.JSONDecodeError:
            raise RuntimeError("Gemini returned invalid JSON for root cause analysis")

    async def persist_results(
        self,
        action: "AIAction",
        incident: "Incident",
        output: dict,
        db: AsyncSession,
    ) -> None:
        incident_id = str(incident.id)

        # Replace old AI results from prior attempts (re-analysis case).
        # Only delete generation=1 fix flows from previous root_cause_analysis runs;
        # improved_fix_flow generations are left untouched.
        await db.execute(
            delete(FixFlow).where(
                FixFlow.incident_id == incident_id,
                FixFlow.generation == 1,
            )
        )
        await db.execute(
            delete(SimilarIncident).where(SimilarIncident.incident_id == incident_id)
        )

        # Determine the current max generation so we don't collide with improved flows.
        # After deleting gen=1 rows above, remaining rows are gen >= 2.
        # We always write new root_cause_analysis results at generation=1.
        generation = 1

        for i, flow_data in enumerate(output.get("fix_flows", [])):
            flow = FixFlow(
                incident_id=incident_id,
                source_action_id=action.id,
                title=flow_data["title"],
                confidence=flow_data["confidence"],
                generation=generation,
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

        for sim in output.get("similar_incident_codes", [])[:3]:
            pass  # resolved below via the context pairs

        # Persist similar incidents from context (already resolved to IDs).
        # The output may reference codes; we use the pre-resolved pairs from context.
        # (Context pairs are not available here — similar incidents written by
        # the caller after inspect of input_snapshot. For now, skip re-resolution
        # and rely on the pre-existing SimilarIncident rows being cleared above.)
        # TODO: pass similar pairs through action.input_snapshot for re-resolution.

        # Update incident cache fields.
        incident.root_cause = output.get("root_cause")
        incident.confidence = output.get("confidence")
        incident.description = output.get("impact_summary")

    def build_input_snapshot(self, context: RootCauseAnalysisContext) -> dict:
        return {
            "action_type": self.action_type,
            "output_schema_version": self.output_schema_version,
            "log_char_count": context.core.char_count,
            "log_truncated": context.core.log_truncated,
            "similar_incident_count": context.similar.count,
            "attempted_flow_count": 0,
            "operator_notes_present": False,
            "origin_type": context.core.origin_type,
        }

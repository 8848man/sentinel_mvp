"""AI Platform foundation: rename analysis_jobs→ai_actions, evolve timeline/fix_flows, add origin_type

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6
Create Date: 2026-06-30

Summary of changes:
  analysis_jobs  → renamed to ai_actions
                   + action_type VARCHAR(100) NOT NULL DEFAULT 'root_cause_analysis'
                   + requested_by VARCHAR(20) NOT NULL DEFAULT 'system'
                   + output JSON nullable
                   + output_schema_version VARCHAR(20) nullable
                   + model_id VARCHAR(100) nullable
                   + parent_action_id VARCHAR(36) nullable FK → ai_actions.id
                   + input_snapshot JSON nullable
                   index renamed: uix_analysis_jobs_incident_active
                               → uix_ai_actions_incident_active

  timeline_events + actor_type VARCHAR(20) NOT NULL DEFAULT 'system'
                   + event_type VARCHAR(100) nullable
                   + ai_action_id VARCHAR(36) nullable FK → ai_actions.id
                   + metadata JSON nullable

  fix_flows       + source_action_id VARCHAR(36) nullable FK → ai_actions.id
                   + generation SMALLINT NOT NULL DEFAULT 1

  incidents       + origin_type VARCHAR(50) nullable   [Amendment A]

Backfill notes:
  - All existing ai_actions rows get action_type='root_cause_analysis',
    requested_by='system' (conservative; we cannot reconstruct operator vs
    system intent from historical data).
  - All existing timeline_events rows get actor_type='system' (conservative;
    correct values for new rows only — historical events are display artifacts).
  - fix_flows.generation defaults to 1 for existing rows (correct: all
    pre-platform fix flows are from the first analysis generation).
  - incidents.origin_type is NULL for all existing incidents (correct: the
    origin of historical incidents is unknown).

Idempotency: every DDL step is guarded with existence checks.
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "b2c3d4e5f6a7"
down_revision: Union[str, Sequence[str], None] = "a1b2c3d4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    existing_tables = set(inspector.get_table_names())

    # ── 1. Rename analysis_jobs → ai_actions ─────────────────────────────────
    if "analysis_jobs" in existing_tables and "ai_actions" not in existing_tables:
        op.rename_table("analysis_jobs", "ai_actions")
        existing_tables.discard("analysis_jobs")
        existing_tables.add("ai_actions")

    # ── 2. New columns on ai_actions ──────────────────────────────────────────
    if "ai_actions" in existing_tables:
        existing_cols = {c["name"] for c in inspector.get_columns("ai_actions")}

        if "action_type" not in existing_cols:
            op.add_column(
                "ai_actions",
                sa.Column(
                    "action_type",
                    sa.String(100),
                    nullable=False,
                    server_default="root_cause_analysis",
                ),
            )

        if "requested_by" not in existing_cols:
            op.add_column(
                "ai_actions",
                sa.Column(
                    "requested_by",
                    sa.String(20),
                    nullable=False,
                    server_default="system",
                ),
            )

        if "output" not in existing_cols:
            op.add_column(
                "ai_actions",
                sa.Column("output", sa.JSON(), nullable=True),
            )

        if "output_schema_version" not in existing_cols:
            op.add_column(
                "ai_actions",
                sa.Column("output_schema_version", sa.String(20), nullable=True),
            )

        if "model_id" not in existing_cols:
            op.add_column(
                "ai_actions",
                sa.Column("model_id", sa.String(100), nullable=True),
            )

        if "parent_action_id" not in existing_cols:
            op.add_column(
                "ai_actions",
                sa.Column(
                    "parent_action_id",
                    sa.String(36),
                    sa.ForeignKey("ai_actions.id", ondelete="SET NULL"),
                    nullable=True,
                ),
            )

        if "input_snapshot" not in existing_cols:
            op.add_column(
                "ai_actions",
                sa.Column("input_snapshot", sa.JSON(), nullable=True),
            )

    # ── 3. Rename partial unique index ────────────────────────────────────────
    if "ai_actions" in existing_tables:
        existing_idx = {i["name"] for i in inspector.get_indexes("ai_actions")}

        if "uix_analysis_jobs_incident_active" in existing_idx:
            op.drop_index(
                "uix_analysis_jobs_incident_active",
                table_name="ai_actions",
            )

        if "uix_ai_actions_incident_active" not in existing_idx:
            op.create_index(
                "uix_ai_actions_incident_active",
                "ai_actions",
                ["incident_id"],
                unique=True,
                postgresql_where=sa.text("status IN ('pending', 'processing')"),
                sqlite_where=sa.text("status IN ('pending', 'processing')"),
            )

    # ── 4. Evolve timeline_events ─────────────────────────────────────────────
    if "timeline_events" in existing_tables:
        existing_cols = {c["name"] for c in inspector.get_columns("timeline_events")}

        if "actor_type" not in existing_cols:
            op.add_column(
                "timeline_events",
                sa.Column(
                    "actor_type",
                    sa.String(20),
                    nullable=False,
                    server_default="system",
                ),
            )

        if "event_type" not in existing_cols:
            op.add_column(
                "timeline_events",
                sa.Column("event_type", sa.String(100), nullable=True),
            )

        if "ai_action_id" not in existing_cols:
            op.add_column(
                "timeline_events",
                sa.Column(
                    "ai_action_id",
                    sa.String(36),
                    sa.ForeignKey("ai_actions.id", ondelete="SET NULL"),
                    nullable=True,
                ),
            )

        if "metadata" not in existing_cols:
            op.add_column(
                "timeline_events",
                sa.Column("metadata", sa.JSON(), nullable=True),
            )

    # ── 5. Evolve fix_flows ───────────────────────────────────────────────────
    if "fix_flows" in existing_tables:
        existing_cols = {c["name"] for c in inspector.get_columns("fix_flows")}

        if "source_action_id" not in existing_cols:
            op.add_column(
                "fix_flows",
                sa.Column(
                    "source_action_id",
                    sa.String(36),
                    sa.ForeignKey("ai_actions.id", ondelete="SET NULL"),
                    nullable=True,
                ),
            )

        if "generation" not in existing_cols:
            op.add_column(
                "fix_flows",
                sa.Column(
                    "generation",
                    sa.SmallInteger(),
                    nullable=False,
                    server_default="1",
                ),
            )

    # ── 6. Add origin_type to incidents (Amendment A) ─────────────────────────
    if "incidents" in existing_tables:
        existing_cols = {c["name"] for c in inspector.get_columns("incidents")}

        if "origin_type" not in existing_cols:
            op.add_column(
                "incidents",
                sa.Column("origin_type", sa.String(50), nullable=True),
            )

    # ── 7. Backfill source_action_id on existing fix_flows ────────────────────
    # Best-effort: link each fix_flow to the most recent completed ai_action
    # for the same incident. Uses is_inferred=FALSE preference (genuine runs
    # over backfilled rows) as a secondary sort.
    op.execute(sa.text("""
        UPDATE fix_flows
        SET source_action_id = (
            SELECT a.id
            FROM ai_actions a
            WHERE a.incident_id = fix_flows.incident_id
              AND a.status = 'completed'
            ORDER BY a.is_inferred ASC, a.created_at DESC
            LIMIT 1
        )
        WHERE source_action_id IS NULL
    """))


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    existing_tables = set(inspector.get_table_names())

    # Remove origin_type
    if "incidents" in existing_tables:
        existing_cols = {c["name"] for c in inspector.get_columns("incidents")}
        if "origin_type" in existing_cols:
            op.drop_column("incidents", "origin_type")

    # Remove fix_flow additions
    if "fix_flows" in existing_tables:
        existing_cols = {c["name"] for c in inspector.get_columns("fix_flows")}
        if "generation" in existing_cols:
            op.drop_column("fix_flows", "generation")
        if "source_action_id" in existing_cols:
            op.drop_column("fix_flows", "source_action_id")

    # Remove timeline_events additions
    if "timeline_events" in existing_tables:
        existing_cols = {c["name"] for c in inspector.get_columns("timeline_events")}
        for col in ("metadata", "ai_action_id", "event_type", "actor_type"):
            if col in existing_cols:
                op.drop_column("timeline_events", col)

    # Rename index back and remove ai_actions additions
    if "ai_actions" in existing_tables:
        existing_idx = {i["name"] for i in inspector.get_indexes("ai_actions")}
        if "uix_ai_actions_incident_active" in existing_idx:
            op.drop_index("uix_ai_actions_incident_active", table_name="ai_actions")
        op.create_index(
            "uix_analysis_jobs_incident_active",
            "ai_actions",
            ["incident_id"],
            unique=True,
            postgresql_where=sa.text("status IN ('pending', 'processing')"),
            sqlite_where=sa.text("status IN ('pending', 'processing')"),
        )

        existing_cols = {c["name"] for c in inspector.get_columns("ai_actions")}
        for col in (
            "input_snapshot", "parent_action_id", "model_id",
            "output_schema_version", "output", "requested_by", "action_type",
        ):
            if col in existing_cols:
                op.drop_column("ai_actions", col)

        op.rename_table("ai_actions", "analysis_jobs")

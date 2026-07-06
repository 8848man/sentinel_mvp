"""add analysis_jobs table and incident analysis fields

Revision ID: a1b2c3d4e5f6
Revises: c4e1f9a03b72
Create Date: 2026-06-26 00:00:00.000000

Summary of changes:
  - incidents: add analysis_status (VARCHAR 20, NOT NULL, DEFAULT 'pending')
  - incidents: add analysis_error (TEXT, nullable)
  - analysis_jobs: new table (source of truth for analysis lifecycle)
  - analysis_jobs: partial unique index on (incident_id) WHERE status IN ('pending','processing')

Backfill strategy (INFERRED DATA — not ground truth):
  Existing incidents are classified by observable evidence:
    root_cause IS NOT NULL → inferred 'completed' (is_inferred=TRUE)
    root_cause IS NULL     → inferred 'failed'    (is_inferred=TRUE)
  All backfilled analysis_jobs rows have is_inferred=TRUE so they can be
  identified and re-analyzed if needed. This is best-effort reconstruction,
  not a verified historical record.

Idempotency note:
  Each DDL step is guarded with existence checks so this migration is safe
  to apply against a DB where analysis_jobs was previously created out-of-band
  (e.g. via a partial or manually-aborted prior migration run). The backfill
  INSERT uses NOT IN (SELECT incident_id FROM analysis_jobs) to avoid duplicate
  rows if the table already contains data.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, Sequence[str], None] = 'c4e1f9a03b72'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    # ── 1. Add analysis columns to incidents ──────────────────────────────────
    existing_incident_cols = {col['name'] for col in inspector.get_columns('incidents')}

    if 'analysis_status' not in existing_incident_cols:
        op.add_column(
            'incidents',
            sa.Column('analysis_status', sa.String(20), nullable=False, server_default='pending'),
        )

    if 'analysis_error' not in existing_incident_cols:
        op.add_column(
            'incidents',
            sa.Column('analysis_error', sa.Text(), nullable=True),
        )

    # ── 2. Create analysis_jobs table ─────────────────────────────────────────
    # Guard: the table may already exist if a prior migration run was interrupted
    # after CREATE TABLE but before the alembic_version stamp was updated.
    existing_tables = inspector.get_table_names()

    if 'analysis_jobs' not in existing_tables:
        op.create_table(
            'analysis_jobs',
            sa.Column('id', sa.String(36), primary_key=True),
            sa.Column(
                'incident_id',
                sa.String(36),
                sa.ForeignKey('incidents.id', ondelete='CASCADE'),
                nullable=False,
                index=True,
            ),
            sa.Column('attempt_number', sa.SmallInteger(), nullable=False),
            sa.Column('status', sa.String(20), nullable=False, server_default='pending'),
            sa.Column('error_message', sa.Text(), nullable=True),
            sa.Column('is_inferred', sa.Boolean(), nullable=False, server_default='false'),
            sa.Column('input_char_count', sa.Integer(), nullable=True),
            sa.Column('started_at', sa.DateTime(timezone=True), nullable=True),
            sa.Column('completed_at', sa.DateTime(timezone=True), nullable=True),
            sa.Column(
                'created_at',
                sa.DateTime(timezone=True),
                nullable=False,
                server_default=sa.text('NOW()'),
            ),
        )

    # ── 3. Partial unique index: at most one active job per incident ───────────
    existing_indexes = {idx['name'] for idx in inspector.get_indexes('analysis_jobs')}

    if 'uix_analysis_jobs_incident_active' not in existing_indexes:
        op.create_index(
            'uix_analysis_jobs_incident_active',
            'analysis_jobs',
            ['incident_id'],
            unique=True,
            postgresql_where=sa.text("status IN ('pending', 'processing')"),
        )

    # ── 4. Backfill existing incidents (INFERRED DATA — see docstring) ────────
    #
    # Infer 'completed' from presence of root_cause; 'failed' otherwise.
    # All rows created here have is_inferred=TRUE — never treat them as verified.
    # NOT IN guard makes backfill idempotent if table already has rows.

    op.execute(sa.text("""
        INSERT INTO analysis_jobs
            (id, incident_id, attempt_number, status, is_inferred, created_at, error_message)
        SELECT
            gen_random_uuid()::text,
            id,
            1,
            'completed',
            TRUE,
            NOW(),
            NULL
        FROM incidents
        WHERE root_cause IS NOT NULL
          AND id NOT IN (SELECT incident_id FROM analysis_jobs)
    """))

    op.execute(sa.text("""
        INSERT INTO analysis_jobs
            (id, incident_id, attempt_number, status, is_inferred, created_at, error_message)
        SELECT
            gen_random_uuid()::text,
            id,
            1,
            'failed',
            TRUE,
            NOW(),
            'pre-migration: analysis data absent or unverifiable'
        FROM incidents
        WHERE root_cause IS NULL
          AND id NOT IN (SELECT incident_id FROM analysis_jobs)
    """))

    # Sync the cache column to match the inferred jobs
    op.execute(sa.text("""
        UPDATE incidents
        SET analysis_status = 'completed'
        WHERE root_cause IS NOT NULL
    """))

    op.execute(sa.text("""
        UPDATE incidents
        SET analysis_status = 'failed'
        WHERE root_cause IS NULL
    """))


def downgrade() -> None:
    op.drop_index('uix_analysis_jobs_incident_active', table_name='analysis_jobs')
    op.drop_table('analysis_jobs')
    op.drop_column('incidents', 'analysis_error')
    op.drop_column('incidents', 'analysis_status')

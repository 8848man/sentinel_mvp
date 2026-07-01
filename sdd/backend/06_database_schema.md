# 06 — Database Schema

**DB:** PostgreSQL (GCP Cloud SQL, via Alembic migrations)  
**Dev:** SQLite (auto-created from ORM models on startup — no migrations needed)  
**Refs:** → [API Spec](./05_api_spec.md) · [Auth Spec](./07_auth_spec.md)

---

## Design Principles

- All PKs: `UUID DEFAULT gen_random_uuid()`
- All timestamps: `TIMESTAMPTZ` (UTC)
- `user_id` on every table references Supabase `auth.users(id)`
- `incident_code` is human-readable (`INC-YYYY-NNN`); `id` is the internal UUID
- Alembic manages all schema changes for PostgreSQL (`backend/alembic/versions/`)

---

## Table: incidents

```sql
CREATE TABLE incidents (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  incident_code         VARCHAR(20) NOT NULL UNIQUE,
  title                 VARCHAR(255) NOT NULL,
  description           TEXT,
  log_text              TEXT NOT NULL,
  severity              VARCHAR(20) NOT NULL,
  status                VARCHAR(20) NOT NULL DEFAULT 'open',
  components            JSONB NOT NULL DEFAULT '[]',
  root_cause            TEXT,
  confidence            NUMERIC(4,3),
  selected_fix_flow_id  UUID,
  analysis_status       VARCHAR(20) NOT NULL DEFAULT 'pending',
  analysis_error        TEXT,
  origin_type           VARCHAR(50),
  resolved_at           TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

`analysis_status`: `pending` | `processing` | `completed` | `failed` — denormalized cache from latest AIAction.  
`origin_type`: `manual_text` | `ocr_image` | `webhook` | `null` — forward-compat hook for the Origin concept.

---

## Table: incident_sequence

```sql
CREATE TABLE incident_sequence (
  year     SMALLINT PRIMARY KEY,
  next_seq INTEGER NOT NULL DEFAULT 1
);
```

Usage: `SELECT ... FOR UPDATE` on current year row, increment, compose `INC-{year}-{seq:03d}`.

---

## Table: ai_actions

Tracks every AI action request and its result. Replaces the legacy `analysis_jobs` table.

```sql
CREATE TABLE ai_actions (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id           UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
  action_type           VARCHAR(100) NOT NULL DEFAULT 'root_cause_analysis',
  requested_by          VARCHAR(20) NOT NULL DEFAULT 'system',
  status                VARCHAR(20) NOT NULL DEFAULT 'pending',
  attempt_number        INTEGER NOT NULL DEFAULT 1,
  input_snapshot        JSONB,
  output                JSONB,
  output_schema_version VARCHAR(20),
  model_id              VARCHAR(100),
  parent_action_id      UUID REFERENCES ai_actions(id),
  error_message         TEXT,
  started_at            TIMESTAMPTZ,
  completed_at          TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ai_actions_incident_id ON ai_actions(incident_id);
CREATE UNIQUE INDEX uix_ai_actions_incident_active
  ON ai_actions(incident_id)
  WHERE status IN ('pending', 'processing');
```

`requested_by`: `system` | `operator`  
`status`: `pending` | `processing` | `completed` | `failed`  
`input_snapshot`: metadata captured at T1 (char counts, origin_type, similar_incident_count, etc.)  
Partial unique index enforces at most one active action per incident.

---

## Table: timeline_events

```sql
CREATE TABLE timeline_events (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id  UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
  actor_type   VARCHAR(20) NOT NULL DEFAULT 'system',
  event_type   VARCHAR(100),
  event        TEXT NOT NULL,
  ai_action_id UUID REFERENCES ai_actions(id),
  metadata     JSONB,
  occurred_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

`actor_type`: `system` | `operator` | `ai`  
Common `event_type` values: `incident_created`, `ai_action_queued`, `ai_action_completed`, `fix_flow_selected`, `fix_flow_attempted`, `checklist_step_completed`, `incident_resolved`, `incident_reopened`, `incident_closed`

---

## Table: fix_flows

```sql
CREATE TABLE fix_flows (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id      UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
  source_action_id UUID REFERENCES ai_actions(id),
  title            VARCHAR(255) NOT NULL,
  confidence       NUMERIC(4,3) NOT NULL,
  is_attempted     BOOLEAN NOT NULL DEFAULT FALSE,
  generation       SMALLINT NOT NULL DEFAULT 1,
  sort_order       SMALLINT NOT NULL DEFAULT 0,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

`generation`: 1 = initial analysis, N+1 = improved analysis. Old generations are never deleted.  
`source_action_id`: links to the AIAction that produced this flow.

---

## Table: checklist_items

```sql
CREATE TABLE checklist_items (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fix_flow_id  UUID NOT NULL REFERENCES fix_flows(id) ON DELETE CASCADE,
  step_number  SMALLINT NOT NULL,
  description  TEXT NOT NULL,
  is_completed BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

## Table: notes

One note per incident (upsert pattern).

```sql
CREATE TABLE notes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id UUID NOT NULL UNIQUE REFERENCES incidents(id) ON DELETE CASCADE,
  content     TEXT NOT NULL DEFAULT '',
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

## Table: similar_incidents

```sql
CREATE TABLE similar_incidents (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id   UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
  similar_to_id UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
  match_score   NUMERIC(4,3) NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(incident_id, similar_to_id)
);
```

---

## FK: incidents.selected_fix_flow_id

```sql
ALTER TABLE incidents
  ADD CONSTRAINT fk_selected_fix_flow
  FOREIGN KEY (selected_fix_flow_id) REFERENCES fix_flows(id) ON DELETE SET NULL;
```

---

## Migrations

Located at: `backend/alembic/versions/`  
Key migrations in order:
- `a1b2c3d4e5f6_*` — initial schema (incidents, fix_flows, checklist, notes, timeline, similar_incidents)
- `b2c3d4e5f6a7_ai_platform_foundation` — adds ai_actions table; extends incidents, timeline_events, fix_flows

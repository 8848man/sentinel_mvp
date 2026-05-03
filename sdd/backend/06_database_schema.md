# 06 — Database Schema

**DB:** PostgreSQL (GCP Cloud SQL)  
**Refs:** → [API Spec](./05_api_spec.md) · [Auth Spec](./07_auth_spec.md)

---

## Design Principles

- `user_id` on every table references Supabase `auth.users(id)` — RLS can be layered later
- All PKs are `UUID DEFAULT gen_random_uuid()`
- All timestamps are `TIMESTAMPTZ` (UTC)
- Soft delete not used in MVP; resolved incidents transition to `closed` status
- `incident_code` is human-readable (`INC-YYYY-NNN`); `id` is the internal UUID

---

## Enums

```sql
CREATE TYPE severity_level AS ENUM ('critical', 'major', 'minor');
CREATE TYPE incident_status AS ENUM ('open', 'in_progress', 'resolved', 'closed');
```

---

## Table: incidents

```sql
CREATE TABLE incidents (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  incident_code         VARCHAR(20) NOT NULL UNIQUE,  -- INC-2026-043
  title                 VARCHAR(255) NOT NULL,
  description           TEXT,                          -- AI-generated short summary
  log_text              TEXT NOT NULL,                 -- original user-provided log
  severity              severity_level NOT NULL,
  status                incident_status NOT NULL DEFAULT 'open',
  components            TEXT[] NOT NULL DEFAULT '{}',  -- architecture component names
  root_cause            TEXT,                          -- AI-generated
  confidence            NUMERIC(4,3),                  -- 0.000 – 1.000
  selected_fix_flow_id  UUID,                          -- FK set after fix flow chosen
  resolved_at           TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_incidents_user_id ON incidents(user_id);
CREATE INDEX idx_incidents_status  ON incidents(status);
CREATE INDEX idx_incidents_severity ON incidents(severity);
```

---

## Table: incident_sequence

Tracks the per-year auto-increment sequence for `INC-YYYY-NNN` codes.

```sql
CREATE TABLE incident_sequence (
  year    SMALLINT PRIMARY KEY,
  next_seq INTEGER NOT NULL DEFAULT 1
);
```

**Usage:** On incident creation, `SELECT ... FOR UPDATE` on current year row,  
increment `next_seq`, compose `incident_code = 'INC-' || year || '-' || LPAD(seq::text, 3, '0')`.

---

## Table: timeline_events

```sql
CREATE TABLE timeline_events (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id  UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
  event        TEXT NOT NULL,
  occurred_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_timeline_incident_id ON timeline_events(incident_id);
```

**System-generated events (backend writes these automatically):**
- `"Alert triggered"` — on incident creation
- `"AI analysis completed"` — after Gemini response stored
- `"Fix Flow attached: {flow_title}"` — when fix flow selected
- `"Step '{step}' completed"` — when checklist item checked
- `"Incident resolved"` — on Mark as Resolved

---

## Table: fix_flows

```sql
CREATE TABLE fix_flows (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id  UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
  title        VARCHAR(255) NOT NULL,
  confidence   NUMERIC(4,3) NOT NULL,   -- 0.000 – 1.000
  is_attempted BOOLEAN NOT NULL DEFAULT FALSE,
  sort_order   SMALLINT NOT NULL DEFAULT 0,  -- display order (confidence DESC)
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_fix_flows_incident_id ON fix_flows(incident_id);
```

**FK back-reference:**  
`incidents.selected_fix_flow_id` → `fix_flows.id` (set after user selects a flow)  
Add FK after both tables created:

```sql
ALTER TABLE incidents
  ADD CONSTRAINT fk_selected_fix_flow
  FOREIGN KEY (selected_fix_flow_id) REFERENCES fix_flows(id) ON DELETE SET NULL;
```

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

CREATE INDEX idx_checklist_fix_flow_id ON checklist_items(fix_flow_id);
```

---

## Table: notes

One note per incident (upsert pattern).

```sql
CREATE TABLE notes (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id  UUID NOT NULL UNIQUE REFERENCES incidents(id) ON DELETE CASCADE,
  content      TEXT NOT NULL DEFAULT '',
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

**Upsert query (PUT /incidents/{id}/note):**
```sql
INSERT INTO notes (incident_id, content, updated_at)
VALUES ($1, $2, NOW())
ON CONFLICT (incident_id)
DO UPDATE SET content = EXCLUDED.content, updated_at = NOW();
```

---

## Table: similar_incidents

Stores AI-identified similar incidents at analysis time.

```sql
CREATE TABLE similar_incidents (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id        UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
  similar_to_id      UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
  match_score        NUMERIC(4,3) NOT NULL,   -- 0.000 – 1.000
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(incident_id, similar_to_id)
);

CREATE INDEX idx_similar_incident_id ON similar_incidents(incident_id);
```

---

## Updated_at Trigger

Apply to `incidents` and `checklist_items`:

```sql
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_incidents_updated_at
  BEFORE UPDATE ON incidents
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_checklist_updated_at
  BEFORE UPDATE ON checklist_items
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

---

## Computed Field: resolution_time_minutes

Not stored; calculated on query:

```sql
SELECT
  EXTRACT(EPOCH FROM (resolved_at - created_at)) / 60 AS resolution_time_minutes
FROM incidents
WHERE status IN ('resolved', 'closed');
```

---

## Row-Level Security (MVP: disabled; future)

Supabase RLS policies should be added post-MVP to enforce `user_id` ownership  
at the database level. For MVP, ownership is enforced in FastAPI service layer.

---

## Migration File

Located at: `/database/migrations/001_initial_schema.sql`  
Contains all `CREATE TYPE`, `CREATE TABLE`, `ALTER TABLE`, trigger definitions above, in dependency order.

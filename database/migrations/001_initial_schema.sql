-- Sentinel MVP: Initial Schema
-- Apply to: GCP Cloud SQL PostgreSQL 16
-- Depends on: Supabase auth.users table (managed by Supabase)

-- ============================================================
-- ENUMS
-- ============================================================

CREATE TYPE severity_level AS ENUM ('critical', 'major', 'minor');
CREATE TYPE incident_status AS ENUM ('open', 'in_progress', 'resolved', 'closed');

-- ============================================================
-- INCIDENT SEQUENCE (for INC-YYYY-NNN generation)
-- ============================================================

CREATE TABLE incident_sequence (
  year     SMALLINT PRIMARY KEY,
  next_seq INTEGER NOT NULL DEFAULT 1
);

-- ============================================================
-- INCIDENTS
-- ============================================================

CREATE TABLE incidents (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID NOT NULL,  -- references auth.users(id)
  incident_code         VARCHAR(20) NOT NULL UNIQUE,
  title                 VARCHAR(255) NOT NULL,
  description           TEXT,
  log_text              TEXT NOT NULL,
  severity              severity_level NOT NULL,
  status                incident_status NOT NULL DEFAULT 'open',
  components            TEXT[] NOT NULL DEFAULT '{}',
  root_cause            TEXT,
  confidence            NUMERIC(4,3),
  selected_fix_flow_id  UUID,
  resolved_at           TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_incidents_user_id  ON incidents(user_id);
CREATE INDEX idx_incidents_status   ON incidents(status);
CREATE INDEX idx_incidents_severity ON incidents(severity);

-- ============================================================
-- TIMELINE EVENTS
-- ============================================================

CREATE TABLE timeline_events (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id  UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
  event        TEXT NOT NULL,
  occurred_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_timeline_incident_id ON timeline_events(incident_id);

-- ============================================================
-- FIX FLOWS
-- ============================================================

CREATE TABLE fix_flows (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id  UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
  title        VARCHAR(255) NOT NULL,
  confidence   NUMERIC(4,3) NOT NULL,
  is_attempted BOOLEAN NOT NULL DEFAULT FALSE,
  sort_order   SMALLINT NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_fix_flows_incident_id ON fix_flows(incident_id);

-- FK from incidents to fix_flows (after fix_flows table created)
ALTER TABLE incidents
  ADD CONSTRAINT fk_selected_fix_flow
  FOREIGN KEY (selected_fix_flow_id) REFERENCES fix_flows(id) ON DELETE SET NULL;

-- ============================================================
-- CHECKLIST ITEMS
-- ============================================================

CREATE TABLE checklist_items (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fix_flow_id  UUID NOT NULL REFERENCES fix_flows(id) ON DELETE CASCADE,
  step_number  SMALLINT NOT NULL,
  description  TEXT NOT NULL,
  is_completed BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_checklist_fix_flow_id ON checklist_items(fix_flow_id);

-- ============================================================
-- NOTES (one per incident)
-- ============================================================

CREATE TABLE notes (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id  UUID NOT NULL UNIQUE REFERENCES incidents(id) ON DELETE CASCADE,
  content      TEXT NOT NULL DEFAULT '',
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- SIMILAR INCIDENTS
-- ============================================================

CREATE TABLE similar_incidents (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id     UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
  similar_to_id   UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
  match_score     NUMERIC(4,3) NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(incident_id, similar_to_id)
);

CREATE INDEX idx_similar_incident_id ON similar_incidents(incident_id);

-- ============================================================
-- UPDATED_AT TRIGGER
-- ============================================================

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

CREATE TRIGGER trg_notes_updated_at
  BEFORE UPDATE ON notes
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

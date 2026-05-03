-- Sentinel Dev Seed Data
-- Run after 001_initial_schema.sql
-- Requires a real Supabase user UUID — replace 'YOUR-USER-UUID' before running.

DO $$
DECLARE
  v_user_id UUID := 'YOUR-USER-UUID';
  v_inc1_id UUID := gen_random_uuid();
  v_inc2_id UUID := gen_random_uuid();
  v_inc3_id UUID := gen_random_uuid();
  v_flow1_id UUID := gen_random_uuid();
  v_flow2_id UUID := gen_random_uuid();
BEGIN

-- Sequence
INSERT INTO incident_sequence (year, next_seq) VALUES (2026, 45) ON CONFLICT DO NOTHING;

-- Incident 1: Critical / Open
INSERT INTO incidents (id, user_id, incident_code, title, description, log_text, severity, status, components, root_cause, confidence)
VALUES (
  v_inc1_id, v_user_id, 'INC-2026-041',
  'DB Connection Pool Exhausted',
  'Primary database is rejecting new connections.',
  'ERROR: FATAL: remaining connection slots are reserved for replication super-user connections',
  'critical', 'open',
  ARRAY['AWS EKS', 'PostgreSQL', 'Redis', 'Spring Boot'],
  'Database connection leak caused by unreleased sessions.',
  0.87
);

-- Incident 2: Major / In Progress
INSERT INTO incidents (id, user_id, incident_code, title, description, log_text, severity, status, components, root_cause, confidence)
VALUES (
  v_inc2_id, v_user_id, 'INC-2026-042',
  'Auth Service Latency Spike',
  'Token validation p99 exceeding 2s.',
  'WARN: JWT validation timeout after 2000ms for user authentication requests',
  'major', 'in_progress',
  ARRAY['Spring Boot', 'Redis'],
  'Redis cache miss causing repeated DB lookups during token validation.',
  0.79
);

-- Incident 3: Minor / Resolved
INSERT INTO incidents (id, user_id, incident_code, title, description, log_text, severity, status, components, root_cause, confidence, resolved_at)
VALUES (
  v_inc3_id, v_user_id, 'INC-2026-040',
  'Scheduled Job Queue Backlog',
  'Worker scaling resolved backlog.',
  'ERROR: Job queue depth exceeded threshold: 1842 pending jobs',
  'minor', 'resolved',
  ARRAY['AWS EKS', 'PostgreSQL'],
  'Insufficient worker replicas during traffic peak.',
  0.91,
  NOW() - INTERVAL '23 minutes'
);

-- Fix flow for INC-2026-041
INSERT INTO fix_flows (id, incident_id, title, confidence, sort_order) VALUES
  (v_flow1_id, v_inc1_id, 'Identify top connection consumers', 0.96, 0),
  (v_flow2_id, v_inc1_id, 'Restart affected application pods', 0.91, 1);

-- Checklist items
INSERT INTO checklist_items (fix_flow_id, step_number, description, is_completed) VALUES
  (v_flow1_id, 1, 'Confirm affected service scope', true),
  (v_flow1_id, 2, 'Restart overloaded instances', false),
  (v_flow1_id, 3, 'Validate error rate normalization', false),
  (v_flow1_id, 4, 'Final resolution confirmation', false),
  (v_flow2_id, 1, 'Identify pods with high connection count', false),
  (v_flow2_id, 2, 'Perform rolling restart', false),
  (v_flow2_id, 3, 'Monitor connection pool after restart', false);

-- Timeline events
INSERT INTO timeline_events (incident_id, event, occurred_at) VALUES
  (v_inc1_id, 'Alert triggered', NOW() - INTERVAL '30 minutes'),
  (v_inc1_id, 'AI analysis completed', NOW() - INTERVAL '27 minutes'),
  (v_inc1_id, 'Fix Flow attached: Identify top connection consumers', NOW() - INTERVAL '26 minutes');

END $$;

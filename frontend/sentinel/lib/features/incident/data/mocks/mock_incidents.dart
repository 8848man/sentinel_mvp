import '../models/incident_model.dart';
import '../models/fix_flow_model.dart';
import '../models/checklist_item_model.dart';
import '../models/timeline_event_model.dart';
import '../models/similar_incident_model.dart';
import '../models/note_model.dart';

// Realistic mock incident data matching API spec shapes from 05_api_spec.md.
// These act as the executable version of the API contract for frontend testing.

final kMockIncidents = <IncidentModel>[
  // ── INC-2026-041 · Critical · open ──────────────────────────────────────
  IncidentModel(
    id: 'mock-inc-001',
    incidentCode: 'INC-2026-041',
    title: 'PostgreSQL Connection Pool Exhaustion',
    description: 'Primary database is rejecting new connections due to pool exhaustion.',
    logText: 'FATAL: remaining connection slots are reserved for non-replication superuser connections\n'
        'ERROR: connection to server at "db.internal" failed: FATAL: sorry, too many clients already\n'
        'WARN: HikariPool-1 - Connection is not available, request timed out after 30000ms',
    severity: 'critical',
    status: 'open',
    components: ['AWS EKS', 'PostgreSQL', 'Spring Boot', 'HikariCP'],
    rootCause: 'Database connection leak caused by unreleased sessions in the auth service after JWT validation failures.',
    confidence: 0.87,
    selectedFixFlowId: null,
    resolvedAt: null,
    createdAt: DateTime.parse('2026-04-29T14:18:00Z'),
    updatedAt: DateTime.parse('2026-04-29T14:18:00Z'),
    fixFlows: [
      FixFlowModel(
        id: 'mock-ff-001',
        title: 'Identify top connection consumers',
        confidence: 0.96,
        isAttempted: false,
        checklistItems: [
          ChecklistItemModel(id: 'mock-ci-001', stepNumber: 1, description: 'Run SELECT count(*), usename FROM pg_stat_activity GROUP BY usename to find top consumers', isCompleted: false, updatedAt: DateTime.parse('2026-04-29T14:18:00Z')),
          ChecklistItemModel(id: 'mock-ci-002', stepNumber: 2, description: 'Identify auth-service pod using highest connection count via kubectl top pods', isCompleted: false, updatedAt: DateTime.parse('2026-04-29T14:18:00Z')),
          ChecklistItemModel(id: 'mock-ci-003', stepNumber: 3, description: 'Restart overloaded auth-service pods to release leaked connections', isCompleted: false, updatedAt: DateTime.parse('2026-04-29T14:18:00Z')),
        ],
      ),
      FixFlowModel(
        id: 'mock-ff-002',
        title: 'Adjust connection pool limits',
        confidence: 0.74,
        isAttempted: false,
        checklistItems: [
          ChecklistItemModel(id: 'mock-ci-004', stepNumber: 1, description: 'Review current HikariCP maximumPoolSize setting in application.yaml', isCompleted: false, updatedAt: DateTime.parse('2026-04-29T14:18:00Z')),
          ChecklistItemModel(id: 'mock-ci-005', stepNumber: 2, description: 'Lower maximumPoolSize from 20 to 10 per instance to stay within PostgreSQL max_connections', isCompleted: false, updatedAt: DateTime.parse('2026-04-29T14:18:00Z')),
        ],
      ),
    ],
    similarIncidents: [
      SimilarIncidentModel(incidentId: 'mock-inc-004', incidentCode: 'INC-2026-017', matchScore: 0.92),
    ],
    timeline: [
      TimelineEventModel(id: 'mock-te-001', event: 'Alert triggered', occurredAt: DateTime.parse('2026-04-29T14:18:00Z')),
      TimelineEventModel(id: 'mock-te-002', event: 'AI analysis completed', occurredAt: DateTime.parse('2026-04-29T14:21:00Z')),
    ],
    note: null,
  ),

  // ── INC-2026-042 · Major · in_progress ──────────────────────────────────
  IncidentModel(
    id: 'mock-inc-002',
    incidentCode: 'INC-2026-042',
    title: 'Redis Cache Cluster Timeout Spike',
    description: 'Session cache returning ETIMEDOUT errors, causing elevated API latency.',
    logText: 'Error: connect ETIMEDOUT 10.0.1.45:6379\n'
        'RedisCommandTimeoutException: Command timed out after 1 second(s): GET session:abc123\n'
        'WARN: Cache miss rate elevated to 78%, falling back to DB for all session reads',
    severity: 'major',
    status: 'in_progress',
    components: ['Redis', 'API Gateway', 'Session Service'],
    rootCause: 'Redis primary node under memory pressure; eviction policy (allkeys-lru) evicting active sessions.',
    confidence: 0.81,
    selectedFixFlowId: 'mock-ff-003',
    resolvedAt: null,
    createdAt: DateTime.parse('2026-04-29T11:05:00Z'),
    updatedAt: DateTime.parse('2026-04-29T13:40:00Z'),
    fixFlows: [
      FixFlowModel(
        id: 'mock-ff-003',
        title: 'Scale Redis memory and flush expired keys',
        confidence: 0.81,
        isAttempted: true,
        checklistItems: [
          ChecklistItemModel(id: 'mock-ci-006', stepNumber: 1, description: 'Check Redis memory usage via redis-cli INFO memory', isCompleted: true, updatedAt: DateTime.parse('2026-04-29T13:00:00Z')),
          ChecklistItemModel(id: 'mock-ci-007', stepNumber: 2, description: 'Run FLUSHDB on expired session keyspace (non-prod) or set lower TTL', isCompleted: true, updatedAt: DateTime.parse('2026-04-29T13:20:00Z')),
          ChecklistItemModel(id: 'mock-ci-008', stepNumber: 3, description: 'Scale Redis node from r6g.large to r6g.xlarge via AWS console', isCompleted: false, updatedAt: DateTime.parse('2026-04-29T13:40:00Z')),
        ],
      ),
      FixFlowModel(
        id: 'mock-ff-004',
        title: 'Switch eviction policy to volatile-lru',
        confidence: 0.62,
        isAttempted: false,
        checklistItems: [
          ChecklistItemModel(id: 'mock-ci-009', stepNumber: 1, description: 'Set maxmemory-policy to volatile-lru in Redis config', isCompleted: false, updatedAt: DateTime.parse('2026-04-29T11:05:00Z')),
          ChecklistItemModel(id: 'mock-ci-010', stepNumber: 2, description: 'Ensure all session keys have TTL set (verify with redis-cli OBJECT ENCODING)', isCompleted: false, updatedAt: DateTime.parse('2026-04-29T11:05:00Z')),
        ],
      ),
    ],
    similarIncidents: [
      SimilarIncidentModel(incidentId: 'mock-inc-005', incidentCode: 'INC-2026-009', matchScore: 0.85),
    ],
    timeline: [
      TimelineEventModel(id: 'mock-te-003', event: 'Alert triggered', occurredAt: DateTime.parse('2026-04-29T11:05:00Z')),
      TimelineEventModel(id: 'mock-te-004', event: 'AI analysis completed', occurredAt: DateTime.parse('2026-04-29T11:08:00Z')),
      TimelineEventModel(id: 'mock-te-005', event: 'Fix Flow attached: Scale Redis memory and flush expired keys', occurredAt: DateTime.parse('2026-04-29T11:12:00Z')),
      TimelineEventModel(id: 'mock-te-006', event: "Step 'Check Redis memory usage via redis-cli INFO memory' completed", occurredAt: DateTime.parse('2026-04-29T13:00:00Z')),
      TimelineEventModel(id: 'mock-te-007', event: "Step 'Run FLUSHDB on expired session keyspace' completed", occurredAt: DateTime.parse('2026-04-29T13:20:00Z')),
    ],
    note: NoteModel(
      id: 'mock-note-002',
      incidentId: 'mock-inc-002',
      content: 'Memory usage was at 94%. Flushed ~180K expired keys. Waiting for node scale-up to complete.',
      updatedAt: DateTime.parse('2026-04-29T13:40:00Z'),
    ),
  ),

  // ── INC-2026-043 · Minor · open ─────────────────────────────────────────
  IncidentModel(
    id: 'mock-inc-003',
    incidentCode: 'INC-2026-043',
    title: 'Scheduled Job Queue Backlog',
    description: 'Nightly report generation jobs accumulating in queue; no consumer failures detected.',
    logText: 'WARN: Job queue depth: 2341 (threshold: 500)\n'
        'INFO: Worker pool utilization: 100% (8/8 workers busy)\n'
        'WARN: Job ID job-8821 waiting for 14m 32s (SLA: 5m)',
    severity: 'minor',
    status: 'open',
    components: ['Job Scheduler', 'Worker Pool', 'S3'],
    rootCause: 'Worker pool under-provisioned for end-of-month report volume spike. Expected quarterly pattern.',
    confidence: 0.73,
    selectedFixFlowId: null,
    resolvedAt: null,
    createdAt: DateTime.parse('2026-04-29T02:00:00Z'),
    updatedAt: DateTime.parse('2026-04-29T02:00:00Z'),
    fixFlows: [
      FixFlowModel(
        id: 'mock-ff-005',
        title: 'Scale worker pool temporarily',
        confidence: 0.73,
        isAttempted: false,
        checklistItems: [
          ChecklistItemModel(id: 'mock-ci-011', stepNumber: 1, description: 'Increase worker replicas from 8 to 24 via kubectl scale deployment job-workers', isCompleted: false, updatedAt: DateTime.parse('2026-04-29T02:00:00Z')),
          ChecklistItemModel(id: 'mock-ci-012', stepNumber: 2, description: 'Monitor queue depth every 5 minutes until below 100', isCompleted: false, updatedAt: DateTime.parse('2026-04-29T02:00:00Z')),
          ChecklistItemModel(id: 'mock-ci-013', stepNumber: 3, description: 'Scale back to 8 workers once queue is cleared', isCompleted: false, updatedAt: DateTime.parse('2026-04-29T02:00:00Z')),
        ],
      ),
    ],
    similarIncidents: [],
    timeline: [
      TimelineEventModel(id: 'mock-te-008', event: 'Alert triggered', occurredAt: DateTime.parse('2026-04-29T02:00:00Z')),
      TimelineEventModel(id: 'mock-te-009', event: 'AI analysis completed', occurredAt: DateTime.parse('2026-04-29T02:03:00Z')),
    ],
    note: null,
  ),

  // ── INC-2026-040 · Minor · closed (archive) ──────────────────────────────
  IncidentModel(
    id: 'mock-inc-004',
    incidentCode: 'INC-2026-040',
    title: 'Auth Service Memory Leak',
    description: 'Auth service pods restarting every 2 hours due to OOMKilled events.',
    logText: 'OOMKilled: auth-service pod auth-service-77c8f9d6b-xk2p9 killed\n'
        'container auth-service exceeded memory limit of 512Mi',
    severity: 'minor',
    status: 'closed',
    components: ['Auth Service', 'AWS EKS'],
    rootCause: 'Unbounded in-memory token blacklist growing indefinitely. Fixed by adding TTL-based eviction.',
    confidence: 0.94,
    selectedFixFlowId: 'mock-ff-006',
    resolvedAt: DateTime.parse('2026-04-28T16:45:00Z'),
    createdAt: DateTime.parse('2026-04-28T14:22:00Z'),
    updatedAt: DateTime.parse('2026-04-28T16:45:00Z'),
    fixFlows: [
      FixFlowModel(
        id: 'mock-ff-006',
        title: 'Add TTL eviction to token blacklist',
        confidence: 0.94,
        isAttempted: true,
        checklistItems: [
          ChecklistItemModel(id: 'mock-ci-014', stepNumber: 1, description: 'Profile heap dump from OOMKilled pod to confirm blacklist growth', isCompleted: true, updatedAt: DateTime.parse('2026-04-28T15:00:00Z')),
          ChecklistItemModel(id: 'mock-ci-015', stepNumber: 2, description: 'Add 24h TTL to token blacklist entries in auth service code', isCompleted: true, updatedAt: DateTime.parse('2026-04-28T16:00:00Z')),
          ChecklistItemModel(id: 'mock-ci-016', stepNumber: 3, description: 'Deploy patched auth service and verify no OOMKilled events for 30 minutes', isCompleted: true, updatedAt: DateTime.parse('2026-04-28T16:45:00Z')),
        ],
      ),
    ],
    similarIncidents: [],
    timeline: [
      TimelineEventModel(id: 'mock-te-010', event: 'Alert triggered', occurredAt: DateTime.parse('2026-04-28T14:22:00Z')),
      TimelineEventModel(id: 'mock-te-011', event: 'AI analysis completed', occurredAt: DateTime.parse('2026-04-28T14:25:00Z')),
      TimelineEventModel(id: 'mock-te-012', event: 'Fix Flow attached: Add TTL eviction to token blacklist', occurredAt: DateTime.parse('2026-04-28T15:10:00Z')),
      TimelineEventModel(id: 'mock-te-013', event: 'Incident resolved', occurredAt: DateTime.parse('2026-04-28T16:45:00Z')),
    ],
    note: NoteModel(
      id: 'mock-note-004',
      incidentId: 'mock-inc-004',
      content: 'Root cause confirmed via heap dump. Patched and deployed v2.4.1. No recurrence in 24h monitoring window.',
      updatedAt: DateTime.parse('2026-04-28T16:45:00Z'),
    ),
  ),

  // ── INC-2026-039 · Major · resolved (archive) ────────────────────────────
  IncidentModel(
    id: 'mock-inc-005',
    incidentCode: 'INC-2026-039',
    title: 'API Gateway 502 Bad Gateway Spike',
    description: '15% of API requests returning 502 during peak hours.',
    logText: '502 Bad Gateway\nupstream connect error or disconnect/reset before headers. reset reason: connection timeout',
    severity: 'major',
    status: 'resolved',
    components: ['API Gateway', 'Nginx', 'Backend Services'],
    rootCause: 'Nginx upstream keepalive timeout shorter than backend service keepalive, causing race condition.',
    confidence: 0.89,
    selectedFixFlowId: 'mock-ff-007',
    resolvedAt: DateTime.parse('2026-04-27T09:15:00Z'),
    createdAt: DateTime.parse('2026-04-27T07:30:00Z'),
    updatedAt: DateTime.parse('2026-04-27T09:15:00Z'),
    fixFlows: [
      FixFlowModel(
        id: 'mock-ff-007',
        title: 'Align Nginx and upstream keepalive timeouts',
        confidence: 0.89,
        isAttempted: true,
        checklistItems: [
          ChecklistItemModel(id: 'mock-ci-017', stepNumber: 1, description: 'Set keepalive_timeout 65s in nginx.conf (upstream default is 75s)', isCompleted: true, updatedAt: DateTime.parse('2026-04-27T08:10:00Z')),
          ChecklistItemModel(id: 'mock-ci-018', stepNumber: 2, description: 'Reload Nginx config and monitor 502 rate for 10 minutes', isCompleted: true, updatedAt: DateTime.parse('2026-04-27T09:15:00Z')),
        ],
      ),
    ],
    similarIncidents: [],
    timeline: [
      TimelineEventModel(id: 'mock-te-014', event: 'Alert triggered', occurredAt: DateTime.parse('2026-04-27T07:30:00Z')),
      TimelineEventModel(id: 'mock-te-015', event: 'AI analysis completed', occurredAt: DateTime.parse('2026-04-27T07:33:00Z')),
      TimelineEventModel(id: 'mock-te-016', event: 'Incident resolved', occurredAt: DateTime.parse('2026-04-27T09:15:00Z')),
    ],
    note: NoteModel(
      id: 'mock-note-005',
      incidentId: 'mock-inc-005',
      content: '502 rate dropped to 0% within 2 minutes of Nginx reload.',
      updatedAt: DateTime.parse('2026-04-27T09:15:00Z'),
    ),
  ),
];

// Convenience getters
List<IncidentModel> get kActiveIncidents =>
    kMockIncidents.where((i) => i.status != 'closed').toList();

List<IncidentModel> get kArchiveIncidents =>
    kMockIncidents.where((i) => i.status == 'resolved' || i.status == 'closed').toList();

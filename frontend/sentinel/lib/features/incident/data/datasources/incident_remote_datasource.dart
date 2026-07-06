import 'dart:typed_data';

import '../mocks/mock_incidents.dart';
import '../models/incident_metadata_model.dart';
import '../models/incident_model.dart';
import '../models/fix_flow_model.dart';
import '../models/checklist_item_model.dart';
import '../models/timeline_event_model.dart';
import '../models/note_model.dart';
import '../models/ocr_extraction_result_model.dart';
import 'incident_datasource.dart';

class IncidentRemoteDatasource implements IncidentDatasource {
  // In-memory mutable copy so UI mutations (checklist, notes, resolve) persist
  // within a single app session.
  final List<IncidentModel> _store = List.of(kMockIncidents);

  // ── POST /ocr/extract-log ────────────────────────────────────────────────────

  Future<OcrExtractionResultModel> extractLogFromImage(
    Uint8List imageBytes,
    String filename,
  ) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    return OcrExtractionResultModel.fromJson({
      'ocr_status': 'ok',
      'ocr_text': '[mock] ERROR: connection refused at 10:42:03 — '
          'mock OCR output for "$filename" (${imageBytes.length} bytes)',
      'cleaned_text': '[mock] ERROR: connection refused at 10:42:03',
      'cleanup_status': 'ok',
      'warnings': <String>[],
    });
  }

  // ── POST /incidents/analyze-metadata ──────────────────────────────────────

  Future<IncidentMetadataModel> analyzeMetadata(String rawLog) async {
    await Future.delayed(const Duration(milliseconds: 900));

    final lower = rawLog.toLowerCase();
    final severity = lower.contains('fatal') || lower.contains('critical') || lower.contains('oom')
        ? 'critical'
        : lower.contains('error') || lower.contains('exception') || lower.contains('timeout')
            ? 'major'
            : 'minor';

    final nextSeq = _store.length + 44;
    final suggestedCode = 'INC-2026-0$nextSeq';

    final components = <String>[];
    if (lower.contains('postgres') || lower.contains('pg_')) components.add('PostgreSQL');
    if (lower.contains('redis')) components.add('Redis');
    if (lower.contains('nginx') || lower.contains('gateway')) components.add('API Gateway');
    if (lower.contains('eks') || lower.contains('pod') || lower.contains('kubectl')) components.add('AWS EKS');
    if (lower.contains('spring') || lower.contains('hikari')) components.add('Spring Boot');
    if (components.isEmpty) components.addAll(['API Gateway', 'Backend Service']);

    return IncidentMetadataModel(
      suggestedId: suggestedCode,
      suggestedTitle: _deriveTitle(lower, severity),
      suggestedSeverity: severity,
      detectedComponents: components,
    );
  }

  String _deriveTitle(String lower, String severity) {
    if (lower.contains('connection') && lower.contains('pool')) return 'Connection Pool Exhaustion';
    if (lower.contains('redis') && lower.contains('timeout')) return 'Redis Cache Timeout Spike';
    if (lower.contains('oom') || lower.contains('memory')) return 'Service Memory Exhaustion';
    if (lower.contains('502') || lower.contains('bad gateway')) return 'API Gateway 502 Spike';
    if (lower.contains('queue') || lower.contains('backlog')) return 'Job Queue Backlog';
    return severity == 'critical' ? 'Critical Service Degradation' : 'Service Degradation Detected';
  }

  // ── POST /incidents ────────────────────────────────────────────────────────

  Future<IncidentModel> createIncident({
    required String logText,
    required String title,
    required String severity,
    required List<String> components,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));

    final id = 'mock-inc-${DateTime.now().millisecondsSinceEpoch}';
    final code = 'INC-2026-0${_store.length + 44}';
    final now = DateTime.now().toUtc();

    final incident = IncidentModel(
      id: id,
      incidentCode: code,
      title: title,
      description: 'AI-generated summary for $title.',
      logText: logText,
      severity: severity,
      status: 'open',
      components: components,
      rootCause: 'Root cause identified from log pattern analysis.',
      confidence: 0.82,
      selectedFixFlowId: null,
      resolvedAt: null,
      createdAt: now,
      updatedAt: now,
      fixFlows: [
        FixFlowModel(
          id: 'mock-ff-new-1',
          title: 'Isolate and restart affected services',
          confidence: 0.82,
          isAttempted: false,
          checklistItems: [
            ChecklistItemModel(id: 'mock-ci-new-1', stepNumber: 1, description: 'Confirm affected service scope', isCompleted: false, updatedAt: now),
            ChecklistItemModel(id: 'mock-ci-new-2', stepNumber: 2, description: 'Restart overloaded instances', isCompleted: false, updatedAt: now),
            ChecklistItemModel(id: 'mock-ci-new-3', stepNumber: 3, description: 'Verify service health after restart', isCompleted: false, updatedAt: now),
          ],
        ),
        FixFlowModel(
          id: 'mock-ff-new-2',
          title: 'Review and adjust resource limits',
          confidence: 0.65,
          isAttempted: false,
          checklistItems: [
            ChecklistItemModel(id: 'mock-ci-new-4', stepNumber: 1, description: 'Review current resource utilization metrics', isCompleted: false, updatedAt: now),
            ChecklistItemModel(id: 'mock-ci-new-5', stepNumber: 2, description: 'Adjust limits and redeploy affected services', isCompleted: false, updatedAt: now),
          ],
        ),
      ],
      similarIncidents: [],
      timeline: [
        TimelineEventModel(id: 'mock-te-new-1', event: 'Alert triggered', occurredAt: now),
        TimelineEventModel(id: 'mock-te-new-2', event: 'AI analysis completed', occurredAt: now.add(const Duration(seconds: 3))),
      ],
      note: null,
    );

    _store.add(incident);
    return incident;
  }

  // ── GET /incidents ─────────────────────────────────────────────────────────

  Future<List<IncidentModel>> getIncidents({String? status}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final active = _store.where((i) => i.status != 'closed').toList();
    if (status != null) return active.where((i) => i.status == status).toList();
    return active;
  }

  // ── GET /incidents/{id} ────────────────────────────────────────────────────

  Future<IncidentModel> getIncidentDetail(String id) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final incident = _store.where((i) => i.id == id).firstOrNull;
    if (incident == null) throw Exception('Incident not found: $id');
    return incident;
  }

  // ── PATCH /incidents/{id} ──────────────────────────────────────────────────

  Future<IncidentModel> patchIncident(String id, {
    String? selectedFixFlowId,
    String? status,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final idx = _store.indexWhere((i) => i.id == id);
    if (idx == -1) throw Exception('Incident not found: $id');

    final old = _store[idx];
    final now = DateTime.now().toUtc();

    final newTimeline = List<TimelineEventModel>.from(old.timeline);
    if (selectedFixFlowId != null && old.selectedFixFlowId != selectedFixFlowId) {
      final flow = old.fixFlows.where((f) => f.id == selectedFixFlowId).firstOrNull;
      if (flow != null) {
        newTimeline.add(TimelineEventModel(
          id: 'mock-te-patch-${now.millisecondsSinceEpoch}',
          event: 'Fix Flow attached: ${flow.title}',
          occurredAt: now,
        ));
      }
    }

    final updated = IncidentModel(
      id: old.id,
      incidentCode: old.incidentCode,
      title: old.title,
      description: old.description,
      logText: old.logText,
      severity: old.severity,
      status: status ?? old.status,
      components: old.components,
      rootCause: old.rootCause,
      confidence: old.confidence,
      selectedFixFlowId: selectedFixFlowId ?? old.selectedFixFlowId,
      resolvedAt: old.resolvedAt,
      createdAt: old.createdAt,
      updatedAt: now,
      fixFlows: old.fixFlows,
      similarIncidents: old.similarIncidents,
      timeline: newTimeline,
      note: old.note,
    );

    _store[idx] = updated;
    return updated;
  }

  // ── PATCH /incidents/{id}/resolve ──────────────────────────────────────────

  Future<IncidentModel> resolveIncident(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final idx = _store.indexWhere((i) => i.id == id);
    if (idx == -1) throw Exception('Incident not found: $id');

    final old = _store[idx];
    final now = DateTime.now().toUtc();
    final newTimeline = List<TimelineEventModel>.from(old.timeline)
      ..add(TimelineEventModel(
        id: 'mock-te-resolve-${now.millisecondsSinceEpoch}',
        event: 'Incident resolved',
        occurredAt: now,
      ));

    final updated = IncidentModel(
      id: old.id,
      incidentCode: old.incidentCode,
      title: old.title,
      description: old.description,
      logText: old.logText,
      severity: old.severity,
      status: 'resolved',
      components: old.components,
      rootCause: old.rootCause,
      confidence: old.confidence,
      selectedFixFlowId: old.selectedFixFlowId,
      resolvedAt: now,
      createdAt: old.createdAt,
      updatedAt: now,
      fixFlows: old.fixFlows,
      similarIncidents: old.similarIncidents,
      timeline: newTimeline,
      note: old.note,
    );

    _store[idx] = updated;
    return updated;
  }

  // ── PATCH /incidents/{id}/close ───────────────────────────────────────────

  Future<IncidentModel> closeIncident(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final idx = _store.indexWhere((i) => i.id == id);
    if (idx == -1) throw Exception('Incident not found: $id');

    final old = _store[idx];
    final now = DateTime.now().toUtc();
    final newTimeline = List<TimelineEventModel>.from(old.timeline)
      ..add(TimelineEventModel(
        id: 'mock-te-close-${now.millisecondsSinceEpoch}',
        event: 'Incident closed',
        occurredAt: now,
      ));

    final updated = IncidentModel(
      id: old.id,
      incidentCode: old.incidentCode,
      title: old.title,
      description: old.description,
      logText: old.logText,
      severity: old.severity,
      status: 'closed',
      components: old.components,
      rootCause: old.rootCause,
      confidence: old.confidence,
      selectedFixFlowId: old.selectedFixFlowId,
      resolvedAt: old.resolvedAt,
      createdAt: old.createdAt,
      updatedAt: now,
      fixFlows: old.fixFlows,
      similarIncidents: old.similarIncidents,
      timeline: newTimeline,
      note: old.note,
    );

    _store[idx] = updated;
    return updated;
  }

  // ── PATCH /checklist/{item_id} ─────────────────────────────────────────────

  Future<ChecklistItemModel> updateChecklistItem(
      String itemId, {required bool isCompleted}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final now = DateTime.now().toUtc();

    for (var i = 0; i < _store.length; i++) {
      final incident = _store[i];
      for (var fi = 0; fi < incident.fixFlows.length; fi++) {
        final flow = incident.fixFlows[fi];
        final ciIdx = flow.checklistItems.indexWhere((c) => c.id == itemId);
        if (ciIdx == -1) continue;

        final oldItem = flow.checklistItems[ciIdx];
        final updatedItem = ChecklistItemModel(
          id: oldItem.id,
          stepNumber: oldItem.stepNumber,
          description: oldItem.description,
          isCompleted: isCompleted,
          updatedAt: now,
        );

        final newItems = List<ChecklistItemModel>.from(flow.checklistItems);
        newItems[ciIdx] = updatedItem;

        final updatedFlow = FixFlowModel(
          id: flow.id,
          title: flow.title,
          confidence: flow.confidence,
          isAttempted: flow.isAttempted,
          checklistItems: newItems,
        );

        final newFlows = List<FixFlowModel>.from(incident.fixFlows);
        newFlows[fi] = updatedFlow;

        // Append timeline event when completing a step
        final newTimeline = List<TimelineEventModel>.from(incident.timeline);
        if (isCompleted) {
          newTimeline.add(TimelineEventModel(
            id: 'mock-te-ci-${now.millisecondsSinceEpoch}',
            event: "Step '${oldItem.description}' completed",
            occurredAt: now,
          ));
        }

        _store[i] = IncidentModel(
          id: incident.id,
          incidentCode: incident.incidentCode,
          title: incident.title,
          description: incident.description,
          logText: incident.logText,
          severity: incident.severity,
          status: incident.status,
          components: incident.components,
          rootCause: incident.rootCause,
          confidence: incident.confidence,
          selectedFixFlowId: incident.selectedFixFlowId,
          resolvedAt: incident.resolvedAt,
          createdAt: incident.createdAt,
          updatedAt: now,
          fixFlows: newFlows,
          similarIncidents: incident.similarIncidents,
          timeline: newTimeline,
          note: incident.note,
        );

        return updatedItem;
      }
    }

    throw Exception('Checklist item not found: $itemId');
  }

  // ── PUT /incidents/{id}/note ───────────────────────────────────────────────

  Future<NoteModel> saveNote(String incidentId, String content) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final idx = _store.indexWhere((i) => i.id == incidentId);
    if (idx == -1) throw Exception('Incident not found: $incidentId');

    final old = _store[idx];
    final now = DateTime.now().toUtc();
    final noteId = old.note?.id ?? 'mock-note-${now.millisecondsSinceEpoch}';

    final note = NoteModel(
      id: noteId,
      incidentId: incidentId,
      content: content,
      updatedAt: now,
    );

    _store[idx] = IncidentModel(
      id: old.id,
      incidentCode: old.incidentCode,
      title: old.title,
      description: old.description,
      logText: old.logText,
      severity: old.severity,
      status: old.status,
      components: old.components,
      rootCause: old.rootCause,
      confidence: old.confidence,
      selectedFixFlowId: old.selectedFixFlowId,
      resolvedAt: old.resolvedAt,
      createdAt: old.createdAt,
      updatedAt: now,
      fixFlows: old.fixFlows,
      similarIncidents: old.similarIncidents,
      timeline: old.timeline,
      note: note,
    );

    return note;
  }

  // ── GET /archive ───────────────────────────────────────────────────────────

  Future<List<IncidentModel>> getArchiveIncidents() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _store.where((i) => i.status == 'closed').toList();
  }
}

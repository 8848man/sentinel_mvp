import '../../domain/entities/incident.dart';
import 'fix_flow_model.dart';
import 'similar_incident_model.dart';
import 'timeline_event_model.dart';
import 'note_model.dart';

class IncidentModel {
  const IncidentModel({
    required this.id,
    required this.incidentCode,
    required this.title,
    this.description,
    required this.logText,
    required this.severity,
    required this.status,
    required this.components,
    this.rootCause,
    this.confidence,
    this.selectedFixFlowId,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
    this.fixFlows = const [],
    this.similarIncidents = const [],
    this.timeline = const [],
    this.note,
  });

  final String id;
  final String incidentCode;
  final String title;
  final String? description;
  final String logText;
  final String severity;
  final String status;
  final List<String> components;
  final String? rootCause;
  final double? confidence;
  final String? selectedFixFlowId;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<FixFlowModel> fixFlows;
  final List<SimilarIncidentModel> similarIncidents;
  final List<TimelineEventModel> timeline;
  final NoteModel? note;

  factory IncidentModel.fromJson(Map<String, dynamic> json) {
    return IncidentModel(
      id: json['id'] as String,
      incidentCode: json['incident_code'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      logText: json['log_text'] as String? ?? '',
      severity: json['severity'] as String,
      status: json['status'] as String,
      components: (json['components'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      rootCause: json['root_cause'] as String?,
      confidence: json['confidence'] != null
          ? (json['confidence'] as num).toDouble()
          : null,
      selectedFixFlowId: json['selected_fix_flow_id'] as String?,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.tryParse(json['resolved_at'] as String? ?? '') ??
          DateTime.utc(2026),
      updatedAt: DateTime.tryParse(
              (json['updated_at'] ?? json['created_at'] ?? json['resolved_at'])
                  as String? ??
                  '') ??
          DateTime.utc(2026),
      fixFlows: (json['fix_flows'] as List<dynamic>?)
              ?.map((e) => FixFlowModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      similarIncidents: (json['similar_incidents'] as List<dynamic>?)
              ?.map((e) =>
                  SimilarIncidentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      timeline: (json['timeline'] as List<dynamic>?)
              ?.map((e) =>
                  TimelineEventModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      note: json['note'] != null
          ? NoteModel.fromJson(json['note'] as Map<String, dynamic>)
          : null,
    );
  }

  Incident toEntity() => Incident(
        id: id,
        incidentCode: incidentCode,
        title: title,
        description: description,
        logText: logText,
        severity: severity,
        status: status,
        components: components,
        rootCause: rootCause,
        confidence: confidence,
        selectedFixFlowId: selectedFixFlowId,
        resolvedAt: resolvedAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
        fixFlows: fixFlows.map((e) => e.toEntity()).toList(),
        similarIncidents: similarIncidents.map((e) => e.toEntity()).toList(),
        timeline: timeline.map((e) => e.toEntity()).toList(),
        note: note?.toEntity(),
      );
}

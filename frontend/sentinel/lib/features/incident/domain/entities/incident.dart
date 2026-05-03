import 'package:flutter/foundation.dart';
import 'fix_flow.dart';
import 'similar_incident.dart';
import 'timeline_event.dart';
import 'note.dart';

@immutable
class Incident {
  const Incident({
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
  final List<FixFlow> fixFlows;
  final List<SimilarIncident> similarIncidents;
  final List<TimelineEvent> timeline;
  final Note? note;
}

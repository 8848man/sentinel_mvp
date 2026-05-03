import 'package:flutter/foundation.dart';

@immutable
class IncidentModel {
  const IncidentModel({
    required this.id,
    required this.incidentCode,
    required this.title,
    required this.description,
    required this.severity,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String incidentCode;
  final String title;
  final String? description;
  final String severity;  // critical | major | minor
  final String status;    // open | in_progress | resolved | closed
  final DateTime createdAt;

  factory IncidentModel.fromJson(Map<String, dynamic> json) {
    return IncidentModel(
      id: json['id'] as String,
      incidentCode: json['incident_code'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      severity: json['severity'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

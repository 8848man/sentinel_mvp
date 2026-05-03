import '../../domain/entities/incident_metadata.dart';

class IncidentMetadataModel {
  const IncidentMetadataModel({
    required this.suggestedId,
    required this.suggestedTitle,
    required this.suggestedSeverity,
    required this.detectedComponents,
  });

  final String suggestedId;
  final String suggestedTitle;
  final String suggestedSeverity;
  final List<String> detectedComponents;

  factory IncidentMetadataModel.fromJson(Map<String, dynamic> json) {
    return IncidentMetadataModel(
      suggestedId: json['suggested_id'] as String,
      suggestedTitle: json['suggested_title'] as String,
      suggestedSeverity: json['suggested_severity'] as String,
      detectedComponents: (json['detected_components'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }

  IncidentMetadata toEntity() => IncidentMetadata(
        suggestedId: suggestedId,
        suggestedTitle: suggestedTitle,
        suggestedSeverity: suggestedSeverity,
        detectedComponents: detectedComponents,
      );
}

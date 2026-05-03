import '../../domain/entities/similar_incident.dart';

class SimilarIncidentModel {
  const SimilarIncidentModel({
    required this.incidentId,
    required this.incidentCode,
    required this.matchScore,
  });

  final String incidentId;
  final String incidentCode;
  final double matchScore;

  factory SimilarIncidentModel.fromJson(Map<String, dynamic> json) {
    return SimilarIncidentModel(
      incidentId: json['incident_id'] as String,
      incidentCode: json['incident_code'] as String,
      matchScore: (json['match_score'] as num).toDouble(),
    );
  }

  SimilarIncident toEntity() => SimilarIncident(
        incidentId: incidentId,
        incidentCode: incidentCode,
        matchScore: matchScore,
      );
}

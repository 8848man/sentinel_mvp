import 'package:flutter/foundation.dart';

@immutable
class SimilarIncident {
  const SimilarIncident({
    required this.incidentId,
    required this.incidentCode,
    required this.matchScore,
  });

  final String incidentId;
  final String incidentCode;
  final double matchScore;
}

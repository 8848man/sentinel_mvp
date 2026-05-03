import 'package:flutter/foundation.dart';

@immutable
class IncidentMetadata {
  const IncidentMetadata({
    required this.suggestedId,
    required this.suggestedTitle,
    required this.suggestedSeverity,
    required this.detectedComponents,
  });

  final String suggestedId;
  final String suggestedTitle;
  final String suggestedSeverity;
  final List<String> detectedComponents;
}

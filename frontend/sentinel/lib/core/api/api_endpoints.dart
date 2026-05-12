class ApiEndpoints {
  ApiEndpoints._();

  static const String base = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const analyzeMetadata = '/api/v1/incidents/analyze-metadata';
  static const incidents = '/api/v1/incidents';
  static const archive = '/api/v1/archive';

  static String incidentById(String id) => '/api/v1/incidents/$id';
  static String resolveIncident(String id) => '/api/v1/incidents/$id/resolve';
  static String closeIncident(String id) => '/api/v1/incidents/$id/close';
  static String incidentNote(String id) => '/api/v1/incidents/$id/note';
  static String incidentTimeline(String id) => '/api/v1/incidents/$id/timeline';
  static String checklistItem(String id) => '/api/v1/checklist/$id';
  static String fixFlowAttempted(String id) => '/api/v1/fix-flows/$id/attempted';
}

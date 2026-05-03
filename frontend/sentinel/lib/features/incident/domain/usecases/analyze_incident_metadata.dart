import '../entities/incident_metadata.dart';
import '../repositories/incident_repository.dart';

class AnalyzeIncidentMetadata {
  const AnalyzeIncidentMetadata(this._repository);
  final IncidentRepository _repository;

  Future<IncidentMetadata> call(String rawLog) => _repository.analyzeMetadata(rawLog);
}

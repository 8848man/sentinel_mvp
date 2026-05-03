import '../entities/incident.dart';
import '../repositories/incident_repository.dart';

class GetArchiveIncidents {
  const GetArchiveIncidents(this._repository);
  final IncidentRepository _repository;

  Future<List<Incident>> call() => _repository.getArchiveIncidents();
}

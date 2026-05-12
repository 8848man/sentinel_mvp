import '../entities/incident.dart';
import '../repositories/incident_repository.dart';

class CloseIncident {
  const CloseIncident(this._repository);
  final IncidentRepository _repository;

  Future<Incident> call(String id) => _repository.closeIncident(id);
}

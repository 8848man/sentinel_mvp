import '../entities/incident.dart';
import '../repositories/incident_repository.dart';

class ResolveIncident {
  const ResolveIncident(this._repository);
  final IncidentRepository _repository;

  Future<Incident> call(String id) => _repository.resolveIncident(id);
}

import '../entities/incident.dart';
import '../repositories/incident_repository.dart';

class GetIncidentDetail {
  const GetIncidentDetail(this._repository);
  final IncidentRepository _repository;

  Future<Incident> call(String id) => _repository.getIncidentDetail(id);
}

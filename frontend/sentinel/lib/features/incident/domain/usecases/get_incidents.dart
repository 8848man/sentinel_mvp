import '../entities/incident.dart';
import '../repositories/incident_repository.dart';

class GetIncidents {
  const GetIncidents(this._repository);
  final IncidentRepository _repository;

  Future<List<Incident>> call({String? status}) =>
      _repository.getIncidents(status: status);
}

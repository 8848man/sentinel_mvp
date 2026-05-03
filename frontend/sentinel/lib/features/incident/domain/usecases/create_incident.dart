import '../entities/incident.dart';
import '../repositories/incident_repository.dart';

class CreateIncident {
  const CreateIncident(this._repository);
  final IncidentRepository _repository;

  Future<Incident> call({
    required String logText,
    required String title,
    required String severity,
    required List<String> components,
  }) =>
      _repository.createIncident(
        logText: logText,
        title: title,
        severity: severity,
        components: components,
      );
}

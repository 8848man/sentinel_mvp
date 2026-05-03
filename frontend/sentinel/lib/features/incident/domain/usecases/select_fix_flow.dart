import '../entities/incident.dart';
import '../repositories/incident_repository.dart';

class SelectFixFlow {
  const SelectFixFlow(this._repository);
  final IncidentRepository _repository;

  Future<Incident> call(String incidentId, String fixFlowId) =>
      _repository.patchIncident(
        incidentId,
        selectedFixFlowId: fixFlowId,
        status: 'in_progress',
      );
}

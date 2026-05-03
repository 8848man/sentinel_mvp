import '../entities/note.dart';
import '../repositories/incident_repository.dart';

class SaveNote {
  const SaveNote(this._repository);
  final IncidentRepository _repository;

  Future<Note> call(String incidentId, String content) =>
      _repository.saveNote(incidentId, content);
}

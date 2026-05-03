import '../entities/checklist_item.dart';
import '../repositories/incident_repository.dart';

class UpdateChecklistItem {
  const UpdateChecklistItem(this._repository);
  final IncidentRepository _repository;

  Future<ChecklistItem> call(String itemId, {required bool isCompleted}) =>
      _repository.updateChecklistItem(itemId, isCompleted: isCompleted);
}

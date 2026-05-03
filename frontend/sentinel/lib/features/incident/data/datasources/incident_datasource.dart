import '../models/checklist_item_model.dart';
import '../models/incident_metadata_model.dart';
import '../models/incident_model.dart';
import '../models/note_model.dart';

abstract class IncidentDatasource {
  Future<IncidentMetadataModel> analyzeMetadata(String rawLog);

  Future<IncidentModel> createIncident({
    required String logText,
    required String title,
    required String severity,
    required List<String> components,
  });

  Future<List<IncidentModel>> getIncidents({String? status});

  Future<IncidentModel> getIncidentDetail(String id);

  Future<IncidentModel> patchIncident(
    String id, {
    String? selectedFixFlowId,
    String? status,
  });

  Future<IncidentModel> resolveIncident(String id);

  Future<ChecklistItemModel> updateChecklistItem(
    String itemId, {
    required bool isCompleted,
  });

  Future<NoteModel> saveNote(String incidentId, String content);

  Future<List<IncidentModel>> getArchiveIncidents();
}

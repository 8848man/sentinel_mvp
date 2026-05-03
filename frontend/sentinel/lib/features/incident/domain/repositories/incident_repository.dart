import '../entities/incident.dart';
import '../entities/incident_metadata.dart';
import '../entities/note.dart';
import '../entities/checklist_item.dart';

abstract class IncidentRepository {
  /// Analyze raw log text — returns AI-suggested metadata only, no DB write.
  Future<IncidentMetadata> analyzeMetadata(String rawLog);

  /// Create incident from form data — triggers AI analysis, returns full incident.
  Future<Incident> createIncident({
    required String logText,
    required String title,
    required String severity,
    required List<String> components,
  });

  /// Returns all active incidents (status != closed) for the current user.
  Future<List<Incident>> getIncidents({String? status});

  /// Returns full incident detail including fix_flows, timeline, note.
  Future<Incident> getIncidentDetail(String id);

  /// Patches incident — used to attach fix flow or change status.
  Future<Incident> patchIncident(String id, {
    String? selectedFixFlowId,
    String? status,
  });

  /// Marks incident as resolved.
  Future<Incident> resolveIncident(String id);

  /// Toggles a checklist item's completion state.
  Future<ChecklistItem> updateChecklistItem(String itemId, {required bool isCompleted});

  /// Creates or replaces the note for an incident.
  Future<Note> saveNote(String incidentId, String content);

  /// Returns all closed/resolved incidents.
  Future<List<Incident>> getArchiveIncidents();
}

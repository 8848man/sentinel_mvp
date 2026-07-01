import 'dart:typed_data';

import '../../domain/entities/incident.dart';
import '../../domain/entities/incident_metadata.dart';
import '../../domain/entities/checklist_item.dart';
import '../../domain/entities/note.dart';
import '../../domain/entities/ocr_extraction_result.dart';
import '../../domain/repositories/incident_repository.dart';
import '../datasources/incident_datasource.dart';

class IncidentRepositoryImpl implements IncidentRepository {
  const IncidentRepositoryImpl(this._datasource);
  final IncidentDatasource _datasource;

  @override
  Future<IncidentMetadata> analyzeMetadata(String rawLog) async {
    final model = await _datasource.analyzeMetadata(rawLog);
    return model.toEntity();
  }

  @override
  Future<OcrExtractionResult> extractLogFromImage(
    Uint8List imageBytes,
    String filename,
  ) async {
    final model = await _datasource.extractLogFromImage(imageBytes, filename);
    return model.toEntity();
  }

  @override
  Future<Incident> createIncident({
    required String logText,
    required String title,
    required String severity,
    required List<String> components,
  }) async {
    final model = await _datasource.createIncident(
      logText: logText,
      title: title,
      severity: severity,
      components: components,
    );
    return model.toEntity();
  }

  @override
  Future<List<Incident>> getIncidents({String? status}) async {
    final models = await _datasource.getIncidents(status: status);
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<Incident> getIncidentDetail(String id) async {
    final model = await _datasource.getIncidentDetail(id);
    return model.toEntity();
  }

  @override
  Future<Incident> patchIncident(String id, {
    String? selectedFixFlowId,
    String? status,
  }) async {
    final model = await _datasource.patchIncident(
      id,
      selectedFixFlowId: selectedFixFlowId,
      status: status,
    );
    return model.toEntity();
  }

  @override
  Future<Incident> resolveIncident(String id) async {
    final model = await _datasource.resolveIncident(id);
    return model.toEntity();
  }

  @override
  Future<Incident> closeIncident(String id) async {
    final model = await _datasource.closeIncident(id);
    return model.toEntity();
  }

  @override
  Future<ChecklistItem> updateChecklistItem(String itemId,
      {required bool isCompleted}) async {
    final model = await _datasource.updateChecklistItem(
      itemId,
      isCompleted: isCompleted,
    );
    return model.toEntity();
  }

  @override
  Future<Note> saveNote(String incidentId, String content) async {
    final model = await _datasource.saveNote(incidentId, content);
    return model.toEntity();
  }

  @override
  Future<List<Incident>> getArchiveIncidents() async {
    final models = await _datasource.getArchiveIncidents();
    return models.map((m) => m.toEntity()).toList();
  }
}

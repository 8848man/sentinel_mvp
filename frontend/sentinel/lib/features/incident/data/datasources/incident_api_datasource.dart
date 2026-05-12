import 'package:dio/dio.dart';
import '../../../../core/api/api_endpoints.dart';
import '../models/checklist_item_model.dart';
import '../models/incident_metadata_model.dart';
import '../models/incident_model.dart';
import '../models/note_model.dart';
import 'incident_datasource.dart';

class IncidentApiDatasource implements IncidentDatasource {
  const IncidentApiDatasource(this._dio);

  final Dio _dio;

  String _detail(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return data['detail'] as String? ?? e.message ?? 'Request failed';
      }
    } catch (_) {}
    return e.message ?? 'Request failed';
  }

  // ── POST /incidents/analyze-metadata ────────────────────────────────────────

  @override
  Future<IncidentMetadataModel> analyzeMetadata(String rawLog) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.analyzeMetadata,
        data: {'log_text': rawLog},
      );
      return IncidentMetadataModel.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_detail(e));
    }
  }

  // ── POST /incidents ──────────────────────────────────────────────────────────

  @override
  Future<IncidentModel> createIncident({
    required String logText,
    required String title,
    required String severity,
    required List<String> components,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.incidents,
        data: {
          'log_text': logText,
          'title': title,
          'severity': severity,
          'components': components,
        },
      );
      return IncidentModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_detail(e));
    }
  }

  // ── GET /incidents ───────────────────────────────────────────────────────────

  @override
  Future<List<IncidentModel>> getIncidents({String? status}) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.incidents,
        queryParameters: status != null ? {'status': status} : null,
      );
      return (response.data['data'] as List<dynamic>)
          .map((e) => IncidentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_detail(e));
    }
  }

  // ── GET /incidents/{id} ──────────────────────────────────────────────────────

  @override
  Future<IncidentModel> getIncidentDetail(String id) async {
    try {
      final response = await _dio.get(ApiEndpoints.incidentById(id));
      return IncidentModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_detail(e));
    }
  }

  // ── PATCH /incidents/{id} ────────────────────────────────────────────────────

  @override
  Future<IncidentModel> patchIncident(
    String id, {
    String? selectedFixFlowId,
    String? status,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (selectedFixFlowId != null) {
        body['selected_fix_flow_id'] = selectedFixFlowId;
      }
      if (status != null) body['status'] = status;

      final response =
          await _dio.patch(ApiEndpoints.incidentById(id), data: body);
      return IncidentModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_detail(e));
    }
  }

  // ── PATCH /incidents/{id}/resolve ────────────────────────────────────────────
  // The resolve endpoint returns a partial object (id, status, resolved_at).
  // We follow up with a GET to return the full incident.

  @override
  Future<IncidentModel> resolveIncident(String id) async {
    try {
      await _dio.patch(ApiEndpoints.resolveIncident(id));
      final detail = await _dio.get(ApiEndpoints.incidentById(id));
      return IncidentModel.fromJson(detail.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_detail(e));
    }
  }

  // ── PATCH /incidents/{id}/close ──────────────────────────────────────────────

  @override
  Future<IncidentModel> closeIncident(String id) async {
    try {
      await _dio.patch(ApiEndpoints.closeIncident(id));
      final detail = await _dio.get(ApiEndpoints.incidentById(id));
      return IncidentModel.fromJson(detail.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_detail(e));
    }
  }

  // ── PATCH /checklist/{item_id} ───────────────────────────────────────────────
  // The API returns only {id, is_completed, updated_at}.
  // step_number and description are defaulted to 0 / '' here;
  // WorkspaceNotifier._applyChecklistUpdate merges them from local state.

  @override
  Future<ChecklistItemModel> updateChecklistItem(
    String itemId, {
    required bool isCompleted,
  }) async {
    try {
      final response = await _dio.patch(
        ApiEndpoints.checklistItem(itemId),
        data: {'is_completed': isCompleted},
      );
      return ChecklistItemModel.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_detail(e));
    }
  }

  // ── PUT /incidents/{id}/note ─────────────────────────────────────────────────

  @override
  Future<NoteModel> saveNote(String incidentId, String content) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.incidentNote(incidentId),
        data: {'content': content},
      );
      return NoteModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_detail(e));
    }
  }

  // ── GET /archive ─────────────────────────────────────────────────────────────

  @override
  Future<List<IncidentModel>> getArchiveIncidents() async {
    try {
      final response = await _dio.get(ApiEndpoints.archive);
      return (response.data['data'] as List<dynamic>)
          .map((e) => IncidentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_detail(e));
    }
  }
}

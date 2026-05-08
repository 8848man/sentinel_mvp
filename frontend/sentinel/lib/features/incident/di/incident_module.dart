import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../data/datasources/incident_datasource.dart';
import '../data/datasources/incident_remote_datasource.dart';
import '../data/datasources/incident_api_datasource.dart';
import '../data/repositories/incident_repository_impl.dart';
import '../domain/repositories/incident_repository.dart';
import '../domain/usecases/analyze_incident_metadata.dart';
import '../domain/usecases/create_incident.dart';
import '../domain/usecases/get_incidents.dart';
import '../domain/usecases/get_incident_detail.dart';
import '../domain/usecases/resolve_incident.dart';
import '../domain/usecases/update_checklist_item.dart';
import '../domain/usecases/save_note.dart';
import '../domain/usecases/get_archive_incidents.dart';
import '../domain/usecases/select_fix_flow.dart';

/// Monotonically-incrementing counter. Bump this after any mutation that
/// changes the incident list (create, resolve) so that DashboardNotifier and
/// ArchiveNotifier automatically reload via their ref.listen subscriptions.
final incidentListStampProvider = StateProvider<int>((_) => 0);

final incidentDatasourceProvider = Provider<IncidentDatasource>((ref) {
  if (AppConfig.useMockData) return IncidentRemoteDatasource();
  return IncidentApiDatasource(ref.watch(apiClientProvider));
});

final incidentRepositoryProvider = Provider<IncidentRepository>(
  (ref) => IncidentRepositoryImpl(ref.watch(incidentDatasourceProvider)),
);

final analyzeMetadataUseCaseProvider = Provider<AnalyzeIncidentMetadata>(
  (ref) => AnalyzeIncidentMetadata(ref.watch(incidentRepositoryProvider)),
);

final createIncidentUseCaseProvider = Provider<CreateIncident>(
  (ref) => CreateIncident(ref.watch(incidentRepositoryProvider)),
);

final getIncidentsUseCaseProvider = Provider<GetIncidents>(
  (ref) => GetIncidents(ref.watch(incidentRepositoryProvider)),
);

final getIncidentDetailUseCaseProvider = Provider<GetIncidentDetail>(
  (ref) => GetIncidentDetail(ref.watch(incidentRepositoryProvider)),
);

final resolveIncidentUseCaseProvider = Provider<ResolveIncident>(
  (ref) => ResolveIncident(ref.watch(incidentRepositoryProvider)),
);

final updateChecklistItemUseCaseProvider = Provider<UpdateChecklistItem>(
  (ref) => UpdateChecklistItem(ref.watch(incidentRepositoryProvider)),
);

final saveNoteUseCaseProvider = Provider<SaveNote>(
  (ref) => SaveNote(ref.watch(incidentRepositoryProvider)),
);

final getArchiveIncidentsUseCaseProvider = Provider<GetArchiveIncidents>(
  (ref) => GetArchiveIncidents(ref.watch(incidentRepositoryProvider)),
);

final selectFixFlowUseCaseProvider = Provider<SelectFixFlow>(
  (ref) => SelectFixFlow(ref.watch(incidentRepositoryProvider)),
);

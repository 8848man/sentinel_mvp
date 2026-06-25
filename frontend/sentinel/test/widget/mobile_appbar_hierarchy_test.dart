import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/features/incident/di/incident_module.dart';
import 'package:sentinel/features/incident/domain/entities/incident.dart';
import 'package:sentinel/features/incident/domain/entities/incident_metadata.dart';
import 'package:sentinel/features/incident/domain/entities/note.dart';
import 'package:sentinel/features/incident/domain/entities/checklist_item.dart';
import 'package:sentinel/features/incident/domain/repositories/incident_repository.dart';
import 'package:sentinel/features/incident/domain/usecases/get_incident_detail.dart';
import 'package:sentinel/features/incident/presentation/analysis/screens/analysis_screen.dart';
import 'package:sentinel/features/incident/presentation/workspace/screens/workspace_screen.dart';

const _title = 'Database Connection Failure Investigation';
const _code = 'INC-12345';

class _FakeIncidentRepository implements IncidentRepository {
  final _incident = Incident(
    id: 'inc-1',
    incidentCode: _code,
    title: _title,
    logText: 'log',
    severity: 'critical',
    status: 'open',
    components: [],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  @override
  Future<Incident> getIncidentDetail(String id) async => _incident;

  @override
  Future<IncidentMetadata> analyzeMetadata(String rawLog) =>
      throw UnimplementedError();
  @override
  Future<Incident> createIncident({
    required String logText,
    required String title,
    required String severity,
    required List<String> components,
  }) =>
      throw UnimplementedError();
  @override
  Future<List<Incident>> getIncidents({String? status}) =>
      throw UnimplementedError();
  @override
  Future<Incident> patchIncident(String id,
          {String? selectedFixFlowId, String? status}) =>
      throw UnimplementedError();
  @override
  Future<Incident> resolveIncident(String id) => throw UnimplementedError();
  @override
  Future<Incident> closeIncident(String id) => throw UnimplementedError();
  @override
  Future<ChecklistItem> updateChecklistItem(String itemId,
          {required bool isCompleted}) =>
      throw UnimplementedError();
  @override
  Future<Note> saveNote(String incidentId, String content) =>
      throw UnimplementedError();
  @override
  Future<List<Incident>> getArchiveIncidents() => throw UnimplementedError();
}

Widget _wrap(Widget child, Size size) {
  final repo = _FakeIncidentRepository();
  return ProviderScope(
    overrides: [
      getIncidentDetailUseCaseProvider.overrideWithValue(
        GetIncidentDetail(repo),
      ),
    ],
    child: MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(home: child),
    ),
  );
}

void main() {
  testWidgets(
      'Analysis: mobile header shows page label only, title/ID move to page content',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const AnalysisScreen(incidentId: 'inc-1'), const Size(360, 900)),
    );
    await tester.pumpAndSettle();

    // AppBar-equivalent header: back + page label only.
    expect(find.text('← Dashboard'), findsOneWidget);
    expect(find.text('AI Analysis'), findsOneWidget);

    // Incident title + ID render in the page content, not the header.
    expect(find.text(_title), findsOneWidget);
    expect(find.text(_code), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Workspace: mobile header shows page label only, title/ID move to page content',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const WorkspaceScreen(incidentId: 'inc-1'), const Size(360, 900)),
    );
    await tester.pumpAndSettle();

    expect(find.text('← Dashboard'), findsOneWidget);
    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text(_title), findsOneWidget);
    expect(find.text(_code), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Analysis: desktop header keeps incident code/title inline (unchanged)',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const AnalysisScreen(incidentId: 'inc-1'), const Size(1400, 900)),
    );
    await tester.pumpAndSettle();

    expect(find.text(_code), findsOneWidget);
    expect(find.text(_title), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

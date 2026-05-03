import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/config/app_config.dart';
import '../../../incident/di/incident_module.dart';
import '../../data/models/dashboard_incident_summary_model.dart';
import '../../../../design_system/tokens/view_mode.dart';

@immutable
class DashboardState {
  const DashboardState({
    this.incidents = const [],
    this.viewMode = DashboardViewMode.status,
    required this.utcTime,
    this.isLoading = false,
    this.error,
  });

  final List<DashboardIncidentSummaryModel> incidents;
  final DashboardViewMode viewMode;
  final DateTime utcTime;
  final bool isLoading;
  final String? error;

  DashboardState copyWith({
    List<DashboardIncidentSummaryModel>? incidents,
    DashboardViewMode? viewMode,
    DateTime? utcTime,
    bool? isLoading,
    String? error,
  }) {
    return DashboardState(
      incidents: incidents ?? this.incidents,
      viewMode: viewMode ?? this.viewMode,
      utcTime: utcTime ?? this.utcTime,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  List<DashboardIncidentSummaryModel> byStatus(String status) =>
      incidents.where((i) => i.status == status).toList();

  List<DashboardIncidentSummaryModel> bySeverity(String severity) =>
      incidents.where((i) => i.severity == severity).toList();
}

class DashboardNotifier extends Notifier<DashboardState> {
  Timer? _clockTimer;

  @override
  DashboardState build() {
    _startClock();
    ref.onDispose(() => _clockTimer?.cancel());
    Future.microtask(loadIncidents);
    return DashboardState(utcTime: DateTime.now().toUtc());
  }

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      state = state.copyWith(utcTime: DateTime.now().toUtc());
    });
  }

  Future<void> loadIncidents() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final List<DashboardIncidentSummaryModel> data;

      if (AppConfig.useMockData) {
        final useCase = ref.read(getIncidentsUseCaseProvider);
        final incidents = await useCase();
        data = incidents
            .map((i) => DashboardIncidentSummaryModel(
                  id: i.id,
                  incidentCode: i.incidentCode,
                  title: i.title,
                  description: i.description,
                  severity: i.severity,
                  status: i.status,
                  createdAt: i.createdAt,
                ))
            .toList();
      } else {
        final dio = ref.read(apiClientProvider);
        final response = await dio.get(ApiEndpoints.incidents);
        data = (response.data['data'] as List)
            .map((json) => DashboardIncidentSummaryModel.fromJson(
                json as Map<String, dynamic>))
            .toList();
      }

      state = state.copyWith(incidents: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load incidents. Pull to refresh.',
      );
    }
  }

  void toggleViewMode() {
    state = state.copyWith(
      viewMode: state.viewMode == DashboardViewMode.status
          ? DashboardViewMode.severity
          : DashboardViewMode.status,
    );
  }
}

final dashboardProvider = NotifierProvider<DashboardNotifier, DashboardState>(
  DashboardNotifier.new,
);

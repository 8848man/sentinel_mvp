import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../di/incident_module.dart';
import '../../../domain/entities/incident.dart';

@immutable
class AnalysisState {
  const AnalysisState({
    this.isLoading = false,
    this.incident,
    this.isSelectingFlow = false,
    this.error,
    this.navigateToWorkspace = false,
  });

  final bool isLoading;
  final Incident? incident;
  final bool isSelectingFlow;
  final String? error;
  final bool navigateToWorkspace;

  AnalysisState copyWith({
    bool? isLoading,
    Incident? incident,
    bool? isSelectingFlow,
    String? error,
    bool? navigateToWorkspace,
    bool clearError = false,
  }) {
    return AnalysisState(
      isLoading: isLoading ?? this.isLoading,
      incident: incident ?? this.incident,
      isSelectingFlow: isSelectingFlow ?? this.isSelectingFlow,
      error: clearError ? null : (error ?? this.error),
      navigateToWorkspace: navigateToWorkspace ?? this.navigateToWorkspace,
    );
  }
}

class AnalysisNotifier extends FamilyNotifier<AnalysisState, String> {
  @override
  AnalysisState build(String incidentId) {
    Future.microtask(() => _load(incidentId));
    return const AnalysisState(isLoading: true);
  }

  Future<void> _load(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final useCase = ref.read(getIncidentDetailUseCaseProvider);
      final incident = await useCase(id);
      state = state.copyWith(isLoading: false, incident: incident);
    } catch (_) {
      state = state.copyWith(
          isLoading: false, error: 'Failed to load incident details.');
    }
  }

  Future<void> selectFixFlow(String flowId) async {
    state = state.copyWith(isSelectingFlow: true, clearError: true);
    try {
      final useCase = ref.read(selectFixFlowUseCaseProvider);
      final updated = await useCase(arg, flowId);
      state = state.copyWith(
        isSelectingFlow: false,
        incident: updated,
        navigateToWorkspace: true,
      );
    } catch (_) {
      state = state.copyWith(
          isSelectingFlow: false, error: 'Failed to select fix flow.');
    }
  }
}

final analysisProvider =
    NotifierProvider.family<AnalysisNotifier, AnalysisState, String>(
  AnalysisNotifier.new,
);

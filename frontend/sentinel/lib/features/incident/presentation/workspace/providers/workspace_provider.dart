import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/utils/debounce.dart';
import '../../../di/incident_module.dart';
import '../../../domain/entities/incident.dart';
import '../../../domain/entities/checklist_item.dart';
import '../../../domain/entities/fix_flow.dart';
import '../../../domain/usecases/close_incident.dart';
import '../../../domain/repositories/incident_repository.dart';

@immutable
class WorkspaceState {
  const WorkspaceState({
    this.isLoading = false,
    this.incident,
    this.noteContent = '',
    this.togglingItemId,
    this.isResolving = false,
    this.isClosing = false,
    this.isReopening = false,
    this.error,
    this.navigateToDashboard = false,
  });

  final bool isLoading;
  final Incident? incident;
  final String noteContent;
  final String? togglingItemId;
  final bool isResolving;
  final bool isClosing;
  final bool isReopening;
  final String? error;
  final bool navigateToDashboard;

  WorkspaceState copyWith({
    bool? isLoading,
    Incident? incident,
    String? noteContent,
    String? togglingItemId,
    bool? isResolving,
    bool? isClosing,
    bool? isReopening,
    String? error,
    bool? navigateToDashboard,
    bool clearTogglingItem = false,
    bool clearError = false,
  }) {
    return WorkspaceState(
      isLoading: isLoading ?? this.isLoading,
      incident: incident ?? this.incident,
      noteContent: noteContent ?? this.noteContent,
      togglingItemId:
          clearTogglingItem ? null : (togglingItemId ?? this.togglingItemId),
      isResolving: isResolving ?? this.isResolving,
      isClosing: isClosing ?? this.isClosing,
      isReopening: isReopening ?? this.isReopening,
      error: clearError ? null : (error ?? this.error),
      navigateToDashboard: navigateToDashboard ?? this.navigateToDashboard,
    );
  }
}

class WorkspaceNotifier extends FamilyNotifier<WorkspaceState, String> {
  late final Debounce _noteDebounce;

  @override
  WorkspaceState build(String incidentId) {
    _noteDebounce = Debounce(duration: const Duration(seconds: 1));
    ref.onDispose(_noteDebounce.dispose);
    Future.microtask(() => _load(incidentId));
    return const WorkspaceState(isLoading: true);
  }

  Future<void> _load(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final useCase = ref.read(getIncidentDetailUseCaseProvider);
      final incident = await useCase(id);
      state = state.copyWith(
        isLoading: false,
        incident: incident,
        noteContent: incident.note?.content ?? '',
      );
    } catch (_) {
      state = state.copyWith(
          isLoading: false, error: 'Failed to load workspace.');
    }
  }

  Future<void> toggleChecklistItem(String itemId, bool currentCompleted) async {
    state = state.copyWith(togglingItemId: itemId);
    try {
      final useCase = ref.read(updateChecklistItemUseCaseProvider);
      final updated =
          await useCase(itemId, isCompleted: !currentCompleted);
      _applyChecklistUpdate(updated);
      _silentReload(arg); // refresh timeline without blocking UI
    } catch (_) {
      state = state.copyWith(
          clearTogglingItem: true, error: 'Failed to update step.');
    }
  }

  Future<void> _silentReload(String id) async {
    try {
      final useCase = ref.read(getIncidentDetailUseCaseProvider);
      final incident = await useCase(id);
      state = state.copyWith(incident: incident);
    } catch (_) {
      // Keep current state if background reload fails.
    }
  }

  void _applyChecklistUpdate(ChecklistItem updated) {
    final incident = state.incident;
    if (incident == null) return;

    final newFixFlows = incident.fixFlows.map((flow) {
      final idx = flow.checklistItems.indexWhere((c) => c.id == updated.id);
      if (idx == -1) return flow;
      final existing = flow.checklistItems[idx];
      // Merge: keep description/stepNumber from local state; take isCompleted/updatedAt from API.
      final merged = ChecklistItem(
        id: existing.id,
        stepNumber: existing.stepNumber,
        description: existing.description,
        isCompleted: updated.isCompleted,
        updatedAt: updated.updatedAt,
      );
      final newItems = List<ChecklistItem>.from(flow.checklistItems);
      newItems[idx] = merged;
      return FixFlow(
        id: flow.id,
        title: flow.title,
        confidence: flow.confidence,
        isAttempted: flow.isAttempted,
        checklistItems: newItems,
      );
    }).toList();

    final newIncident = Incident(
      id: incident.id,
      incidentCode: incident.incidentCode,
      title: incident.title,
      description: incident.description,
      logText: incident.logText,
      severity: incident.severity,
      status: incident.status,
      components: incident.components,
      rootCause: incident.rootCause,
      confidence: incident.confidence,
      selectedFixFlowId: incident.selectedFixFlowId,
      resolvedAt: incident.resolvedAt,
      createdAt: incident.createdAt,
      updatedAt: incident.updatedAt,
      fixFlows: newFixFlows,
      similarIncidents: incident.similarIncidents,
      timeline: incident.timeline,
      note: incident.note,
    );

    state = state.copyWith(
        incident: newIncident, clearTogglingItem: true);
  }

  void updateNote(String content) {
    state = state.copyWith(noteContent: content);
    _noteDebounce(() => _saveNote(arg, content));
  }

  Future<void> _saveNote(String incidentId, String content) async {
    try {
      final useCase = ref.read(saveNoteUseCaseProvider);
      await useCase(incidentId, content);
    } catch (_) {
      // Silent failure — note will be retried on next keystroke.
    }
  }

  Future<void> resolve() async {
    state = state.copyWith(isResolving: true, clearError: true);
    try {
      final useCase = ref.read(resolveIncidentUseCaseProvider);
      await useCase(arg);
      state = state.copyWith(isResolving: false, navigateToDashboard: true);
      ref.read(incidentListStampProvider.notifier).state++;
    } catch (_) {
      state = state.copyWith(
          isResolving: false, error: 'Failed to resolve incident.');
    }
  }

  Future<void> close() async {
    state = state.copyWith(isClosing: true, clearError: true);
    try {
      final useCase = ref.read(closeIncidentUseCaseProvider);
      await useCase(arg);
      state = state.copyWith(isClosing: false, navigateToDashboard: true);
      ref.read(incidentListStampProvider.notifier).state++;
    } catch (_) {
      state = state.copyWith(
          isClosing: false, error: 'Failed to close incident.');
    }
  }

  Future<void> reopen() async {
    state = state.copyWith(isReopening: true, clearError: true);
    try {
      final repo = ref.read(incidentRepositoryProvider);
      await repo.patchIncident(arg, status: 'in_progress');
      await _silentReload(arg);
      state = state.copyWith(isReopening: false);
      ref.read(incidentListStampProvider.notifier).state++;
    } catch (_) {
      state = state.copyWith(
          isReopening: false, error: 'Failed to reopen incident.');
    }
  }
}

final workspaceProvider =
    NotifierProvider.family<WorkspaceNotifier, WorkspaceState, String>(
  WorkspaceNotifier.new,
);

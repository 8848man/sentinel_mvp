import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../di/incident_module.dart';
import '../../../domain/entities/incident_metadata.dart';

@immutable
class RegistrationFormState {
  const RegistrationFormState({
    this.rawLog = '',
    this.suggestedIncidentId = '',
    this.title = '',
    this.severity = 'major',
    this.components = const [],
    this.isSubmitting = false,
    this.submitError,
    this.createdIncidentId,
  });

  final String rawLog;
  final String suggestedIncidentId;
  final String title;
  final String severity;
  final List<String> components;
  final bool isSubmitting;
  final String? submitError;
  final String? createdIncidentId;

  RegistrationFormState copyWith({
    String? rawLog,
    String? suggestedIncidentId,
    String? title,
    String? severity,
    List<String>? components,
    bool? isSubmitting,
    String? submitError,
    String? createdIncidentId,
    bool clearSubmitError = false,
  }) {
    return RegistrationFormState(
      rawLog: rawLog ?? this.rawLog,
      suggestedIncidentId: suggestedIncidentId ?? this.suggestedIncidentId,
      title: title ?? this.title,
      severity: severity ?? this.severity,
      components: components ?? this.components,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
      createdIncidentId: createdIncidentId ?? this.createdIncidentId,
    );
  }
}

class RegistrationFormNotifier extends AutoDisposeNotifier<RegistrationFormState> {
  @override
  RegistrationFormState build() => const RegistrationFormState();

  void updateRawLog(String value) => state = state.copyWith(rawLog: value);
  void updateTitle(String value) => state = state.copyWith(title: value);
  void updateSeverity(String value) => state = state.copyWith(severity: value);

  void addComponent(String component) {
    final trimmed = component.trim();
    if (trimmed.isEmpty || state.components.contains(trimmed)) return;
    state = state.copyWith(components: [...state.components, trimmed]);
  }

  void removeComponent(String component) {
    state = state.copyWith(
      components: state.components.where((c) => c != component).toList(),
    );
  }

  void applyMetadata(IncidentMetadata metadata) {
    state = state.copyWith(
      suggestedIncidentId: metadata.suggestedId,
      title: metadata.suggestedTitle,
      severity: metadata.suggestedSeverity,
      components: List.from(metadata.detectedComponents),
    );
  }

  Future<void> submit() async {
    if (state.title.trim().isEmpty) {
      state = state.copyWith(submitError: 'Title is required');
      return;
    }
    state = state.copyWith(isSubmitting: true, clearSubmitError: true);
    try {
      final useCase = ref.read(createIncidentUseCaseProvider);
      final incident = await useCase(
        logText: state.rawLog,
        title: state.title.trim(),
        severity: state.severity,
        components: List.from(state.components),
      );
      state = state.copyWith(isSubmitting: false, createdIncidentId: incident.id);
      ref.read(incidentListStampProvider.notifier).state++;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        submitError: kDebugMode ? e.toString() : 'Failed to create incident. Please try again.',
      );
    }
  }
}

final registrationFormProvider =
    NotifierProvider.autoDispose<RegistrationFormNotifier, RegistrationFormState>(
  RegistrationFormNotifier.new,
);

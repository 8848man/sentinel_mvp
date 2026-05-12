import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/utils/debounce.dart';
import '../../../di/incident_module.dart';
import '../../../domain/entities/incident_metadata.dart';
import 'registration_form_provider.dart';

@immutable
class RegistrationMetadataState {
  const RegistrationMetadataState({
    this.isAnalyzing = false,
    this.metadata,
    this.error,
  });

  final bool isAnalyzing;
  final IncidentMetadata? metadata;
  final String? error;

  RegistrationMetadataState copyWith({
    bool? isAnalyzing,
    IncidentMetadata? metadata,
    String? error,
    bool clearError = false,
  }) {
    return RegistrationMetadataState(
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      metadata: metadata ?? this.metadata,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class RegistrationMetadataNotifier extends AutoDisposeNotifier<RegistrationMetadataState> {
  late Debounce _debounce;

  @override
  RegistrationMetadataState build() {
    _debounce = Debounce(duration: const Duration(milliseconds: 600));
    ref.onDispose(_debounce.dispose);

    ref.listen<RegistrationFormState>(registrationFormProvider, (prev, next) {
      if (prev?.rawLog != next.rawLog) {
        _onRawLogChanged(next.rawLog);
      }
    });

    return const RegistrationMetadataState();
  }

  void _onRawLogChanged(String rawLog) {
    if (rawLog.trim().length < 10) return;
    _debounce(() => _analyze(rawLog));
  }

  Future<void> _analyze(String rawLog) async {
    state = state.copyWith(isAnalyzing: true, clearError: true);
    try {
      final useCase = ref.read(analyzeMetadataUseCaseProvider);
      final metadata = await useCase(rawLog);
      state = state.copyWith(isAnalyzing: false, metadata: metadata);
      ref.read(registrationFormProvider.notifier).applyMetadata(metadata);
    } catch (_) {
      state = state.copyWith(isAnalyzing: false, error: 'Analysis failed');
    }
  }
}

final registrationMetadataProvider =
    NotifierProvider.autoDispose<RegistrationMetadataNotifier, RegistrationMetadataState>(
  RegistrationMetadataNotifier.new,
);

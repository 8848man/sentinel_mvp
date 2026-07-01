import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../di/incident_module.dart';
import '../../../domain/entities/ocr_extraction_result.dart';

/// OCR-assisted Raw Log extraction flow state (sdd/context/04_1_ocr_log_extraction.md).
///
/// Stage machine: idle → picking → uploading → reviewing → (idle on
/// cancel/insert) | error. "picking" covers image-source selection at the
/// widget layer (image_picker); this provider owns everything from the
/// moment bytes are selected through review/insertion.
enum OcrFlowStage { idle, picking, uploading, reviewing, error }

/// Time-based processing message shown during `uploading` (no backend
/// progress reporting — purely a local timer, since OCR is a single
/// request/response call that can take 20-30s+ on dense screenshots).
@immutable
class OcrProcessingMessage {
  const OcrProcessingMessage(this.headline, this.subtext);

  final String headline;
  final String subtext;
}

const ocrProcessingMessageStage1 = OcrProcessingMessage(
  '📷 Extracting text from image...',
  'Large screenshots and dense logs may take longer to process.',
);
const ocrProcessingMessageStage2 = OcrProcessingMessage(
  '📷 Processing screenshot...',
  'Large images may require additional processing time.',
);
const ocrProcessingMessageStage3 = OcrProcessingMessage(
  '📷 Still processing...',
  'This screenshot contains a large amount of text.\n'
      'OCR processing may take up to 1 minute.',
);

@immutable
class OcrFlowState {
  const OcrFlowState({
    this.stage = OcrFlowStage.idle,
    this.result,
    this.errorMessage,
    this.processingMessage = ocrProcessingMessageStage1,
  });

  final OcrFlowStage stage;
  final OcrExtractionResult? result;
  final String? errorMessage;
  final OcrProcessingMessage processingMessage;

  OcrFlowState copyWith({
    OcrFlowStage? stage,
    OcrExtractionResult? result,
    String? errorMessage,
    OcrProcessingMessage? processingMessage,
  }) {
    return OcrFlowState(
      stage: stage ?? this.stage,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      processingMessage: processingMessage ?? this.processingMessage,
    );
  }
}

class OcrFlowNotifier extends AutoDisposeNotifier<OcrFlowState> {
  Timer? _stage2Timer;
  Timer? _stage3Timer;

  @override
  OcrFlowState build() {
    // autoDispose covers "user navigates away" (OCR11) — the provider and
    // its state are torn down when Registration is no longer watching it.
    // Timers are local-only (no server polling) and must die with it too.
    ref.onDispose(_cancelMessageTimers);
    return const OcrFlowState();
  }

  void _cancelMessageTimers() {
    _stage2Timer?.cancel();
    _stage3Timer?.cancel();
    _stage2Timer = null;
    _stage3Timer = null;
  }

  /// Picking has started (widget is showing/awaiting the native chooser).
  void startPicking() => state = const OcrFlowState(stage: OcrFlowStage.picking);

  /// Picker-level failure: camera permission denied, no camera API, or the
  /// user dismissed the chooser. Distinct, named path — not a generic error
  /// (sdd/context/04_1_ocr_log_extraction.md Error Handling Requirements).
  void reportPickerError(String message) {
    _cancelMessageTimers();
    state = OcrFlowState(stage: OcrFlowStage.error, errorMessage: message);
  }

  /// Cancel the flow entirely — clears OCR/cleaned text from memory (OCR11).
  void cancel() {
    _cancelMessageTimers();
    state = const OcrFlowState();
  }

  /// Call immediately after the widget has inserted text into Raw Log —
  /// clears OCR/cleaned text from memory (OCR11). Insertion itself happens
  /// at the widget layer against registrationFormProvider, not here.
  void completeInsertion() {
    _cancelMessageTimers();
    state = const OcrFlowState();
  }

  Future<void> processImage(Uint8List imageBytes, String filename) async {
    _cancelMessageTimers();
    state = const OcrFlowState(
      stage: OcrFlowStage.uploading,
      processingMessage: ocrProcessingMessageStage1,
    );

    // Purely local, time-based messaging — no server progress reporting,
    // no polling. Only advances the message while still uploading, so a
    // fast response never flashes a "still processing" message after the
    // fact.
    _stage2Timer = Timer(const Duration(seconds: 5), () {
      if (state.stage == OcrFlowStage.uploading) {
        state = state.copyWith(processingMessage: ocrProcessingMessageStage2);
      }
    });
    _stage3Timer = Timer(const Duration(seconds: 15), () {
      if (state.stage == OcrFlowStage.uploading) {
        state = state.copyWith(processingMessage: ocrProcessingMessageStage3);
      }
    });

    try {
      final useCase = ref.read(extractLogFromImageUseCaseProvider);
      final result = await useCase(imageBytes, filename);
      _cancelMessageTimers();

      // "no_text" / "blocked" never reach the Review Screen — neither has
      // anything insertable, and they need distinct messaging, not generic
      // empty boxes (sdd/context/04_1_ocr_log_extraction.md Error Handling
      // Requirements).
      switch (result.ocrStatus) {
        case OcrStatus.ok:
          state = OcrFlowState(stage: OcrFlowStage.reviewing, result: result);
        case OcrStatus.noText:
          state = const OcrFlowState(
            stage: OcrFlowStage.error,
            errorMessage: 'No text detected in image.',
          );
        case OcrStatus.blocked:
          state = const OcrFlowState(
            stage: OcrFlowStage.error,
            errorMessage: "This image couldn't be processed.",
          );
      }
    } catch (_) {
      _cancelMessageTimers();
      state = const OcrFlowState(
        stage: OcrFlowStage.error,
        errorMessage:
            'Could not process this image. Check your connection and try again.',
      );
    }
  }
}

final ocrFlowProvider =
    NotifierProvider.autoDispose<OcrFlowNotifier, OcrFlowState>(
  OcrFlowNotifier.new,
);

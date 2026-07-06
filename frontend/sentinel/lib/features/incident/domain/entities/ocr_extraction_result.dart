import 'package:flutter/foundation.dart';

enum OcrStatus { ok, noText, blocked }

enum OcrCleanupStatus { ok, failed, skipped }

@immutable
class OcrExtractionResult {
  const OcrExtractionResult({
    required this.ocrStatus,
    required this.ocrText,
    required this.cleanedText,
    required this.cleanupStatus,
    required this.warnings,
  });

  final OcrStatus ocrStatus;
  final String ocrText;
  final String? cleanedText;
  final OcrCleanupStatus cleanupStatus;
  final List<String> warnings;
}

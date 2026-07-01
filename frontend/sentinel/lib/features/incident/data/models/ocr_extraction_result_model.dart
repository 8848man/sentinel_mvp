import '../../domain/entities/ocr_extraction_result.dart';

class OcrExtractionResultModel {
  const OcrExtractionResultModel({
    required this.ocrStatus,
    required this.ocrText,
    required this.cleanedText,
    required this.cleanupStatus,
    required this.warnings,
  });

  final String ocrStatus;
  final String ocrText;
  final String? cleanedText;
  final String cleanupStatus;
  final List<String> warnings;

  factory OcrExtractionResultModel.fromJson(Map<String, dynamic> json) {
    return OcrExtractionResultModel(
      ocrStatus: json['ocr_status'] as String,
      ocrText: json['ocr_text'] as String,
      cleanedText: json['cleaned_text'] as String?,
      cleanupStatus: json['cleanup_status'] as String,
      warnings: (json['warnings'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
    );
  }

  static OcrStatus _ocrStatus(String value) {
    switch (value) {
      case 'no_text':
        return OcrStatus.noText;
      case 'blocked':
        return OcrStatus.blocked;
      default:
        return OcrStatus.ok;
    }
  }

  static OcrCleanupStatus _cleanupStatus(String value) {
    switch (value) {
      case 'failed':
        return OcrCleanupStatus.failed;
      case 'skipped':
        return OcrCleanupStatus.skipped;
      default:
        return OcrCleanupStatus.ok;
    }
  }

  OcrExtractionResult toEntity() => OcrExtractionResult(
        ocrStatus: _ocrStatus(ocrStatus),
        ocrText: ocrText,
        cleanedText: cleanedText,
        cleanupStatus: _cleanupStatus(cleanupStatus),
        warnings: warnings,
      );
}

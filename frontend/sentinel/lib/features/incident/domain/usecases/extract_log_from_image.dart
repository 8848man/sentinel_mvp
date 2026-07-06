import 'dart:typed_data';

import '../entities/ocr_extraction_result.dart';
import '../repositories/incident_repository.dart';

class ExtractLogFromImage {
  const ExtractLogFromImage(this._repository);
  final IncidentRepository _repository;

  Future<OcrExtractionResult> call(Uint8List imageBytes, String filename) =>
      _repository.extractLogFromImage(imageBytes, filename);
}

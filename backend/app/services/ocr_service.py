"""
OCR-assisted Raw Log extraction orchestration.
Spec: sdd/backend/05_1_ocr_api_spec.md, sdd/context/04_1_ocr_log_extraction.md

Fully stateless (OCR3): no DB session, no incident_id, image is never
persisted. Never logs image bytes, ocr_text, or cleaned_text (OCR10).
"""
from app.schemas.ocr import OcrExtractResponse
from app.services import gemini_service
from app.services.image_processing import validate_and_optimize_image


async def extract_log_from_upload(raw_bytes: bytes) -> OcrExtractResponse:
    optimized_bytes, mime_type = validate_and_optimize_image(raw_bytes)

    ocr_result = await gemini_service.extract_log_from_image(optimized_bytes, mime_type)
    ocr_status = ocr_result["status"]
    ocr_text = ocr_result["ocr_text"]

    if ocr_status == "no_text":
        return OcrExtractResponse(
            ocr_status="no_text",
            ocr_text="",
            cleaned_text=None,
            cleanup_status="skipped",
            warnings=["No text detected in image"],
        )

    if ocr_status == "blocked":
        return OcrExtractResponse(
            ocr_status="blocked",
            ocr_text="",
            cleaned_text=None,
            cleanup_status="skipped",
            warnings=["This image couldn't be processed"],
        )

    # ocr_status == "ok" — attempt cleanup; a cleanup failure degrades
    # gracefully (OCR Extraction already succeeded) rather than failing the
    # whole request (sdd/backend/08_1_ocr_ai_integration.md Decisions).
    try:
        cleaned_text = await gemini_service.cleanup_log_text(ocr_text)
        return OcrExtractResponse(
            ocr_status="ok",
            ocr_text=ocr_text,
            cleaned_text=cleaned_text,
            cleanup_status="ok",
            warnings=[],
        )
    except RuntimeError:
        return OcrExtractResponse(
            ocr_status="ok",
            ocr_text=ocr_text,
            cleaned_text=None,
            cleanup_status="failed",
            warnings=["AI cleanup unavailable, showing OCR output only"],
        )

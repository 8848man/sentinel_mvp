"""
OCR-assisted Raw Log extraction schemas.
Spec: sdd/backend/05_1_ocr_api_spec.md
"""
from pydantic import BaseModel
from typing import Literal

OcrStatus = Literal["ok", "no_text", "blocked"]
CleanupStatus = Literal["ok", "failed", "skipped"]


class OcrExtractResponse(BaseModel):
    ocr_status: OcrStatus
    ocr_text: str
    cleaned_text: str | None
    cleanup_status: CleanupStatus
    warnings: list[str] = []

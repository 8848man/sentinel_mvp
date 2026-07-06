"""
OCR-assisted Raw Log extraction endpoint. Spec: sdd/backend/05_1_ocr_api_spec.md
"""
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile

from app.core.auth import get_current_user
from app.schemas.ocr import OcrExtractResponse
from app.services import ocr_service
from app.services.image_processing import (
    ImageTooComplexError,
    ImageTooLargeError,
    UnsupportedImageFormatError,
)

router = APIRouter(tags=["ocr"])


@router.post("/ocr/extract-log", response_model=OcrExtractResponse)
async def extract_log(
    image: UploadFile = File(...),
    target_field: str = Form("raw_log"),
    current_user: dict = Depends(get_current_user),
):
    """
    Spec: POST /ocr/extract-log — stateless OCR + AI cleanup (OCR3, no DB
    write, no incident_id). `target_field` is a forward-compat placeholder
    (OCR8); only "raw_log" is meaningfully supported today.
    """
    raw_bytes = await image.read()

    try:
        return await ocr_service.extract_log_from_upload(raw_bytes)
    except UnsupportedImageFormatError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except ImageTooLargeError as e:
        raise HTTPException(status_code=413, detail=str(e))
    except ImageTooComplexError as e:
        raise HTTPException(status_code=500, detail=str(e))
    except RuntimeError as e:
        raise HTTPException(status_code=500, detail=str(e))

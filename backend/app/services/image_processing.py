"""
Image validation + optimization for OCR-assisted Raw Log extraction.
Spec: sdd/context/04_1_ocr_log_extraction.md (Image Validation / Optimization
Requirements), sdd/backend/08_1_ocr_ai_integration.md (Image Payload Constraints).

Content is content-sniffed via Pillow's own decode (never trusted from
extension/declared MIME), never persisted to disk, and never logged.
"""
from io import BytesIO

from PIL import Image, ImageOps, UnidentifiedImageError
import pillow_heif

pillow_heif.register_heif_opener()

MAX_UPLOAD_BYTES = 20 * 1024 * 1024  # 20 MB, sdd/context/04_1_ocr_log_extraction.md
MAX_PIXELS = 40_000_000  # defensive bound against decompression-bomb-style images
TARGET_MAX_BYTES = 4 * 1024 * 1024  # sdd/backend/08_1_ocr_ai_integration.md
MAX_LONG_EDGE = 2500
ALLOWED_FORMATS = {"JPEG", "PNG", "WEBP", "HEIF"}
_QUALITY_STEPS = (85, 70, 55, 40)


class UnsupportedImageFormatError(Exception):
    """Raised when the decoded image format isn't in ALLOWED_FORMATS."""


class ImageTooLargeError(Exception):
    """Raised when the upload exceeds MAX_UPLOAD_BYTES or MAX_PIXELS."""


class ImageTooComplexError(Exception):
    """Raised when the image still exceeds TARGET_MAX_BYTES after optimization."""


def validate_and_optimize_image(raw_bytes: bytes) -> tuple[bytes, str]:
    """
    Validate + optimize an uploaded image for the OCR pipeline.

    Returns (optimized_jpeg_bytes, mime_type). Never writes the image to disk;
    callers must not log raw_bytes or the returned bytes (OCR10).
    """
    if len(raw_bytes) > MAX_UPLOAD_BYTES:
        raise ImageTooLargeError(f"Image exceeds {MAX_UPLOAD_BYTES} bytes")

    try:
        image = Image.open(BytesIO(raw_bytes))
        image.load()  # force full decode now, not lazily later
    except UnidentifiedImageError:
        raise UnsupportedImageFormatError("Could not decode image")
    except Image.DecompressionBombError:
        raise ImageTooLargeError("Image dimensions too large to process")

    if image.format not in ALLOWED_FORMATS:
        raise UnsupportedImageFormatError(f"Unsupported image format: {image.format}")

    if image.width * image.height > MAX_PIXELS:
        raise ImageTooLargeError("Image dimensions too large to process")

    # EXIF orientation normalization MUST happen before resize (04_1, Image
    # Optimization Requirements) — exif_transpose rotates pixels to upright
    # and drops the orientation tag; re-saving below (without an exif= kwarg)
    # drops all other EXIF (including GPS) as a side effect.
    image = ImageOps.exif_transpose(image)

    if image.mode not in ("RGB", "L"):
        image = image.convert("RGB")

    if max(image.width, image.height) > MAX_LONG_EDGE:
        image.thumbnail((MAX_LONG_EDGE, MAX_LONG_EDGE), Image.LANCZOS)

    for quality in _QUALITY_STEPS:
        buffer = BytesIO()
        image.save(buffer, format="JPEG", quality=quality)
        encoded = buffer.getvalue()
        if len(encoded) <= TARGET_MAX_BYTES:
            return encoded, "image/jpeg"

    raise ImageTooComplexError("Image too complex to process after optimization")

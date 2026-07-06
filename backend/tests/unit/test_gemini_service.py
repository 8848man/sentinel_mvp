"""Unit tests for gemini_service.

Mocks _model.generate_content_async to prevent real API calls.
Tests generate(), extract_metadata(), and _parse_json().
"""
import asyncio
import json
import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from app.services import gemini_service


def _mock_response(text: str):
    """Build a minimal fake Gemini response object."""
    resp = MagicMock()
    resp.text = text
    return resp


# ── generate() ────────────────────────────────────────────────────────────────


async def test_generate_returns_text_on_success():
    resp = _mock_response("hello world")
    with patch.object(gemini_service._model, "generate_content_async", new=AsyncMock(return_value=resp)):
        result = await gemini_service.generate("prompt text", timeout=5)
    assert result == "hello world"


async def test_generate_strips_whitespace():
    resp = _mock_response("  trimmed  ")
    with patch.object(gemini_service._model, "generate_content_async", new=AsyncMock(return_value=resp)):
        result = await gemini_service.generate("prompt", timeout=5)
    assert result == "trimmed"


async def test_generate_raises_on_empty_response():
    resp = _mock_response("")
    with patch.object(gemini_service._model, "generate_content_async", new=AsyncMock(return_value=resp)):
        with pytest.raises(RuntimeError, match="empty response"):
            await gemini_service.generate("prompt", timeout=5)


async def test_generate_raises_on_timeout():
    async def _slow(*args, **kwargs):
        await asyncio.sleep(999)

    with patch.object(gemini_service._model, "generate_content_async", new=_slow):
        with pytest.raises(RuntimeError, match="timeout"):
            await gemini_service.generate("prompt", timeout=0.001)


# ── extract_metadata() ────────────────────────────────────────────────────────


async def test_extract_metadata_parses_valid_json():
    payload = {
        "suggested_title": "DB crash",
        "suggested_severity": "critical",
        "detected_components": ["PostgreSQL"],
        "description": "DB down",
    }
    resp = _mock_response(json.dumps(payload))
    with patch.object(gemini_service._model, "generate_content_async", new=AsyncMock(return_value=resp)):
        result = await gemini_service.extract_metadata("ERROR: db crash")
    assert result["suggested_title"] == "DB crash"
    assert result["detected_components"] == ["PostgreSQL"]


async def test_extract_metadata_parses_code_fenced_json():
    payload = {"suggested_title": "Test", "suggested_severity": "minor",
               "detected_components": [], "description": "x"}
    fenced = f"```json\n{json.dumps(payload)}\n```"
    resp = _mock_response(fenced)
    with patch.object(gemini_service._model, "generate_content_async", new=AsyncMock(return_value=resp)):
        result = await gemini_service.extract_metadata("some log")
    assert result["suggested_title"] == "Test"


async def test_extract_metadata_raises_on_invalid_json():
    resp = _mock_response("not json at all")
    with patch.object(gemini_service._model, "generate_content_async", new=AsyncMock(return_value=resp)):
        with pytest.raises(RuntimeError, match="invalid JSON"):
            await gemini_service.extract_metadata("log text")


async def test_extract_metadata_raises_on_timeout():
    async def _slow(*args, **kwargs):
        await asyncio.sleep(999)

    with patch.object(gemini_service._model, "generate_content_async", new=_slow):
        with pytest.raises(RuntimeError, match="timeout"):
            await gemini_service.extract_metadata("log text")


# ── _parse_json() ─────────────────────────────────────────────────────────────


def test_parse_json_plain():
    result = gemini_service._parse_json('{"key": "value"}')
    assert result == {"key": "value"}


def test_parse_json_code_fenced():
    result = gemini_service._parse_json('```json\n{"key": "value"}\n```')
    assert result == {"key": "value"}


def test_parse_json_code_fenced_no_lang():
    result = gemini_service._parse_json('```\n{"key": "value"}\n```')
    assert result == {"key": "value"}


def test_parse_json_invalid_raises():
    import json as _json
    with pytest.raises(_json.JSONDecodeError):
        gemini_service._parse_json("not json")

"""
Unit tests for app/core/auth.py — validator composition.

Tests cover:
  - _select_validator() routing by iss claim
  - _validate_dev_token() guard enforcement and error responses
"""
import time

import jwt
import pytest

from app.core.auth import _select_validator, _validate_dev_token, _validate_supabase_token

_DEV_SECRET = "test-dev-secret"
_AUD = "authenticated"
_ISS_DEV = "sentinel-dev"


def _make_dev_token(
    *,
    iss: str = _ISS_DEV,
    aud: str = _AUD,
    exp_offset: int = 3600,
    secret: str = _DEV_SECRET,
) -> str:
    now = int(time.time())
    return jwt.encode(
        {"sub": "test-user-id", "email": "dev@test.com", "iss": iss, "aud": aud,
         "iat": now, "exp": now + exp_offset},
        secret,
        algorithm="HS256",
    )


def _make_token_no_iss(secret: str = _DEV_SECRET) -> str:
    now = int(time.time())
    return jwt.encode(
        {"sub": "test-user-id", "aud": _AUD, "iat": now, "exp": now + 3600},
        secret,
        algorithm="HS256",
    )


# ── _select_validator ────────────────────────────────────────────────────────

class TestSelectValidator:
    def test_dev_iss_routes_to_dev_validator(self):
        token = _make_dev_token(iss=_ISS_DEV)
        assert _select_validator(token) is _validate_dev_token

    def test_other_iss_routes_to_supabase_validator(self):
        token = _make_dev_token(iss="https://project.supabase.co")
        assert _select_validator(token) is _validate_supabase_token

    def test_missing_iss_routes_to_supabase_validator(self):
        token = _make_token_no_iss()
        assert _select_validator(token) is _validate_supabase_token

    def test_malformed_token_routes_to_supabase_validator(self):
        assert _select_validator("not.a.token") is _validate_supabase_token

    def test_empty_string_routes_to_supabase_validator(self):
        assert _select_validator("") is _validate_supabase_token


# ── _validate_dev_token ──────────────────────────────────────────────────────

class TestValidateDevToken:
    @pytest.fixture(autouse=True)
    def enable_dev_auth(self, monkeypatch):
        """Enable dev auth and set the expected secret for all tests in this class."""
        from app.core import auth as auth_module
        from app.core.config import settings
        monkeypatch.setattr(settings, "ENABLE_DEV_AUTH", True)
        monkeypatch.setattr(settings, "APP_ENV", "development")
        monkeypatch.setattr(settings, "DEV_JWT_SECRET", _DEV_SECRET)

    async def test_valid_token_returns_identity(self):
        token = _make_dev_token()
        result = await _validate_dev_token(token)
        assert result["user_id"] == "test-user-id"
        assert result["email"] == "dev@test.com"

    async def test_raises_403_when_dev_auth_disabled(self, monkeypatch):
        from app.core.config import settings
        from fastapi import HTTPException
        monkeypatch.setattr(settings, "ENABLE_DEV_AUTH", False)
        token = _make_dev_token()
        with pytest.raises(HTTPException) as exc:
            await _validate_dev_token(token)
        assert exc.value.status_code == 403
        assert exc.value.detail == "Dev auth is disabled"

    async def test_raises_403_in_production(self, monkeypatch):
        from app.core.config import settings
        from fastapi import HTTPException
        monkeypatch.setattr(settings, "APP_ENV", "production")
        token = _make_dev_token()
        with pytest.raises(HTTPException) as exc:
            await _validate_dev_token(token)
        assert exc.value.status_code == 403
        assert exc.value.detail == "Dev auth is disabled"

    async def test_raises_401_on_expired_token(self):
        from fastapi import HTTPException
        token = _make_dev_token(exp_offset=-1)
        with pytest.raises(HTTPException) as exc:
            await _validate_dev_token(token)
        assert exc.value.status_code == 401
        assert exc.value.detail == "Token expired"

    async def test_raises_401_on_wrong_secret(self):
        from fastapi import HTTPException
        token = _make_dev_token(secret="wrong-secret")
        with pytest.raises(HTTPException) as exc:
            await _validate_dev_token(token)
        assert exc.value.status_code == 401
        assert exc.value.detail == "Invalid token"

    async def test_raises_401_on_wrong_audience(self):
        from fastapi import HTTPException
        token = _make_dev_token(aud="wrong-audience")
        with pytest.raises(HTTPException) as exc:
            await _validate_dev_token(token)
        assert exc.value.status_code == 401
        assert exc.value.detail == "Invalid token"

    async def test_email_optional_returns_none_when_absent(self, monkeypatch):
        from app.core.config import settings
        now = int(time.time())
        token = jwt.encode(
            {"sub": "test-user-id", "aud": _AUD, "iss": _ISS_DEV,
             "iat": now, "exp": now + 3600},
            _DEV_SECRET,
            algorithm="HS256",
        )
        result = await _validate_dev_token(token)
        assert result["user_id"] == "test-user-id"
        assert result["email"] is None

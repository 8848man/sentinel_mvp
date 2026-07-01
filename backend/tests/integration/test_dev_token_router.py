"""
Integration tests for POST /api/v1/dev/token.

Tests cover:
  - 200 response with valid token when user exists
  - Issued token is a valid HS256 JWT with correct claims
  - 404 when user not found
  - Route does not exist (404) when ENABLE_DEV_AUTH=False
"""
import time

import jwt
import pytest
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.models import User, _user_id_for

_DEV_SECRET = "integration-test-dev-secret"
_TEST_EMAIL = "dev@sentinel.ai"
_TEST_PASSWORD = "Dev1234!"


@pytest.fixture
def dev_app(monkeypatch):
    """FastAPI app with ENABLE_DEV_AUTH=True and a fixed dev secret."""
    monkeypatch.setattr(settings, "ENABLE_DEV_AUTH", True)
    monkeypatch.setattr(settings, "APP_ENV", "development")
    monkeypatch.setattr(settings, "DEV_JWT_SECRET", _DEV_SECRET)
    from app.main import create_app
    return create_app()


@pytest.fixture
async def dev_client(dev_app):
    async with AsyncClient(
        transport=ASGITransport(app=dev_app),
        base_url="http://test/api/v1",
    ) as c:
        yield c


@pytest.fixture
async def registered_user(db: AsyncSession):
    """Insert a User row matching _TEST_EMAIL."""
    user = User(
        user_id=_user_id_for(_TEST_EMAIL),
        email=_TEST_EMAIL,
        password=_TEST_PASSWORD,
    )
    async with db.begin():
        db.add(user)
    yield user


# ── Happy path ────────────────────────────────────────────────────────────────

class TestDevTokenHappyPath:
    async def test_returns_200(self, dev_client, registered_user):
        r = await dev_client.post("/dev/token", json={"email": _TEST_EMAIL})
        assert r.status_code == 200

    async def test_response_has_required_fields(self, dev_client, registered_user):
        r = await dev_client.post("/dev/token", json={"email": _TEST_EMAIL})
        body = r.json()
        assert "access_token" in body
        assert body["token_type"] == "bearer"
        assert body["expires_in"] == 86400

    async def test_issued_token_is_valid_hs256(self, dev_client, registered_user):
        r = await dev_client.post("/dev/token", json={"email": _TEST_EMAIL})
        token = r.json()["access_token"]
        payload = jwt.decode(
            token,
            _DEV_SECRET,
            algorithms=["HS256"],
            audience="authenticated",
        )
        assert payload["iss"] == "sentinel-dev"
        assert payload["email"] == _TEST_EMAIL
        assert payload["aud"] == "authenticated"
        assert payload["sub"] == _user_id_for(_TEST_EMAIL)

    async def test_token_expires_in_24h(self, dev_client, registered_user):
        before = int(time.time())
        r = await dev_client.post("/dev/token", json={"email": _TEST_EMAIL})
        token = r.json()["access_token"]
        payload = jwt.decode(
            token, _DEV_SECRET, algorithms=["HS256"], audience="authenticated"
        )
        assert payload["exp"] - payload["iat"] == 86400
        assert payload["iat"] >= before

    async def test_email_normalised_to_lowercase(self, dev_client, registered_user):
        r = await dev_client.post("/dev/token", json={"email": _TEST_EMAIL.upper()})
        assert r.status_code == 200
        body = r.json()
        payload = jwt.decode(
            body["access_token"], _DEV_SECRET, algorithms=["HS256"], audience="authenticated"
        )
        assert payload["email"] == _TEST_EMAIL


# ── Error cases ───────────────────────────────────────────────────────────────

class TestDevTokenErrors:
    async def test_user_not_found_returns_404(self, dev_client):
        r = await dev_client.post("/dev/token", json={"email": "nobody@nowhere.com"})
        assert r.status_code == 404
        assert r.json()["detail"] == "User not found"

    async def test_route_absent_when_dev_auth_disabled(self, monkeypatch):
        """When ENABLE_DEV_AUTH=False, the route is not registered — expect 404."""
        monkeypatch.setattr(settings, "ENABLE_DEV_AUTH", False)
        monkeypatch.setattr(settings, "APP_ENV", "development")
        from app.main import create_app
        disabled_app = create_app()
        async with AsyncClient(
            transport=ASGITransport(app=disabled_app),
            base_url="http://test/api/v1",
        ) as c:
            r = await c.post("/dev/token", json={"email": _TEST_EMAIL})
        assert r.status_code == 404


# ── Password verification ─────────────────────────────────────────────────────

class TestDevTokenPasswordVerification:
    async def test_correct_password_returns_200(self, dev_client, registered_user):
        r = await dev_client.post(
            "/dev/token", json={"email": _TEST_EMAIL, "password": _TEST_PASSWORD}
        )
        assert r.status_code == 200

    async def test_wrong_password_returns_401(self, dev_client, registered_user):
        r = await dev_client.post(
            "/dev/token", json={"email": _TEST_EMAIL, "password": "wrong-password"}
        )
        assert r.status_code == 401
        assert r.json()["detail"] == "Invalid credentials"

    async def test_omitted_password_returns_200(self, dev_client, registered_user):
        """Password is optional — omitting it issues a token without checking."""
        r = await dev_client.post("/dev/token", json={"email": _TEST_EMAIL})
        assert r.status_code == 200

    async def test_null_password_returns_200(self, dev_client, registered_user):
        """Explicit null is equivalent to omitted — no verification."""
        r = await dev_client.post(
            "/dev/token", json={"email": _TEST_EMAIL, "password": None}
        )
        assert r.status_code == 200


# ── Token round-trip: issued token accepted by get_current_user ───────────────

class TestDevTokenRoundTrip:
    async def test_issued_token_passes_get_current_user(
        self, dev_client, registered_user, monkeypatch
    ):
        """The token issued by dev/token must be accepted by the auth validator."""
        r = await dev_client.post("/dev/token", json={"email": _TEST_EMAIL})
        token = r.json()["access_token"]

        from app.core.auth import get_current_user
        from fastapi.security import HTTPAuthorizationCredentials
        creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)
        identity = await get_current_user(creds)
        assert identity["user_id"] == _user_id_for(_TEST_EMAIL)
        assert identity["email"] == _TEST_EMAIL

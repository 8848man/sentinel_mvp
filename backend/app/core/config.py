from typing import Optional
from pydantic_settings import BaseSettings
from pydantic import field_validator

class Settings(BaseSettings):
    APP_ENV: str = "development"
    DATABASE_URL: Optional[str] = None
    MIGRATION_DATABASE_URL: str | None = None

    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-2.0-flash"
    GEMINI_TIMEOUT_SECONDS: int = 15

    # Dedicated timeout for OCR image-to-text extraction only — multimodal OCR
    # on dense screenshots takes meaningfully longer than the text-only
    # metadata/analysis calls that GEMINI_TIMEOUT_SECONDS covers.
    OCR_TIMEOUT_SECONDS: int = 60

    # Timeout for full incident analysis (background worker). Much larger than
    # GEMINI_TIMEOUT_SECONDS because large logs take longer to process.
    ANALYSIS_TIMEOUT_SECONDS: int = 120

    # Maximum characters sent to Gemini for analysis. Logs exceeding this are
    # truncated via head+tail strategy before the API call.
    MAX_ANALYSIS_INPUT_CHARS: int = 30000

    ALLOWED_ORIGINS_STR: str = ""  # CSV로 받아오고

    @property
    def ALLOWED_ORIGINS(self) -> list[str]:  # list로 바꾸는 메소드
        if not self.ALLOWED_ORIGINS_STR:
            return []
        return [o.strip() for o in self.ALLOWED_ORIGINS_STR.split(",")]

    # Supabase project URL — used to derive the JWKS endpoint for JWT verification.
    # Format: https://<ref>.supabase.co  (no trailing slash, no path)
    # Found in: Supabase Dashboard → Project Settings → API → Project URL
    SUPABASE_URL: str = ""

    # Set to False in production to enforce full email verification on sign-up.
    # When False, the dev-only POST /api/v1/auth/register endpoint returns 403.
    SKIP_EMAIL_VERIFICATION: bool = True

    # ── Development authentication (dev-only — must NOT be set in production) ──
    # When True, enables POST /api/v1/dev/token and the HS256 validation path.
    # Must never appear in Cloud Run config, Secret Manager, or any prod artifact.
    ENABLE_DEV_AUTH: bool = False
    DEV_JWT_SECRET: str = "dev-insecure-local-secret-change-me"

    @property
    def resolved_database_url(self) -> str:
        if self.DATABASE_URL:
            return self.DATABASE_URL
        if self.APP_ENV == "production":
            raise ValueError("DATABASE_URL must be explicitly set in production")
        return "sqlite+aiosqlite:///./sentinel_dev.db"

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()

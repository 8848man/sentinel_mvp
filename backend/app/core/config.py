from typing import Optional
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    APP_ENV: str = "development"
    DATABASE_URL: Optional[str] = None
    SUPABASE_JWT_SECRET: str = "dev-insecure-secret-change-in-production"
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-2.0-flash"
    GEMINI_TIMEOUT_SECONDS: int = 15
    ALLOWED_ORIGINS: list[str] = ["http://localhost:3000", "http://localhost:5173"]
    # Set to False in production to enforce full email verification on sign-up.
    SKIP_EMAIL_VERIFICATION: bool = True

    @property
    def resolved_database_url(self) -> str:
        if self.DATABASE_URL:
            return self.DATABASE_URL
        if self.APP_ENV == "production":
            raise ValueError("DATABASE_URL must be explicitly set in production")
        return "sqlite+aiosqlite:///./sentinel_dev.db"

    class Config:
        env_file = ".env"


settings = Settings()

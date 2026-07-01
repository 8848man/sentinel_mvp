"""
Root conftest.py — sets environment variables BEFORE any app.* modules are imported.

This file is loaded by pytest before any test collection occurs, ensuring that
module-level singletons (settings, engine, AsyncSessionFactory, _jwks_client)
are created with test-safe values rather than production defaults.
"""
import os

os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///./test_sentinel.db")
os.environ.setdefault("SUPABASE_URL", "https://test.supabase.co")
os.environ.setdefault("GEMINI_API_KEY", "test-gemini-key")
os.environ.setdefault("ANALYSIS_TIMEOUT_SECONDS", "5")
os.environ.setdefault("GEMINI_TIMEOUT_SECONDS", "5")
os.environ.setdefault("MAX_ANALYSIS_INPUT_CHARS", "1000")

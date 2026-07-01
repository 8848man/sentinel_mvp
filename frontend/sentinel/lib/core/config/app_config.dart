enum AuthProviderMode { mock, supabase, dev }

class AppConfig {
  AppConfig._();

  /// Legacy mock-data flag. Set to false to connect to Supabase + backend API.
  /// Override at build time: --dart-define=USE_MOCK_DATA=false
  static const bool useMockData =
      bool.fromEnvironment('USE_MOCK_DATA', defaultValue: true);

  /// When true, sign-up skips the email verification code step.
  /// Defaults to true for local/dev builds; set false for production.
  /// Override at build time: --dart-define=SKIP_EMAIL_VERIFICATION=false
  static const bool skipEmailVerification =
      bool.fromEnvironment('SKIP_EMAIL_VERIFICATION', defaultValue: true);

  // ── Auth provider selection ──────────────────────────────────────────────────
  // The canonical authentication flow is:
  //   Flutter → Supabase Auth → obtain access token → attach to FastAPI calls
  //
  // FastAPI does NOT issue tokens; it only verifies Supabase-issued JWTs.
  //
  // Values: 'supabase' (default) | 'mock' | 'dev'
  //
  // supabase — production/staging: requires SUPABASE_URL and SUPABASE_ANON_KEY
  // mock     — UI-only development: no backend, no network
  // dev      — local full-stack: Flutter + local FastAPI + SQLite (requires ENABLE_DEV_AUTH=True on backend)
  static const String _authProviderEnv =
      String.fromEnvironment('AUTH_PROVIDER', defaultValue: 'supabase');

  static AuthProviderMode get authProvider => switch (_authProviderEnv) {
        'mock' => AuthProviderMode.mock,
        'dev' => AuthProviderMode.dev,
        _ => AuthProviderMode.supabase,
      };
}

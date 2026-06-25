enum AuthProviderMode { mock, localBackend, supabase }

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
  // Values: 'supabase' (default) | 'mock' | 'localBackend' (deprecated)
  //
  // Requires at build time:
  //   --dart-define=SUPABASE_URL=https://<project>.supabase.co
  //   --dart-define=SUPABASE_ANON_KEY=<anon-key>
  //
  // Override: --dart-define=AUTH_PROVIDER=mock  (for UI-only development)
  static const String _authProviderEnv =
      String.fromEnvironment('AUTH_PROVIDER', defaultValue: 'supabase');

  static AuthProviderMode get authProvider => switch (_authProviderEnv) {
        'localBackend' => AuthProviderMode.localBackend,
        'mock' => AuthProviderMode.mock,
        _ => AuthProviderMode.supabase,
      };
}

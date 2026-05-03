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
  // Values: 'mock' | 'localBackend' | 'supabase'
  // Override at build time: --dart-define=AUTH_PROVIDER=supabase
  static const String _authProviderEnv =
      String.fromEnvironment('AUTH_PROVIDER', defaultValue: 'mock');

  static AuthProviderMode get authProvider => switch (_authProviderEnv) {
        'localBackend' => AuthProviderMode.localBackend,
        'supabase' => AuthProviderMode.supabase,
        _ => AuthProviderMode.mock,
      };

  /// Base URL of the locally-running FastAPI backend (used in localBackend mode).
  /// Override at build time: --dart-define=BACKEND_BASE_URL=http://10.0.2.2:8000
  static const String backendBaseUrl =
      String.fromEnvironment('BACKEND_BASE_URL', defaultValue: 'http://localhost:8000');
}

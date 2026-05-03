class AppConfig {
  AppConfig._();

  /// Set to false to switch to the real Supabase + backend API.
  /// Override at build time: --dart-define=USE_MOCK_DATA=false
  static const bool useMockData =
      bool.fromEnvironment('USE_MOCK_DATA', defaultValue: true);

  /// When true, the sign-up screen skips the email verification code step.
  /// Defaults to true for local/dev builds; set false for production.
  /// Override at build time: --dart-define=SKIP_EMAIL_VERIFICATION=false
  static const bool skipEmailVerification =
      bool.fromEnvironment('SKIP_EMAIL_VERIFICATION', defaultValue: true);
}

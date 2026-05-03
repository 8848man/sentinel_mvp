class AppConfig {
  AppConfig._();

  /// Set to false to switch to the real Supabase + backend API.
  /// Can also be overridden via --dart-define=USE_MOCK_DATA=false at build time.
  static const bool useMockData =
      bool.fromEnvironment('USE_MOCK_DATA', defaultValue: true);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/core/config/app_config.dart';

void main() {
  test(
    'AppConfig.validate() fails fast when AUTH_PROVIDER=supabase (default) '
    'and SUPABASE_URL/SUPABASE_ANON_KEY are not supplied',
    () {
      // Run with no --dart-define, matching what happens if a supabase build/run
      // forgets to pass the required flags: authProvider defaults to supabase and
      // supabaseUrl/supabaseAnonKey default to empty strings.
      expect(AppConfig.authProvider, AuthProviderMode.supabase);
      expect(AppConfig.supabaseUrl, isEmpty);

      expect(
        () => AppConfig.validate(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('SUPABASE_URL'), contains('SUPABASE_ANON_KEY')),
          ),
        ),
      );
    },
  );
}

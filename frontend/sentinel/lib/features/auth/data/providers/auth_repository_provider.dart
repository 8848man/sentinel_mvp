import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_endpoints.dart';
import '../../../../core/config/app_config.dart';
import '../../domain/repositories/auth_repository.dart';
import '../repositories/local_backend_auth_repository.dart';
import '../repositories/mock_auth_repository.dart';
import '../repositories/supabase_auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return switch (AppConfig.authProvider) {
    AuthProviderMode.mock => MockAuthRepository(),
    AuthProviderMode.localBackend => LocalBackendAuthRepository(
        baseUrl: ApiEndpoints.base,
      ),
    AuthProviderMode.supabase => SupabaseAuthRepository(),
  };
});

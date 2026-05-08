import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import 'api_endpoints.dart';

final apiClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiEndpoints.base,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _resolveToken(ref);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ),
  );

  return dio;
});

Future<String?> _resolveToken(Ref ref) async {
  // Supabase needs its own path to handle token refresh before reading.
  if (AppConfig.authProvider == AuthProviderMode.supabase) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null && session.isExpired) {
      try {
        await Supabase.instance.client.auth.refreshSession();
      } catch (_) {}
    }
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  // For all other modes (localBackend, mock), read the token from the
  // canonical auth state. Previously, mock mode returned null unconditionally,
  // which caused FastAPI's HTTPBearer to return 403 "Not authenticated" even
  // for authenticated users when USE_MOCK_DATA=false.
  return ref.read(authProvider).user?.accessToken;
}

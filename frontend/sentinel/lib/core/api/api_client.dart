import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../../features/auth/data/providers/auth_repository_provider.dart';
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
  switch (AppConfig.authProvider) {
    case AuthProviderMode.localBackend:
      final user = await ref.read(authRepositoryProvider).getSignedInUser();
      return user?.accessToken;
    case AuthProviderMode.supabase:
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && session.isExpired) {
        try {
          await Supabase.instance.client.auth.refreshSession();
        } catch (_) {}
      }
      return Supabase.instance.client.auth.currentSession?.accessToken;
    case AuthProviderMode.mock:
      return null;
  }
}

import 'dart:async';

import 'package:dio/dio.dart';

import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Calls the locally-running FastAPI backend for authentication.
/// Both endpoints require SKIP_EMAIL_VERIFICATION=true on the backend (returns 403 otherwise).
/// OTP-based sign-up is not supported in this mode.
class LocalBackendAuthRepository implements AuthRepository {
  LocalBackendAuthRepository({required String baseUrl})
      : _dio = Dio(BaseOptions(baseUrl: baseUrl));

  final Dio _dio;
  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;

  @override
  Future<AuthUser?> getSignedInUser() async => _currentUser;

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  Future<AuthUser> signIn(String email, String password) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/login',
        data: {'email': email.trim(), 'password': password},
      );
      return _setUser(_fromJson(r.data!));
    } on DioException catch (e) {
      throw Exception(_dioMessage(e));
    }
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }

  @override
  Future<AuthUser> registerDirect(String email, String password) async {
    try {
      await _dio.post<void>(
        '/api/v1/auth/register',
        data: {'email': email.trim(), 'password': password},
      );
      return signIn(email, password);
    } on DioException catch (e) {
      throw Exception(_dioMessage(e));
    }
  }

  @override
  Future<void> sendSignUpCode(String email, String password) =>
      throw UnsupportedError('OTP sign-up is not supported in local backend mode.');

  @override
  Future<AuthUser> verifySignUp(String email, String code) =>
      throw UnsupportedError('OTP sign-up is not supported in local backend mode.');

  AuthUser _fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['user_id'] as String,
        email: json['email'] as String,
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String? ?? '',
      );

  AuthUser _setUser(AuthUser user) {
    _currentUser = user;
    _controller.add(user);
    return user;
  }

  String _dioMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data.containsKey('detail')) return data['detail'] as String;
    return e.message ?? 'Network error';
  }
}

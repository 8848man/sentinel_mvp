import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

// Dev-only repository. Calls POST /api/v1/dev/token to obtain a real HS256 JWT.
// Requires AUTH_PROVIDER=dev and ENABLE_DEV_AUTH=True on the backend.
// Not for production use.
class DevAuthRepository implements AuthRepository {
  DevAuthRepository({required String baseUrl}) : _baseUrl = baseUrl;

  final String _baseUrl;
  final _dio = Dio();
  final _controller = StreamController<AuthUser?>.broadcast();

  AuthUser? _currentUser;
  String? _accessToken;

  @override
  Future<AuthUser> signIn(String email, String password) async {
    try {
      final r = await _dio.post(
        '$_baseUrl/api/v1/dev/token',
        data: {'email': email, 'password': password},
      );
      return _setUser(email, r.data['access_token'] as String);
    } on DioException catch (e) {
      final detail = e.response?.data['detail'] ?? 'Sign-in failed';
      throw Exception(detail);
    }
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _accessToken = null;
    _controller.add(null);
  }

  @override
  Future<AuthUser?> getSignedInUser() async => _currentUser;

  @override
  Future<String?> getAccessToken() async => _accessToken;

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  Future<AuthUser> registerDirect(String email, String password) async {
    try {
      await _dio.post(
        '$_baseUrl/api/v1/auth/register',
        data: {'email': email, 'password': password},
      );
    } on DioException catch (e) {
      // 409 = user already exists — proceed to sign in
      if (e.response?.statusCode != 409) {
        final detail = e.response?.data['detail'] ?? 'Registration failed';
        throw Exception(detail);
      }
    }
    return signIn(email, password);
  }

  @override
  Future<void> sendSignUpCode(String email, String password) async {
    throw Exception('Not supported in dev mode — use registerDirect()');
  }

  @override
  Future<AuthUser> verifySignUp(String email, String code) async {
    throw Exception('Not supported in dev mode — use registerDirect()');
  }

  String _subFromToken(String token) {
    final parts = token.split('.');
    final padded = base64Url.normalize(parts[1]);
    final payload = jsonDecode(utf8.decode(base64Url.decode(padded))) as Map;
    return payload['sub'] as String;
  }

  AuthUser _setUser(String email, String accessToken) {
    _accessToken = accessToken;
    final user = AuthUser(
      id: _subFromToken(accessToken),
      email: email,
      accessToken: accessToken,
      refreshToken: '',
    );
    _currentUser = user;
    _controller.add(user);
    return user;
  }
}

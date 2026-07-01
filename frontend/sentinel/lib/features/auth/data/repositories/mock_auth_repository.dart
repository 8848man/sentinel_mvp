import 'dart:async';

import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../mocks/mock_auth_accounts.dart';

// Mock tokens are opaque strings, not JWTs. USE_MOCK_DATA=false is not supported with this repository.
class MockAuthRepository implements AuthRepository {
  final Map<String, String> _pendingSignUps = {};
  final Map<String, String> _directRegistrations = {};
  final _controller = StreamController<AuthUser?>.broadcast();

  AuthUser? _currentUser;

  @override
  Future<AuthUser?> getSignedInUser() async => _currentUser;

  @override
  Future<String?> getAccessToken() async => _currentUser?.accessToken;

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  Future<AuthUser> signIn(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final account = kMockAuthAccounts.where((a) => a.email == email.trim()).firstOrNull;
    if (account == null || account.password != password) {
      throw Exception('Invalid login credentials');
    }
    return _setUser(AuthUser(
      id: account.userId,
      email: account.email,
      accessToken: account.accessToken,
      refreshToken: account.refreshToken,
    ));
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }

  @override
  Future<AuthUser> registerDirect(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final normalized = email.trim().toLowerCase();
    final isDuplicate = kMockAuthAccounts.any((a) => a.email == normalized) ||
        _directRegistrations.containsKey(normalized);
    if (isDuplicate) throw Exception('An account with this email already exists.');
    _directRegistrations[normalized] = password;
    return _setUser(AuthUser(
      id: 'mock-user-${DateTime.now().millisecondsSinceEpoch}',
      email: normalized,
      accessToken: 'mock.access.$normalized',
      refreshToken: 'mock.refresh.$normalized',
    ));
  }

  @override
  Future<void> sendSignUpCode(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _pendingSignUps[email.trim()] = password;
  }

  @override
  Future<AuthUser> verifySignUp(String email, String code) async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!_pendingSignUps.containsKey(email.trim())) {
      throw Exception('No pending sign-up for this email.');
    }
    final account = kMockAuthAccounts.where((a) => a.email == email.trim()).firstOrNull;
    if (account == null || account.otpCode != code.trim()) {
      throw Exception('Invalid or expired verification code');
    }
    _pendingSignUps.remove(email.trim());
    return _setUser(AuthUser(
      id: account.userId,
      email: account.email,
      accessToken: account.accessToken,
      refreshToken: account.refreshToken,
    ));
  }

  AuthUser _setUser(AuthUser user) {
    _currentUser = user;
    _controller.add(user);
    return user;
  }
}

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  final _client = supa.Supabase.instance.client;
  final _controller = StreamController<AuthUser?>.broadcast();

  SupabaseAuthRepository() {
    _client.auth.onAuthStateChange.listen((data) {
      final s = data.session;
      _controller.add(s != null ? _fromSession(s) : null);
    });
  }

  AuthUser _fromSession(supa.Session s) => AuthUser(
        id: s.user.id,
        email: s.user.email ?? '',
        accessToken: s.accessToken,
        refreshToken: s.refreshToken ?? '',
      );

  @override
  Future<AuthUser?> getSignedInUser() async {
    final s = _client.auth.currentSession;
    if (s == null || s.isExpired) return null;
    return _fromSession(s);
  }

  @override
  Future<String?> getAccessToken() async {
    final s = _client.auth.currentSession;
    if (s == null) return null;
    if (s.isExpired) {
      try {
        await _client.auth.refreshSession();
      } catch (_) {
        await signOut();
        return null;
      }
    }
    return _client.auth.currentSession?.accessToken;
  }

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  Future<AuthUser> signIn(String email, String password) async {
    try {
      final r = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return _fromSession(r.session!);
    } on supa.AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on supa.AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  @override
  Future<AuthUser> registerDirect(String email, String password) async {
    try {
      final r = await _client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      if (r.session == null) {
        throw Exception(
          'Email confirmation is still enabled in Supabase. '
          'Disable it under Authentication → Providers → Email.',
        );
      }
      return _fromSession(r.session!);
    } on supa.AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  @override
  Future<void> sendSignUpCode(String email, String password) async {
    try {
      await _client.auth.signUp(email: email.trim(), password: password);
    } on supa.AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  @override
  Future<AuthUser> verifySignUp(String email, String code) async {
    try {
      final r = await _client.auth.verifyOTP(
        email: email.trim(),
        token: code.trim(),
        type: supa.OtpType.signup,
      );
      return _fromSession(r.session!);
    } on supa.AuthException catch (e) {
      throw Exception(e.message);
    }
  }
}

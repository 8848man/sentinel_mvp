import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../../../core/config/app_config.dart';
import '../../data/datasources/auth_mock_datasource.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

@immutable
class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.isLoading = false,
    this.error,
  });

  final AuthStatus status;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({AuthStatus? status, bool? isLoading, String? error}) {
    return AuthState(
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  // Lazily instantiated — only used in mock mode.
  AuthMockDatasource? _mock;
  AuthMockDatasource get _mockDatasource => _mock ??= AuthMockDatasource();

  @override
  AuthState build() {
    if (AppConfig.useMockData) {
      // Mock mode: always start unauthenticated so the login screen is shown.
      return const AuthState(status: AuthStatus.unauthenticated);
    }

    // Real mode: check existing Supabase session.
    final session = Supabase.instance.client.auth.currentSession;
    final initialStatus = (session != null && !session.isExpired)
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      switch (data.event) {
        case AuthChangeEvent.signedIn:
          state = state.copyWith(status: AuthStatus.authenticated);
        case AuthChangeEvent.signedOut:
        case AuthChangeEvent.tokenRefreshed when data.session == null:
          state = state.copyWith(status: AuthStatus.unauthenticated);
        default:
          break;
      }
    });

    return AuthState(status: initialStatus);
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (AppConfig.useMockData) {
        await _mockDatasource.signIn(email, password);
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
      }
      state = state.copyWith(isLoading: false, status: AuthStatus.authenticated);
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Step 1: create account and trigger OTP email.
  Future<void> sendSignUpCode(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (AppConfig.useMockData) {
        await _mockDatasource.sendSignUpCode(email, password);
      } else {
        await Supabase.instance.client.auth.signUp(
          email: email.trim(),
          password: password,
        );
      }
      state = state.copyWith(isLoading: false);
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Step 2: verify OTP and complete sign-up.
  Future<void> verifySignUp(String email, String token) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (AppConfig.useMockData) {
        await _mockDatasource.verifySignUp(email, token);
      } else {
        await Supabase.instance.client.auth.verifyOTP(
          email: email.trim(),
          token: token.trim(),
          type: OtpType.signup,
        );
      }
      state = state.copyWith(isLoading: false, status: AuthStatus.authenticated);
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> signOut() async {
    if (!AppConfig.useMockData) {
      await Supabase.instance.client.auth.signOut();
    }
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

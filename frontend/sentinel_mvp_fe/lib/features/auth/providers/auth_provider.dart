import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  @override
  AuthState build() {
    // Check initial session synchronously
    final session = Supabase.instance.client.auth.currentSession;
    final initialStatus = (session != null && !session.isExpired)
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;

    // Listen to Supabase auth state changes
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
      await Supabase.instance.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      state = state.copyWith(isLoading: false, status: AuthStatus.authenticated);
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'An unexpected error occurred.');
    }
  }

  /// Step 1: create account + trigger OTP email
  Future<void> sendSignUpCode(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await Supabase.instance.client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      state = state.copyWith(isLoading: false);
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'An unexpected error occurred.');
    }
  }

  /// Step 2: verify OTP and complete sign-up
  Future<void> verifySignUp(String email, String token) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: OtpType.signup,
      );
      state = state.copyWith(isLoading: false, status: AuthStatus.authenticated);
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'An unexpected error occurred.');
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

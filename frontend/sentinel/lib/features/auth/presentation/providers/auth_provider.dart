import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/auth_repository_provider.dart';
import '../../domain/entities/auth_user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

@immutable
class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isLoading = false,
    this.error,
  });

  final AuthStatus status;

  /// The authenticated user, or null when unauthenticated.
  final AuthUser? user;

  final bool isLoading;
  final String? error;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  // Sentinel that distinguishes "not provided" from explicit null in copyWith,
  // allowing nullable fields (user, error) to be cleared to null when needed.
  static const Object _absent = Object();

  AuthState copyWith({
    AuthStatus? status,
    Object? user = _absent,
    bool? isLoading,
    Object? error = _absent,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: identical(user, _absent) ? this.user : user as AuthUser?,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _absent) ? this.error : error as String?,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final repo = ref.read(authRepositoryProvider);

    // Stream is the single source of truth for user identity and auth status.
    // Methods only manage isLoading and error — never status directly.
    final sub = repo.authStateChanges.listen((user) {
      state = state.copyWith(
        status: user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated,
        user: user,
      );
    });
    ref.onDispose(sub.cancel);

    // Resolve initial session without waiting for a stream event.
    repo.getSignedInUser().then((user) {
      if (state.status == AuthStatus.unknown) {
        state = state.copyWith(
          status: user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated,
          user: user,
        );
      }
    });

    return const AuthState(status: AuthStatus.unknown);
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(authRepositoryProvider).signIn(email, password);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e));
    }
  }

  Future<void> registerDirect(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(authRepositoryProvider).registerDirect(email, password);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e));
    }
  }

  Future<void> sendSignUpCode(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(authRepositoryProvider).sendSignUpCode(email, password);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e));
    }
  }

  Future<void> verifySignUp(String email, String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(authRepositoryProvider).verifySignUp(email, code);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e));
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    // Stream fires and sets status: unauthenticated, user: null.
  }

  void clearError() => state = state.copyWith(error: null);

  String _msg(Object e) => e.toString().replaceAll('Exception: ', '');
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

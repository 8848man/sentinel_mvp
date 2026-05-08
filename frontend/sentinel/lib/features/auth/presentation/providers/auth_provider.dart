import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/auth_repository_provider.dart';

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
    final repo = ref.read(authRepositoryProvider);

    final sub = repo.authStateChanges.listen((user) {
      state = state.copyWith(
        status: user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated,
      );
    });
    ref.onDispose(sub.cancel);

    // Check for an existing session asynchronously.
    repo.getSignedInUser().then((user) {
      if (state.status == AuthStatus.unknown) {
        state = state.copyWith(
          status: user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated,
        );
      }
    });

    return const AuthState(status: AuthStatus.unknown);
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(authRepositoryProvider).signIn(email, password);
      state = state.copyWith(isLoading: false, status: AuthStatus.authenticated);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e));
    }
  }

  Future<void> registerDirect(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(authRepositoryProvider).registerDirect(email, password);
      state = state.copyWith(isLoading: false, status: AuthStatus.authenticated);
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
      state = state.copyWith(isLoading: false, status: AuthStatus.authenticated);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e));
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }

  void clearError() => state = state.copyWith(error: null);

  String _msg(Object e) => e.toString().replaceAll('Exception: ', '');
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

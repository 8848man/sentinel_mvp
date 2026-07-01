import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/incident/presentation/registration/screens/registration_screen.dart';
import '../../features/incident/presentation/analysis/screens/analysis_screen.dart';
import '../../features/incident/presentation/workspace/screens/workspace_screen.dart';
import '../../features/archive/presentation/screens/archive_screen.dart';

// Placeholder screens for routes not yet implemented
// Replace these as each feature screen is built.
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen(this.name);
  final String name;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2733),
      body: Center(
        child: Text(
          '$name\n(not implemented yet)',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Bridges Riverpod auth state to GoRouter's Listenable-based refresh.
/// Only triggers a re-evaluation when the auth status changes, not on every
/// isLoading / error update.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.status != next.status) notifyListeners();
    });
  }
  final Ref _ref;
}

final _routerNotifierProvider = Provider<_RouterNotifier>((ref) {
  return _RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);

      // Don't redirect while auth status is still being determined
      if (authState.status == AuthStatus.unknown) return null;

      final isAuthenticated = authState.isAuthenticated;
      final isOnAuthRoute =
          state.uri.path == '/login' || state.uri.path == '/signup';

      if (!isAuthenticated && !isOnAuthRoute) return '/login';
      if (isAuthenticated && isOnAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(
        path: '/incidents/new',
        builder: (_, __) => const RegistrationScreen(),
      ),
      GoRoute(
        path: '/incidents/:id/analysis',
        builder: (_, state) => AnalysisScreen(
            incidentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/incidents/:id/workspace',
        builder: (_, state) => WorkspaceScreen(
            incidentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/archive',
        builder: (_, __) => const ArchiveScreen(),
      ),
    ],
  );
});

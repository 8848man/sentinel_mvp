# 10 — Frontend Architecture

**Framework:** Flutter (Web, Desktop-first layout)  
**State Management:** Riverpod  
**Routing:** go_router  
**Refs:** → [Screen Spec](../context/04_screen_spec.md) · [User Flow](../context/03_user_flow.md) · [Folder Structure](./10_1_folder_structure.md)

## Design System: Color Tokens (`tokens/colors.dart`)

```dart
class AppColors {
  // Backgrounds
  static const bgPrimary     = Color(0xFF1B2733);  // page bg
  static const bgCard        = Color(0xFF0D1521);  // card / panel bg
  static const bgInput       = Color(0xFF162032);  // input fields
  static const bgHover       = Color(0xFF1E2E40);  // row hover
  static const bgOverlay     = Color(0xFF0D1521);  // modal inner

  // Text
  static const textPrimary   = Color(0xFFFFFFFF);
  static const textMuted     = Color(0xFF8BA0B4);
  static const textFaint     = Color(0xFF5A7A94);

  // Accent
  static const accentBlue    = Color(0xFF3B8BEB);  // primary button, links

  // Severity
  static const severityCritical = Color(0xFFEF4444);  // red
  static const severityMajor    = Color(0xFFF59E0B);  // amber
  static const severityMinor    = Color(0xFF22C55E);  // green

  // Status (same palette, semantic names)
  static const statusOpen        = Color(0xFF3B8BEB);
  static const statusInProgress  = Color(0xFFF59E0B);
  static const statusResolved    = Color(0xFF22C55E);
  static const statusClosed      = Color(0xFF8BA0B4);

  // Borders
  static const border        = Color(0xFF2A3F52);
}
```

---

## Design System: Typography Tokens (`tokens/typography.dart`)

```dart
class AppText {
  static const _base = TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary);

  static final displayLarge  = _base.copyWith(fontSize: 32, fontWeight: FontWeight.w700);
  static final headlineLarge = _base.copyWith(fontSize: 24, fontWeight: FontWeight.w700);
  static final headlineMedium= _base.copyWith(fontSize: 20, fontWeight: FontWeight.w700);
  static final titleLarge    = _base.copyWith(fontSize: 18, fontWeight: FontWeight.w600);
  static final titleMedium   = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w600);
  static final bodyMedium    = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w400);
  static final bodySmall     = _base.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textMuted);
  static final labelMedium   = _base.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMuted);
  static final labelSmall    = _base.copyWith(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textFaint);
  static final displayMedium = _base.copyWith(fontSize: 40, fontWeight: FontWeight.w700); // confidence %
  static final monoBody      = _base.copyWith(fontSize: 13, fontFamily: 'JetBrains Mono'); // log text
}
```

---

## Design System: Spacing Tokens (`tokens/spacing.dart`)

```dart
class AppSpacing {
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;

  static const double cardPadding   = 20;
  static const double pagePadding   = 32;
  static const double panelGap      = 24;
  static const double borderRadius  = 12;
  static const double inputRadius   = 8;
}
```

---

## Design System: Component Contracts

### SeverityBadge
```dart
SeverityBadge(severity: 'critical')  // → red outlined pill, uppercase text
SeverityBadge(severity: 'major')     // → amber outlined pill
SeverityBadge(severity: 'minor')     // → green outlined pill
// Optional: size: SeverityBadgeSize.large (workspace) | .small (card)
```

### StatusBadge
```dart
StatusBadge(status: 'open')           // → blue outlined pill
StatusBadge(status: 'in_progress')    // → amber outlined pill
StatusBadge(status: 'closed')         // → muted outlined pill
```

### IncidentCard
```dart
IncidentCard(
  incidentCode: 'INC-2026-041',
  title: 'DB Connection Pool Exhausted',
  description: 'Primary database rejecting connections.',
  severity: 'critical',
  status: 'open',          // used in Severity View
  viewMode: DashboardViewMode.status,  // status | severity
  onTap: () => context.go('/incidents/$id/workspace'),
)
```
Left border color is always derived from severity regardless of view mode.

### TwoPanelLayout
```dart
TwoPanelLayout(
  leftFlex: 28,
  rightFlex: 72,
  left: LeftPanelWidget(),
  right: RightPanelWidget(),
)
```

---

## Routing (`core/router/app_router.dart`)

```dart
final router = GoRouter(
  redirect: (ctx, state) {
    final isLoggedIn = ref.read(authProvider).isAuthenticated;
    final onAuth = state.uri.path == '/login' || state.uri.path == '/signup';
    if (!isLoggedIn && !onAuth) return '/login';
    if (isLoggedIn && onAuth) return '/dashboard';
    return null;
  },
  routes: [
    GoRoute(path: '/login',    builder: (_, __) => LoginScreen()),
    GoRoute(path: '/signup',   builder: (_, __) => SignupScreen()),
    GoRoute(path: '/dashboard',builder: (_, __) => DashboardScreen()),
    GoRoute(path: '/incidents/new', builder: (_, __) => RegistrationScreen()),
    GoRoute(path: '/incidents/:id/analysis',  builder: (_, s) => AnalysisScreen(id: s.pathParameters['id']!)),
    GoRoute(path: '/incidents/:id/workspace', builder: (_, s) => WorkspaceScreen(id: s.pathParameters['id']!)),
    GoRoute(path: '/archive',  builder: (_, __) => ArchiveScreen()),
  ],
);
```

---

## State Management Pattern (Riverpod)

Each feature has one `AsyncNotifier` or `StateNotifier`:

```dart
// Example: dashboard_provider.dart
final dashboardProvider = AsyncNotifierProvider<DashboardNotifier, DashboardState>(
  DashboardNotifier.new
);

class DashboardNotifier extends AsyncNotifier<DashboardState> {
  @override
  Future<DashboardState> build() => _loadIncidents();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_loadIncidents);
  }
}
```

---

## API Client (`core/api/api_client.dart`)

```dart
// Dio instance with Supabase JWT interceptor
final apiClient = Dio(BaseOptions(baseUrl: ApiEndpoints.base))
  ..interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final session = supabase.auth.currentSession;
      if (session != null) {
        options.headers['Authorization'] = 'Bearer ${session.accessToken}';
      }
      handler.next(options);
    },
  ));
```

---

## Dependencies (`pubspec.yaml` key packages)

```yaml
dependencies:
  flutter_riverpod: ^2.x
  go_router: ^14.x
  supabase_flutter: ^2.x
  dio: ^5.x
  intl: ^0.19.x

dev_dependencies:
  flutter_test:
  mocktail: ^1.x
  riverpod_generator: ^2.x
```

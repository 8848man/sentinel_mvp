# sentinel

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## How to run

**Mock mode** (default — no backend required):
```
flutter run -d chrome --web-port=3000
```
Login with: `admin@sentinel.ai` / `Sentinel2026!` (OTP: `000000`)

**Local backend mode** (FastAPI + SQLite):
```
flutter run -d chrome `
  --web-port=3000 `
  --dart-define=AUTH_PROVIDER=localBackend `
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 `
  --dart-define=USE_MOCK_DATA=false
```
Register an account first via the sign-up screen, then log in.
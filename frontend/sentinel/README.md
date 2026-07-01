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
flutter run -d chrome --web-port=3000 --dart-define=AUTH_PROVIDER=mock --dart-define=USE_MOCK_DATA=true
```
Login with: `admin@sentinel.ai` / `Sentinel2026!` (OTP: `000000`)

**Local backend mode** (FastAPI + SQLite):
```
flutter run -d chrome `
  --web-port=3000 `
  --dart-define=AUTH_PROVIDER=dev `
  --dart-define=USE_MOCK_DATA=false `
  --dart-define=SKIP_EMAIL_VERIFICATION=true `
  --dart-define=API_BASE_URL=http://localhost:8000
```
Register an account first via the sign-up screen, then log in.

**cloud db local backend mode** (FastAPI + SQLite):
```
flutter run -d chrome `
  --web-port=3000 `
  --dart-define=AUTH_PROVIDER=supabase `
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 `
  --dart-define=USE_MOCK_DATA=false `
  --dart-define=SUPABASE_URL=https://cemeuqlytgsiofnpxcui.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_iNrg7X3vdsp7M6IaNZayug_4t6Fr5o3
```

**hosting mode** (FastAPI + SQLite):
```
-- 실행
flutter run -d chrome `
  --web-port=51302 `
  --dart-define=AUTH_PROVIDER=supabase `
  --dart-define=API_BASE_URL=https://sentinel-backend-106332252466.asia-northeast3.run.app `
  --dart-define=USE_MOCK_DATA=false `
  --dart-define=SUPABASE_URL=https://cemeuqlytgsiofnpxcui.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_iNrg7X3vdsp7M6IaNZayug_4t6Fr5o3

-- 빌드
flutter build web `
  --dart-define=AUTH_PROVIDER=supabase `
  --dart-define=API_BASE_URL=https://sentinel-backend-106332252466.asia-northeast3.run.app `
  --dart-define=USE_MOCK_DATA=false `
  --dart-define=SUPABASE_URL=https://cemeuqlytgsiofnpxcui.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_iNrg7X3vdsp7M6IaNZayug_4t6Fr5o3

-- 배포
firebase deploy
```
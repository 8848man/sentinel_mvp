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

## How to run in mock mode

flutter run   # useMockData defaults to true

Login with: admin@sentinel.ai / Sentinel2026! (OTP: 000000)

How to switch to real backend

flutter run --dart-define=USE_MOCK_DATA=false

No presentation or domain code changes needed — only datasource method bodies need replacing with real Dio calls.

## How to run with Backend sync mode
To run against the real backend, pass --dart-define=USE_MOCK_DATA=false --dart-define=API_BASE_URL=https://your-api.com to
flutter run. Mock stays default for local dev.

flutter run `
--dart-define=API_BASE_URL=http://127.0.0.1:8000/ `
--dart-define=USE_MOCK_DATA=false 
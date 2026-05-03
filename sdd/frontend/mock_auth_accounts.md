# Mock Auth Accounts

**Purpose:** Define valid test credentials for frontend development and testing when no live Supabase project is available. These credentials are used exclusively by `AuthMockDatasource` when `AppConfig.useMockData == true`.

**Source spec:** `sdd/backend/07_auth_spec.md`

---

## Registered Mock Accounts

| Email | Password | OTP Code | User ID | Access Token (fake) | Expected Result |
|---|---|---|---|---|---|
| admin@sentinel.ai | Sentinel2026! | 000000 | mock-user-001 | mock.access.token.admin.sentinel.ai | Login success |
| dev@sentinel.ai | Dev1234! | 111111 | mock-user-002 | mock.access.token.dev.sentinel.ai | Login success |

---

## Expected Failure Cases

| Scenario | Input | Expected error |
|---|---|---|
| Unregistered email | unknown@test.com / any | "Invalid login credentials" |
| Wrong password | admin@sentinel.ai / wrongpass | "Invalid login credentials" |
| Wrong OTP code | admin@sentinel.ai / 999999 | "Invalid or expired verification code" |
| OTP before sendSignUpCode | admin@sentinel.ai (no pending) | "No pending sign-up for this email" |

---

## Sign-Up Flow in Mock Mode

1. Call `sendSignUpCode(email, password)` — stores a pending sign-up entry; no real email is sent.
2. Call `verifySignUp(email, otpCode)` — validates OTP against the registered mock accounts table above.
3. On success: returns fake tokens and sets auth status to `authenticated`.

Only OTP codes from the table above are accepted. Any other code returns an error.

---

## Token Format

Mock tokens follow this pattern: `mock.<type>.token.<email-slug>`

- These are clearly fake strings safe for local testing.
- They must never be sent to a real backend.
- `AppConfig.useMockData` must be `true` for these tokens to be used.

---

## Switching to Real Auth

Set `AppConfig.useMockData = false` (or build with `--dart-define=USE_MOCK_DATA=false`). The `AuthNotifier` will use the real Supabase client for all operations. Mock accounts are ignored.

# 04.1 — Auth Screens

**Screens:** Login · Sign Up  
**Refs:** → [Screen Index](./04_screen_spec.md) · [User Flow](./03_user_flow.md) · [Auth Spec](../backend/07_auth_spec.md) · [Responsive: Auth & Dialogs](../frontend/10_6_responsive_auth_dialogs.md)  
**Design refs:** `login.png` · `sign_up.png`

---

## Screen 1: Login

**PNG:** `login.png`  
**Route:** `/login`

### Layout

- Full viewport, background: `AppColors.bgPrimary` (#1B2733)
- Single centered card: width 400px, padding 40px, bg `AppColors.bgCard`, border-radius 16px

### Components

| Component | DS Reference | Notes |
|-----------|-------------|-------|
| App title "Sentinel" | `AppText.displayLarge` (white, bold) | Top of card |
| Subtitle "AI Error Resolution Copilot" | `AppText.bodyMedium` (muted) | Below title |
| Email label + input | `SentinelInput` | placeholder: "you@company.com", type: email |
| Password label + input | `SentinelInput` | placeholder: "••••••••", obscured |
| Continue button | `PrimaryButton` (full width) | triggers login |
| "don't you have any account? sign up" | `AppText.bodySmall` (muted) + `TextLink` (blue) | navigates to /signup |
| Error message | `ErrorText` | inline below Continue button |

### Interactions

- "Continue" validates non-empty fields, calls `AuthService.signIn(email, password)`
- On success → navigate to `/dashboard`, replace stack
- On error → display `ErrorText` with Supabase error message
- "sign up" link → navigate to `/signup`

### States

| State | Behavior |
|-------|---------|
| `idle` | Default form state |
| `loading` | Continue button shows `CircularProgressIndicator`, form disabled |
| `error` | `ErrorText` visible below button |

---

## Screen 2: Sign Up

**PNG:** `sign_up.png`  
**Route:** `/signup`

### Layout

- Same full viewport + centered card as Login

### Components

| Component | DS Reference | Notes |
|-----------|-------------|-------|
| Title "Sentinel - SignUp" | `AppText.displayLarge` (white, bold) | |
| Subtitle "AI Error Resolution Copilot" | `AppText.bodyMedium` (muted) | |
| Password label + input | `SentinelInput` | obscured |
| Validation Code label + input | `SentinelInput` | placeholder: "enter received code" |
| Email label + input | `SentinelInput` | placeholder: "you@company.com" |
| Continue button | `PrimaryButton` (full width) | |
| Error message | `ErrorText` | |

### Interactions

- "Continue" validates all fields → calls `AuthService.signUp(email, password, code)`
- On success → navigate to `/dashboard`, replace stack
- Design deviation: see [User Flow §Sign-Up Note](./03_user_flow.md)

### States

| State | Behavior |
|-------|---------|
| `idle` | Default form state |
| `loading` | Continue button shows `CircularProgressIndicator`, form disabled |
| `error` | `ErrorText` visible below button |

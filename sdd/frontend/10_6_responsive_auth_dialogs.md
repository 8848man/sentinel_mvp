# 10.6 — Responsive: Auth Screens & Detail Dialog

**Refs:** → [Responsive Strategy](./10_2_responsive_strategy.md) · [Screen Spec](../context/04_screen_spec.md)

---

# Summary

Two low-risk, low-complexity items grouped together: the Login/Signup card (already near-mobile-native) and the Incident Detail Dialog (used from both Archive and Analysis' similar-incidents list).

# Decisions

- Login/Signup: card width changes from fixed (~400px) to relative width with margin, instead of a hard pixel value. No structural layout change.
- Incident Detail Dialog (`incident_detail_dialog.dart`): presentation container becomes a bottom sheet <768px, stays a centered dialog ≥768px. Inner content widget is shared between both containers — extract it from the `showDialog` wrapper if not already separable.

# Requirements

| Screen | <768px | ≥768px |
|---|---|---|
| Login / Signup | Card: `ConstrainedBox(maxWidth: 440)` + horizontal margin | Fixed ~400–440px centered (current) |
| Detail Dialog | `showModalBottomSheet`, drag handle | `showDialog`, centered (current) |

# Implementation Notes

- Files: `features/auth/presentation/screens/login_screen.dart`, `signup_screen.dart`, `features/incident/presentation/shared/widgets/incident_detail_dialog.dart`.
- `showIncidentDetailDialog` needs a breakpoint check to pick the presentation container; content widget must not be duplicated between the two paths.

# References

- [`10_2_responsive_strategy.md`](./10_2_responsive_strategy.md) — breakpoints, D6

# 10.7 — Mobile Information Architecture

**Refs:** → [Responsive Strategy](./10_2_responsive_strategy.md) · [User Flow](../context/03_user_flow.md)

---

# Summary

Mobile navigation stays flat and stack-based — same IA as desktop, no new top-level sections. No bottom tab bar, no drawer.

# Decisions

- Single home screen (Dashboard); every other screen returns up the stack it came down from.
- Status/Severity toggle remains a same-screen content filter (not a route), unchanged from desktop.
- Bottom sheets and confirmation steps are overlays on the current screen, not new route entries — back-button dismisses the sheet, doesn't pop the route.
- Incident routing by lifecycle stage (open→Analysis, in_progress/resolved→Workspace) is existing `app_router.dart` logic — preserve unchanged, no IA change needed.

# Requirements

```
Dashboard (home)
 ├─ Register Incident → Analysis → Workspace → (Mark Resolved →) Dashboard
 └─ Archive → (row tap) → Detail bottom sheet (dismiss back to Archive)
```

- Deepest path: `Dashboard → Registration → Analysis → Workspace` (3 hops) — must remain reachable via standard back-navigation at every step; no "jump home" shortcut needed given the short, linear depth.

# Implementation Notes

- Rationale for flat IA (not narrative — affects implementation: confirms no tab/drawer widget should be built): on-call engineers organize mentally around "the incident I'm working," not UI sections; a flat back-stack matches that model and avoids "where am I" ambiguity under time pressure.
- Confirmation step on resolve (Phase 3, [strategy doc](./10_2_responsive_strategy.md)) is justified specifically for mobile because touch mis-taps are more likely than mouse mis-clicks on a high-consequence, hard-to-reverse action.

# References

- [`10_2_responsive_strategy.md`](./10_2_responsive_strategy.md) — Phase 3 items gated by Product Spec Agent
- [`03_user_flow.md`](../context/03_user_flow.md) — desktop navigation paths this IA mirrors

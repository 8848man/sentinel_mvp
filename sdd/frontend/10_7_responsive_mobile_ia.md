# 10.7 — Mobile Information Architecture

**Refs:** → [Responsive Strategy](./10_2_responsive_strategy.md) · [User Flow](../context/03_user_flow.md)

---

# Summary

Mobile navigation stays flat and stack-based — same IA as desktop, no new top-level sections. No bottom tab bar, no drawer.

# Decisions

- **Workflow preservation governs this IA** (`10_2_responsive_strategy.md`, D10): screen hierarchy, navigation hierarchy, workflow sequence, and user mental model must match desktop. No mobile-only workflow changes (mode-switching tabs, reordered reading priority, added steps) without cross-platform parity and Product Spec Agent sign-off.
- Single home screen (Dashboard); every other screen returns up the stack it came down from.
- Status/Severity toggle remains a same-screen content filter (not a route), unchanged from desktop.
- Bottom sheets are overlays on the current screen, not new route entries — back-button/swipe dismisses the sheet, doesn't pop the route. The Workspace "View full timeline" sheet (`10_4_responsive_incident_flow.md`) reuses this exact established pattern rather than introducing a dedicated screen.
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
- A mobile-only confirmation step before Mark Resolved/Close was evaluated and rejected (`10_2_responsive_strategy.md`, D12): it would diverge from desktop's single-tap behavior, which D10 rules out. Current single-tap behavior is unchanged on every breakpoint.

# References

- [`10_2_responsive_strategy.md`](./10_2_responsive_strategy.md) — D10–D12 (workflow preservation, sticky action bars, rejected confirmation steps); Archive search/filter is the only remaining Product Spec Agent sign-off item
- [`03_user_flow.md`](../context/03_user_flow.md) — desktop navigation paths this IA mirrors

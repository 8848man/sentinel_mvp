# 10.2 — Responsive Strategy

**Refs:** → [Frontend Architecture](./10_frontend_arch.md) · [Folder Structure](./10_1_folder_structure.md) · [Screen Spec](../context/04_screen_spec.md)
**Screen-level specs:** [Dashboard](./10_3_responsive_dashboard.md) · [Incident Flow](./10_4_responsive_incident_flow.md) · [Archive](./10_5_responsive_archive.md) · [Auth & Dialogs](./10_6_responsive_auth_dialogs.md) · [Mobile IA](./10_7_responsive_mobile_ia.md)

---

# Summary

Sentinel's Flutter app currently has **no responsive logic anywhere** (no `MediaQuery`/`LayoutBuilder`/breakpoints). `TwoPanelLayout` is a fixed-flex `Row`, `SentinelScaffold` padding is a fixed 32px, and the Archive screen is a fixed 6-column table with no overflow handling. This is a greenfield retrofit. Priority on conflicts: (1) existing functionality → (2) existing web design system → (3) mobile prototype patterns (`sentinel_screen_ref/mobile/sentinel_mobile.html`, UX-pattern reference only, not a source of truth).

# Decisions

| # | Decision |
|---|---|
| D1 | Breakpoints: **mobile** 0–767px, **tablet** 768–1199px, **desktop** 1200px+. Add `AppBreakpoints` to `design_system/tokens/` (new file). |
| D2 | `SentinelScaffold` padding: 32px desktop/tablet, 16px mobile. Needs a breakpoint-aware parameter, not a global token change. |
| D3 | `TwoPanelLayout`: stacks to single column <768px (left-panel content first); flex ratio changes to ~38/62 on tablet (768–1199px); stays 28/72 ≥1200px. |
| D4 | Dashboard's 3-column board stacks to sections <900px (sub-breakpoint inside the tablet band — see [Dashboard spec](./10_3_responsive_dashboard.md)). |
| D5 | Archive table → card list <768px; scrollable table (horizontal `SingleChildScrollView` safety net) 768–1199px; unchanged ≥1200px. See [Archive spec](./10_5_responsive_archive.md). |
| D6 | Modal/dialog content (`incident_detail_dialog.dart`) renders as a bottom sheet <768px, centered dialog ≥768px, same inner content widget both ways. |
| D7 | Timeline dot+connecting-line visual (ported from mobile prototype) applies at **all** breakpoints — pure visual upgrade, not mobile-only. |
| D8 | Navigation stays flat top-app-bar + back button at all breakpoints. No bottom tab bar, no drawer — IA has no parallel top-level sections to tab between. |
| D9 | Resolve-confirmation bottom sheet and Archive search/filter are **out of scope** until Product Spec Agent sign-off (functional changes, not layout adaptation — see Open Questions). |

# Requirements

| Area | Mobile (0–767) | Tablet (768–1199) | Desktop (1200+) |
|---|---|---|---|
| Navigation | Top app-bar, icon-only actions | Top app-bar, icon+label actions | Unchanged (current) |
| Two-panel screens | Single column, left-panel content first | Side-by-side, flex ~38/62 | Side-by-side, flex 28/72 (current) |
| Dashboard board | Stacked sections | Stacked <900px, 3-col ≥900px | 3-col row (current) |
| Archive | Card list | Table + horizontal scroll fallback | Table (current) |
| Detail dialog | Bottom sheet | Centered dialog | Centered dialog (current) |
| Timeline | Dot + connecting line | Dot + connecting line | Dot + connecting line (new, all breakpoints) |

# Implementation Notes

- No existing DS component is breakpoint-aware; every item above is net-new logic, not a tuning pass.
- Files requiring direct changes: `design_system/components/layout/sentinel_scaffold.dart`, `design_system/components/layout/two_panel_layout.dart`, `features/dashboard/presentation/screens/dashboard_screen.dart`, `features/incident/presentation/shared/widgets/incident_detail_dialog.dart`.
- New token file: `design_system/tokens/breakpoints.dart`.
- Mobile prototype patterns adopted: top app-bar (not bottom tabs), card-list for tabular data, bottom sheets for detail "peeks", dot+line timeline, full-row checklist tap targets (≥44px).
- Mobile prototype patterns rejected: its color palette/iconography (different token set than `AppColors`), its auth field ordering/copy, its 2-step signup indicator (unverified against `07_auth_spec.md`).

# Roadmap

1. **Phase 1 — Critical fixes:** breakpoint tokens; `SentinelScaffold`/`TwoPanelLayout` responsive behavior; Dashboard board stacking; Archive horizontal-scroll stopgap; relative-width auth cards. No overflow/breakage at any width.
2. **Phase 2 — Mobile UX:** Archive card-list; bottom-sheet detail dialog; Dashboard header redesign; timeline dot+line (all breakpoints); tablet `TwoPanelLayout` ratio; checklist touch-target sizing.
3. **Phase 3 — Advanced (needs Product Spec Agent sign-off):** resolve-confirmation step + success state; Archive search/filter; persistent bottom CTA bar on Analysis.

# Open Questions (Product Spec Agent)

1. Is "Mark as Resolved" confirmation mobile-only or a universal behavior change?
2. Is Archive search/filter an approved feature or prototype-only speculation?
3. Is signup genuinely 2-step (password+OTP), matching `07_auth_spec.md`, or a prototype simplification?
4. Should the post-resolve success screen exist on desktop too, or stay mobile-only?

# References

- `sentinel_screen_ref/web/*.png` — desktop visual source of truth
- `sentinel_screen_ref/mobile/sentinel_mobile.html` — mobile UX pattern reference only
- [`10_frontend_arch.md`](./10_frontend_arch.md) — design tokens and component contracts (not duplicated here)
- [`13_agent_instructions.md`](../13_agent_instructions.md) — Frontend Agent ownership boundaries; sign-off requirement for new screens/flows

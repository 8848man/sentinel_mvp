# 10.5 — Responsive: Archive

**Refs:** → [Responsive Strategy](./10_2_responsive_strategy.md) · [Screen Spec](../context/04_screen_spec.md)

---

# Summary

Archive renders a fixed 6-column flex `Row` table (`Code`/`Title`/`Severity`/`Status`/`Resolved`/`Fix Flow`/View-link) with no overflow handling. This is the **highest-risk screen** in the app at small widths — it will overflow or compress unreadably, not just look cramped.

# Decisions

- <768px: replace the table with a vertical card list (pattern ported directly from mobile prototype). Each card preserves all 6 data points: code+status line, title, resolution-time line with icon, severity badge + chevron.
- 768–1199px: keep the table, wrap in horizontal `SingleChildScrollView` as a scroll-fallback safety net (not a redesign).
- ≥1200px: unchanged (current).
- Row tap → detail content opens as a bottom sheet <768px, centered dialog ≥768px (shared with [Auth & Dialogs spec](./10_6_responsive_auth_dialogs.md#decisions)).
- Start the card design screen-local (mirrors current `_ArchiveTable`/`_TableRow` being screen-local, not DS components); promote to a shared DS component only if reuse emerges elsewhere.

# Requirements

| Element | <768px | 768–1199px | ≥1200px |
|---|---|---|---|
| List rendering | Card list, full width | Table + horizontal scroll | Table (current) |
| Row tap target | Opens bottom sheet | Opens centered dialog | Opens centered dialog (current) |

# Implementation Notes

- File: `features/archive/presentation/screens/archive_screen.dart` (`_ArchiveTable`, `_TableRow`, `_TableHeader` — currently screen-local widgets, not DS components).
- New: `_ArchiveCardList` / `_ArchiveCard` widgets, mobile breakpoint only.
- Phase 1 stopgap (ship before the card-list redesign): wrap the existing table in `SingleChildScrollView(scrollDirection: Axis.horizontal)` so it degrades to "scrollable but usable" rather than broken. Card list is Phase 2.

# References

- [`10_2_responsive_strategy.md`](./10_2_responsive_strategy.md) — breakpoints, roadmap phases
- `sentinel_screen_ref/mobile/sentinel_mobile.html` — source of the card-list pattern (screen 7, "Closed Incidents Archive")

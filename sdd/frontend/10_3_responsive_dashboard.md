# 10.3 — Responsive: Dashboard

**Refs:** → [Responsive Strategy](./10_2_responsive_strategy.md) · [Screen Spec](../context/04_screen_spec.md)

---

# Summary

Dashboard renders Status View / Severity View as a fixed 3-column `Row` of `Expanded` columns. At ≤767px columns compress to ~100px and become unreadable; the header (title/subtitle + Archive/Register/clock) also has no wrap/collapse logic.

# Decisions

- Board layout uses a **sub-breakpoint at 900px** (inside the tablet band): 3-column row ≥900px, stacked sections <900px. This differs from the 768px line used elsewhere because the board's fixed-width card content needs more floor width than other screens.
- Header actions collapse to icon-only (Archive) / icon+short-label pill (Register) <768px; icon+text labels return ≥768px.
- Clock placement on the narrowest widths is a deferred design call — do not assume drop or relocate without designer confirmation.
- Status/Severity 2-tab toggle is unchanged at all breakpoints (already narrow-width tolerant).

# Requirements

| Element | <768px | 768–899px | ≥900px |
|---|---|---|---|
| Board | Stacked sections, full-width cards, colored label + count per group | Stacked sections | 3-column row (current) |
| Header actions | Icon-only / icon+short-label | Icon+text (current) | Icon+text (current) |
| View toggle | Unchanged | Unchanged | Unchanged |

# Implementation Notes

- Files: `features/dashboard/presentation/screens/dashboard_screen.dart` (`_StatusBoard`, `_SeverityBoard`, `_Header`), `features/dashboard/presentation/widgets/status_column.dart`, `severity_column.dart`.
- `StatusColumn`/`SeverityColumn` likely need a layout-mode parameter (column-of-cards vs. row-wrapper), not a rewrite — internal card rendering is reusable.
- Section grouping pattern (colored label + count) ported from mobile prototype's "Open (1)" style headers.

# References

- [`10_2_responsive_strategy.md`](./10_2_responsive_strategy.md) — breakpoint definitions, global decisions

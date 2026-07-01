# 10.3 — Responsive: Dashboard

**Refs:** → [Responsive Strategy](./10_2_responsive_strategy.md) · [Screen Spec](../context/04_screen_spec.md)

---

# Summary

Dashboard renders Status View / Severity View as a fixed 3-column `Row` of `Expanded` columns. At ≤767px columns compress to ~100px and become unreadable; the header (title/subtitle + Archive/Register/clock) also has no wrap/collapse logic.

# Decisions

- Board layout uses a **sub-breakpoint at 900px** (inside the tablet band): 3-column row ≥900px, stacked sections <900px. This differs from the 768px line used elsewhere because the board's fixed-width card content needs more floor width than other screens.
- Header actions collapse to icon-only (Archive) / icon+short-label pill (Register) <768px; icon+text labels return ≥768px.
- **Register Incident** trigger additionally repositions to a bottom-right FAB <768px — thumb reachability fix, same destination route, same tap behavior (Layout Change, validated, no sign-off needed).
- **Archive stays a single-tap header icon at every breakpoint** — explicitly not moved behind an overflow/kebab menu, which would add a navigation hop absent on desktop.
- Add pull-to-refresh (`RefreshIndicator`) around the mobile board — additive only; desktop has no equivalent manual-refresh action today, so this fills a gap rather than diverging from an existing step.
- `IncidentCard` gets a small distinct elapsed-time chip near the severity badge (Information Hierarchy Change) instead of plain text in the description line — surfaces the most decision-relevant fact without adding a new field.
- Clock placement on the narrowest widths is a deferred design call — do not assume drop or relocate without designer confirmation.
- Status/Severity 2-tab toggle is unchanged at all breakpoints (already narrow-width tolerant).

# Requirements

| Element | <768px | 768–899px | ≥900px |
|---|---|---|---|
| Board | Stacked sections, full-width cards, colored label + count per group | Stacked sections | 3-column row (current) |
| Header actions | Icon-only Archive + icon+short-label Register pill | Icon+text (current) | Icon+text (current) |
| Register trigger | Header pill **and** bottom-right FAB | Header button (current) | Header button (current) |
| Refresh | `RefreshIndicator` (pull-to-refresh) | — | — |
| View toggle | Unchanged | Unchanged | Unchanged |

# Implementation Notes

- Files: `features/dashboard/presentation/screens/dashboard_screen.dart` (`_StatusBoard`, `_SeverityBoard`, `_Header`), `features/dashboard/presentation/widgets/status_column.dart`, `severity_column.dart`, `design_system/components/cards/incident_card.dart` (elapsed-time chip).
- `StatusColumn`/`SeverityColumn` likely need a layout-mode parameter (column-of-cards vs. row-wrapper), not a rewrite — internal card rendering is reusable.
- Section grouping pattern (colored label + count) ported from mobile prototype's "Open (1)" style headers.

# References

- [`10_2_responsive_strategy.md`](./10_2_responsive_strategy.md) — breakpoint definitions, global decisions

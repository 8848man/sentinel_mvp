# 10.4 — Responsive: Incident Flow (Registration / Analysis / Workspace)

**Refs:** → [Responsive Strategy](./10_2_responsive_strategy.md) · [Screen Spec](../context/04_screen_spec.md)

---

# Summary

All three screens use `TwoPanelLayout` (28/72). Grouped here because they share one architectural decision — collapsing/re-flowing `TwoPanelLayout` — even though each screen's panel content differs.

# Decisions

All decisions below follow the workflow-preservation constraint (`10_2_responsive_strategy.md`, D10): document order, screen hierarchy, and step count match desktop exactly on every breakpoint — only positioning and information-hierarchy default-visibility change.

- All three: <768px stacks left-panel content above right-panel content, in current document order, as full-width card sections. No content moves behind a tab or accordion — density must stay visible by scrolling or one tap of progressive disclosure, never permanently hidden.
- **Registration:** left panel is static instructional text only — collapses into a compact heading above the form, not a stacked section. Field order stays identical to desktop (Title → Severity → Components → Log → Submit) — do not reorder for mobile. Submit button moves to a sticky bottom bar (Layout Change). Add a "paste from clipboard" quick action next to the log field (additive). Severity must render as large tap-target chips on mobile, not a small native dropdown hit-area.
- **Registration — OCR image picker (spec only, not yet implemented):** entry point sits beside the existing paste-from-clipboard action on **both** mobile and desktop (not mobile-exclusive) — see [`04_1_ocr_log_extraction.md`](../context/04_1_ocr_log_extraction.md). The Review Screen reuses the D6 dialog↔bottom-sheet pattern (`10_6_responsive_auth_dialogs.md`), not a new route.
- **Analysis:** document order stays Root Cause → Confidence → Similar Incidents → Fix Flows on every breakpoint (matches desktop's left-to-right reading order collapsed top-to-bottom) — do not reorder fix flows ahead of this context. <768px, summarize Root Cause/Confidence/Similar Incidents into a compact card by default (one-line root cause, confidence number, similar-incident count) with an inline "Show details" expand revealing full text/list in place (Information Hierarchy Change — content is fixed-size once analysis completes, so it doesn't compound across revisits the way Workspace's timeline does). Add a "Recommended" visual treatment to the highest-confidence unattempted fix-flow row (Information Hierarchy Change). A confirmation step before committing a fix-flow selection was evaluated and is **not recommended** (D12) — single-tap-select-and-navigate is unchanged. <768px, the header simplifies to back button + "Analysis" page label only (D13, `10_2_responsive_strategy.md`); incident title and incident ID move to the top of the page content, above Root Cause.
### Mobile Fix Flow Information Hierarchy (Information Hierarchy Change)

On a fix-flow row, the Fix Flow Name, the Recommended indicator, and Confidence are not equal-priority content — they must not be laid out as if they were:

- Fix Flow Name is the primary content of the row and carries the highest visual priority.
- Recommended is a status indicator on top of the row's content, not primary content in its own right.
- Confidence is secondary metadata, subordinate to the Fix Flow Name.
- At <768px, Recommended and Confidence must never be laid out in a way that reduces the horizontal space available to the Fix Flow Name (e.g. competing in the same row) — Fix Flow Name readability takes priority over metadata visibility at that width.
- This is a presentation/hierarchy rule, not a styling spec — exact positioning, sizing, and visual treatment are an implementation decision, so long as the above ordering of priority holds.
- **Workspace:** document order stays Header/badges → Components → Root Cause → Timeline → Checklist → Notes → Actions on every breakpoint — no segmented/tabbed mode-switcher (rejected: desktop shows Timeline, Checklist, and Notes simultaneously; a tab switcher would hide two of three at a time, a workflow change D10 rules out). <768px: summarize Timeline to **exactly the 3 most recent events** by default (fixed count, not a height limit — deterministic regardless of text wrap or font scaling), with a "View full timeline" link opening the existing bottom-sheet pattern (`incident_detail_dialog.dart`'s `DraggableScrollableSheet` + scrollController composition, reused exactly, not reinvented) — see Timeline Requirements below. Notes collapses to a fixed-height preview when unfocused, expanding in place to full editing height on focus (Layout Change). Action buttons (`Back to Analysis` / `Mark as Resolved` / `Close` / `Reopen`) move to a sticky bottom action bar, always visible regardless of scroll position (Layout Change), replacing the prior side-by-side row only in *position*, not order or count. A confirmation step before Mark Resolved/Close was evaluated and is **not recommended** (D12) — single-tap behavior is unchanged. <768px, the header simplifies to back button + "Workspace" page label only (D13, `10_2_responsive_strategy.md`); incident title and incident ID move to the top of the page content, above the status/severity badges.

## Workspace Full Timeline — bottom sheet requirements

- Reuse `incident_detail_dialog.dart`'s exact composition: `showModalBottomSheet` → `DraggableScrollableSheet(initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false)` → `scrollController` passed to an **outer** scrollable, with `TimelineList(shrinkWrap: true)` nested inside — do not give `TimelineList` an independent scrollable (avoids drag-to-scroll vs. drag-to-resize gesture conflicts).
- Open the sheet already scrolled to the most recent event (`scrollController.jumpTo(maxScrollExtent)` post-frame) — chronological top-to-bottom order is unchanged, only the initial viewport position changes, so the most operationally relevant events are visible without an initial scroll.
- Above ~20 events, insert lightweight non-interactive hour/time-group separator rows into the same list for scanability — no filter/search control, no new screen.
- The sheet must watch the same live incident provider Workspace already watches (not a frozen snapshot taken at open-time), so events arriving while the sheet is open appear without reopening it.
- Sheet height/virtualization need no special handling at any event volume (validated at 10/30/50/100 events): `DraggableScrollableSheet`'s height is a fixed screen fraction regardless of content, and `ListView.builder` virtualizes lazily regardless of count.
- Dismissing the sheet (swipe down / tap outside / back gesture) returns to Workspace's existing scroll position unchanged — it is an overlay, not a route (`10_7_responsive_mobile_ia.md`).

# Requirements

| Screen | <768px | 768–1199px | ≥1200px |
|---|---|---|---|
| Registration | Single column; left panel text becomes a heading; sticky bottom submit bar | `TwoPanelLayout` flex ~38/62 | `TwoPanelLayout` flex 28/72 (current) |
| Analysis | Single column: summarized root cause/confidence/similar incidents (expandable) → fix flows, top recommendation highlighted | `TwoPanelLayout` flex ~38/62 | `TwoPanelLayout` flex 28/72 (current) |
| Workspace | Single column: header → components → root cause → timeline (last 3 events + "View full timeline" sheet) → checklist → notes (collapsed preview) → sticky bottom action bar | `TwoPanelLayout` flex ~38/62, full timeline inline (current) | `TwoPanelLayout` flex 28/72, full timeline inline (current) |

# Implementation Notes

- Files: `features/incident/presentation/registration/screens/registration_screen.dart`, `analysis/screens/analysis_screen.dart`, `workspace/screens/workspace_screen.dart`, `shared/widgets/timeline_list.dart`, `shared/widgets/incident_detail_dialog.dart` (pattern to copy for the new Full Timeline sheet, not modify).
- D13 header simplification: Analysis's and Workspace's `_Header` widgets keep their back button but drop the incident-code/title `Text`s at <768px, rendering just the page label. The dropped content reappears as a new small block (`shared/widgets/incident_context_header.dart`, shared so both screens render it identically) at the top of each screen's left-panel content, mobile-only — desktop/tablet keep the header exactly as-is today.
- `MetadataPanel`, `ArchitectureComponentList`, fix-flow/checklist widgets are already full-width-capable inside their current `Expanded` — only the outer `Row`→`Column` swap is needed, not internal rewrites.
- `FixFlowRow`: at <768px, do not lay out Fix Flow Name, Recommended, and Confidence in the same row — see Mobile Fix Flow Information Hierarchy above. Confirmed by mobile usability testing that the single-row layout pressures Fix Flow Name's width; a dedicated mobile arrangement (e.g. stacked metadata below the name) is needed rather than relying on wrapping.
- `ChecklistItemWidget`: increase row height for ≥44px touch targets on mobile.
- Timeline summarization is the mitigation for the "longer incident → more scrolling to reach checklist" risk previously flagged here as High — content summarization at a fixed default size, not document reordering, resolves it; the rest of the document order is unaffected.

# References

- [`10_2_responsive_strategy.md`](./10_2_responsive_strategy.md) — breakpoints, `TwoPanelLayout` decision, D10–D12 (workflow preservation, sticky action bars, rejected confirmation steps)
- [`10_7_responsive_mobile_ia.md`](./10_7_responsive_mobile_ia.md) — bottom sheets are overlays, not new routes
- [`13_agent_instructions.md`](../13_agent_instructions.md) — sign-off requirement for any future cross-platform workflow change

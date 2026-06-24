# 10.4 — Responsive: Incident Flow (Registration / Analysis / Workspace)

**Refs:** → [Responsive Strategy](./10_2_responsive_strategy.md) · [Screen Spec](../context/04_screen_spec.md)

---

# Summary

All three screens use `TwoPanelLayout` (28/72). Grouped here because they share one architectural decision — collapsing/re-flowing `TwoPanelLayout` — even though each screen's panel content differs.

# Decisions

- All three: <768px stacks left-panel content above right-panel content, in current document order, as full-width card sections. No content moves behind a tab or accordion — density must stay visible by scrolling, never hidden (per project goal of preserving information density on mobile).
- Registration: left panel is static instructional text only — collapses into a compact heading above the form, not a stacked section.
- Analysis: optional persistent bottom CTA bar once a fix flow is selected, mobile only (mirrors prototype's bottom-anchored primary button). New pattern, not in current DS — flag for design review before building.
- Workspace: action buttons (`Back to Analysis` / `Mark as Resolved`) stack full-width instead of side-by-side <768px. Resolve-confirmation bottom sheet is **Phase 3, contingent on Product Spec Agent sign-off** (see [strategy doc](./10_2_responsive_strategy.md#open-questions-product-spec-agent)) — do not build until approved.

# Requirements

| Screen | <768px | 768–1199px | ≥1200px |
|---|---|---|---|
| Registration | Single column; left panel text becomes a heading | `TwoPanelLayout` flex ~38/62 | `TwoPanelLayout` flex 28/72 (current) |
| Analysis | Single column: root cause → confidence → similar incidents → fix flows; optional bottom CTA bar when a flow is selected | `TwoPanelLayout` flex ~38/62 | `TwoPanelLayout` flex 28/72 (current) |
| Workspace | Single column: header → timeline → checklist → notes → stacked full-width action buttons | `TwoPanelLayout` flex ~38/62 | `TwoPanelLayout` flex 28/72 (current) |

# Implementation Notes

- Files: `features/incident/presentation/registration/screens/registration_screen.dart`, `analysis/screens/analysis_screen.dart`, `workspace/screens/workspace_screen.dart`.
- `MetadataPanel`, `ArchitectureComponentList`, fix-flow/checklist widgets are already full-width-capable inside their current `Expanded` — only the outer `Row`→`Column` swap is needed, not internal rewrites.
- `FixFlowRow`: verify wrapping behavior at narrow widths on real devices before assuming a dedicated mobile variant is needed.
- `ChecklistItemWidget`: increase row height for ≥44px touch targets on mobile.
- Risk: Analysis and Workspace are the densest screens in the product (root cause + confidence + similar incidents + 4 fix-flow rows simultaneously on Analysis) — rated **High** risk/complexity for getting information priority right when stacking.

# References

- [`10_2_responsive_strategy.md`](./10_2_responsive_strategy.md) — breakpoints, `TwoPanelLayout` decision
- [`13_agent_instructions.md`](../13_agent_instructions.md) — sign-off requirement for new screens/flows (bottom CTA bar, resolve confirmation)

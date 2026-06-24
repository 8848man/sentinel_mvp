# Responsive Spec Migration Report

Refactor of `sdd/frontend/14_responsive_design_strategy.md` per [`sdd/rules/spec_authoring_rules.md`](../rules/spec_authoring_rules.md).

## Original

- **File:** `sdd/frontend/14_responsive_design_strategy.md`
- **Size:** 392 lines — exceeds the 300-line hard limit, and written as narrative analysis (long paragraphs, prose "Reasoning" columns, an essay-style mobile-prototype walkthrough) rather than decisions/requirements, violating the writing-style rules independently of size.
- **Status:** deleted. Content migrated below; no information-bearing content was discarded, only narrative justification not tied to an implementation decision.

## Why `10.x`, not `14`

The original file used a standalone `14_` prefix with no entry in `00_index.md`. The project's actual convention for frontend-domain documents is sub-numbering under `10_` (see `10_1_folder_structure.md`) — domain number `10` covers all frontend specs, with `10_N` for sub-topics. A `14_` prefix collides conceptually with the unrelated root-level `13_agent_instructions.md` numbering and doesn't signal "this is a frontend doc." Responsive specs are frontend-domain documents, so they were renumbered into the existing `10_N` series and given an index entry, which the original file never had.

## Resulting Structure

| File | Lines | Responsibility |
|---|---|---|
| `10_2_responsive_strategy.md` | 63 | Breakpoints, global decisions, requirements matrix, roadmap, open questions |
| `10_3_responsive_dashboard.md` | 34 | Dashboard board/header responsive rules |
| `10_4_responsive_incident_flow.md` | 37 | Registration/Analysis/Workspace `TwoPanelLayout` collapse |
| `10_5_responsive_archive.md` | 35 | Archive table → card list |
| `10_6_responsive_auth_dialogs.md` | 30 | Login/Signup card, Detail Dialog → bottom sheet |
| `10_7_responsive_mobile_ia.md` | 36 | Mobile navigation/IA |
| **Total** | **235** | (vs. 392 in the original single file) |

## Sections Moved / Removed

| Original section | Disposition | Reason |
|---|---|---|
| §0 Current-State Finding | Compressed into `10_2` Summary + Implementation Notes | Kept only the constraints that drive implementation (no breakpoints exist anywhere, specific files affected); dropped the narrative framing |
| §1 Desktop Experience Analysis | Removed | Duplicated content already owned by `04_screen_spec.md` and `10_frontend_arch.md`; pure narrative, no implementation decision of its own |
| §2 Design System Analysis | Removed | Duplicated `10_frontend_arch.md`'s token/component tables verbatim; referenced instead of repeated |
| §3 Mobile Prototype Analysis | Compressed into `10_2` "patterns adopted/rejected" bullet list | Essay-length pattern-by-pattern walkthrough reduced to the actionable conclusions only |
| §4 Comparative Analysis (table w/ "Reasoning" prose column) | Split: per-screen decisions moved into `10_3`–`10_7`; cross-cutting items kept as Decisions (D1–D9) in `10_2` | The "Current Web UI" / "Mobile Prototype" descriptive columns were analysis, not requirements — dropped; only the resulting decision survived, attached to the screen it affects |
| §5 Responsive Architecture Strategy | Kept, compressed into `10_2` Decisions + Requirements matrix | Core breakpoint behavior — directly implementation-relevant |
| §6 Screen-by-Screen Plan | Split across `10_3` (Dashboard), `10_4` (Registration/Analysis/Workspace), `10_5` (Archive), `10_6` (Login/Signup + Detail Dialog) | Each screen group is now independently readable without loading the other groups; "Required Layout/Component Changes" kept as Implementation Notes, "Risk Assessment"/"Complexity" prose folded into one line per screen instead of a labeled subsection |
| §7 Mobile Information Architecture | Moved to `10_7`, "why this fits on-call engineers" essay compressed to two Implementation-Notes lines | The persona rationale is real but only needs one sentence to be actionable; the rest was repetition of already-stated IA decisions |
| §8 Responsive Refactoring Roadmap | Kept, compressed into `10_2` Roadmap | Already fairly compact in the original; trimmed examples |
| Open Questions | Kept, moved to `10_2` | Directly gates Phase 3 work — implementation-relevant |

## Rationale for New Files

- **One file per screen-group (`10_3`–`10_6`):** matches "split by responsibility" — Dashboard, the Registration/Analysis/Workspace `TwoPanelLayout` group, Archive, and Auth/Dialogs each have independently reviewable, independently implementable scope. An implementer fixing Archive never needs Dashboard's content open, and vice versa.
- **Registration + Analysis + Workspace share one file (`10_4`), not three:** they share a single architectural decision (collapsing `TwoPanelLayout`) and the same panel-stacking rule; separating them would duplicate that shared decision three times, which the no-duplication rule forbids. Screen-specific differences are kept as subsections within the one file.
- **Login/Signup + Detail Dialog share one file (`10_6`):** both are low-risk, low-complexity, presentation-container-only changes (card width; dialog→bottom-sheet) with no shared screen logic between them — grouped by complexity/cohesion ("trivial responsive changes"), not forced into separate near-empty files.
- **Mobile IA gets its own file (`10_7`):** navigation/IA is a distinct concern from any single screen's layout — it's referenced by every screen doc but owned by none of them.
- **Strategy gets its own file (`10_2`):** every other doc references it for breakpoints and global decisions; keeping it separate avoids the no-duplication problem of restating breakpoint values in six places.

## Cross-References Updated

- `sdd/00_index.md` — added a "Frontend Sub-Documents (10.x)" table; updated the Cross-Document Dependency diagram to show `10_frontend_arch → 10_2..10_7`.
- `sdd/frontend/10_frontend_arch.md` — added `10_2_responsive_strategy.md` to its `Refs:` line.
- `sdd/context/04_screen_spec.md` — added `10_2_responsive_strategy.md` to its `Refs:` line.
- All six new files cross-reference `10_2_responsive_strategy.md` and each other where relevant (e.g., `10_5` references `10_6` for the shared dialog decision) instead of restating shared content.

## Compliance Check

All six files are within the 50–150 target band or below it (30–63 lines each) — none approach the 200-line soft limit. Combined with `sdd/spec_compliance_report.md`'s existing finding that this file was the worst offender, this refactor resolves that specific entry; the other flagged files (`04_screen_spec.md`, `05_api_spec.md`, `13_agent_instructions.md`, `06_database_schema.md`, `10_frontend_arch.md`) are unchanged and remain open per that report's priority order.

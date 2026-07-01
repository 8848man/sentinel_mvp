# Spec Compliance Report

Audit against `sdd/rules/spec_authoring_rules.md` (target 50–150 lines, soft limit 200, hard limit 300). No files modified — report only.

| File | Lines | Violation | Recommended split |
|---|---|---|---|
| `sdd/frontend/14_responsive_design_strategy.md` | 392 | Exceeds hard limit (300). Written as narrative analysis (long paragraphs, "Reasoning" prose columns, prototype-pattern essays) rather than decisions/requirements — violates writing-style rules, not just size. | Split by responsibility: `responsive_strategy.md` (breakpoints + decisions only), `responsive_dashboard.md`, `responsive_archive.md`, `responsive_analysis_workspace.md`, `responsive_ia.md` (mobile IA + nav). Strip narrative justification down to one-line rationale per decision; drop the comparative-analysis prose table to a compact requirements table. |
| `sdd/context/04_screen_spec.md` | 300 | At hard limit exactly. Covers all 9 screens in one file. | Split per screen or per flow-group: `04_1_auth_screens.md`, `04_2_dashboard_screen.md`, `04_3_incident_flow_screens.md` (registration/analysis/workspace), `04_4_archive_screen.md`. |
| `sdd/backend/05_api_spec.md` | 292 | Exceeds soft limit; close to hard limit. Single file for all endpoint groups. | Split by router: `05_1_incidents_api.md`, `05_2_checklist_notes_timeline_api.md`, `05_3_fix_flows_archive_api.md`, `05_4_auth_api.md` — mirrors existing `backend/app/routers/` file boundaries. |
| `sdd/13_agent_instructions.md` | 287 | Exceeds soft limit. Seven distinct agent roles bundled into one file; each role section is independently referenceable and rarely needs the others open at once. | Split per agent: `13_1_product_spec_agent.md` … `13_7_devops_agent.md`, plus a thin `13_0_agent_roster.md` index retaining just the roster table and cross-document dependency note. |
| `sdd/backend/06_database_schema.md` | 227 | Exceeds soft limit. All tables in one document. | Split by domain: `06_1_users_incidents_schema.md`, `06_2_fix_flows_checklist_schema.md`, `06_3_timeline_notes_schema.md`. |
| `sdd/frontend/10_frontend_arch.md` | 211 | Slightly over soft limit. Mixes design tokens, component contracts, routing, state pattern, and dependencies in one doc. | Split: `10_1_folder_structure.md` (already separate), `10_2_design_tokens.md` (colors/typography/spacing — currently inline in this file), `10_3_routing_state.md` (router + Riverpod pattern + API client). |

## Within limits — no action needed

`00_index.md` (74), `07_auth_spec.md` (140), `08_ai_integration_spec.md` (182), `09_backend_arch.md` (159), `01_requirements.md` (97), `02_product_spec.md` (111), `03_user_flow.md` (155), `10_1_folder_structure.md` (197), `mock_auth_accounts.md` (51), `mock_data_spec.md` (113), `11_deployment_spec.md` (182), `12_testing_spec.md` (146), `rules/spec_authoring_rules.md` (73).

## Priority order for remediation

1. `14_responsive_design_strategy.md` — worst offender on both size and style; split before any further edits are made to it.
2. `04_screen_spec.md` and `05_api_spec.md` — both actively referenced by multiple agents per `13_agent_instructions.md`; splitting reduces context cost on every read.
3. `13_agent_instructions.md` — split is mechanical (one file per existing role section), low risk.
4. `06_database_schema.md`, `10_frontend_arch.md` — lower urgency, split opportunistically next time either is touched.

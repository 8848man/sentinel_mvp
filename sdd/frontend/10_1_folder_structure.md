## Folder Structure

```
frontend/sentinel/lib/
├── main.dart                        # app entry, ProviderScope
├── app.dart                         # MaterialApp.router + app bootstrap
│
├── design_system/                   # shared UI system; feature UI must reuse this
│   ├── design_system.dart           # barrel export
│   ├── tokens/
│   │   ├── colors.dart
│   │   ├── typography.dart
│   │   └── spacing.dart
│   └── components/
│       ├── buttons/
│       │   ├── primary_button.dart
│       │   ├── secondary_button.dart
│       │   └── ghost_button.dart
│       ├── inputs/
│       │   ├── sentinel_input.dart
│       │   ├── sentinel_textarea.dart
│       │   └── sentinel_dropdown.dart
│       ├── badges/
│       │   ├── severity_badge.dart
│       │   └── status_badge.dart
│       ├── cards/
│       │   └── incident_card.dart
│       ├── chips/
│       │   └── component_chip.dart
│       ├── modals/
│       │   └── base_dialog.dart
│       └── layout/
│           ├── two_panel_layout.dart
│           └── sentinel_scaffold.dart
│
├── core/                            # app-wide infrastructure, no feature logic
│   ├── router/
│   │   └── app_router.dart
│   ├── api/
│   │   ├── api_client.dart
│   │   └── api_endpoints.dart
│   ├── errors/
│   │   ├── app_exception.dart
│   │   └── failure.dart
│   ├── providers/
│   │   └── supabase_provider.dart
│   └── utils/
│       ├── date_time_formatter.dart
│       └── debounce.dart
│
└── features/
    ├── auth/
    │   ├── data/
    │   │   ├── datasources/
    │   │   │   └── auth_remote_datasource.dart
    │   │   ├── models/
    │   │   │   └── auth_user_model.dart
    │   │   └── repositories/
    │   │       └── auth_repository_impl.dart
    │   │
    │   ├── domain/
    │   │   ├── entities/
    │   │   │   └── auth_user.dart
    │   │   ├── repositories/
    │   │   │   └── auth_repository.dart
    │   │   └── usecases/
    │   │       ├── sign_in.dart
    │   │       ├── sign_up.dart
    │   │       └── sign_out.dart
    │   │
    │   ├── presentation/
    │   │   ├── providers/
    │   │   │   └── auth_provider.dart
    │   │   ├── screens/
    │   │   │   ├── login_screen.dart
    │   │   │   └── signup_screen.dart
    │   │   └── widgets/
    │   │
    │   └── di/
    │       └── auth_module.dart
    │
    ├── dashboard/
    │   ├── data/
    │   │   ├── datasources/
    │   │   │   └── dashboard_remote_datasource.dart
    │   │   ├── models/
    │   │   │   └── dashboard_incident_summary_model.dart
    │   │   └── repositories/
    │   │       └── dashboard_incident_repository_impl.dart
    │   │
    │   ├── domain/
    │   │   ├── entities/
    │   │   │   └── dashboard_incident_summary.dart
    │   │   ├── repositories/
    │   │   │   └── dashboard_incident_repository.dart
    │   │   └── usecases/
    │   │       └── get_dashboard_incidents.dart
    │   │
    │   ├── presentation/
    │   │   ├── providers/
    │   │   │   └── dashboard_provider.dart
    │   │   ├── screens/
    │   │   │   └── dashboard_screen.dart
    │   │   └── widgets/
    │   │       ├── status_column.dart
    │   │       └── severity_column.dart
    │   │
    │   └── di/
    │       └── dashboard_module.dart
    │
    └── incident/
        ├── data/
        │   ├── datasources/
        │   │   └── incident_remote_datasource.dart
        │   ├── models/
        │   │   ├── incident_model.dart
        │   │   ├── incident_metadata_model.dart
        │   │   ├── analysis_result_model.dart
        │   │   ├── fix_flow_model.dart
        │   │   ├── checklist_item_model.dart
        │   │   ├── timeline_event_model.dart
        │   │   ├── note_model.dart
        │   │   └── similar_incident_model.dart
        │   └── repositories/
        │       └── incident_repository_impl.dart
        │
        ├── domain/
        │   ├── entities/
        │   │   ├── incident.dart
        │   │   ├── incident_metadata.dart
        │   │   ├── analysis_result.dart
        │   │   ├── fix_flow.dart
        │   │   ├── checklist_item.dart
        │   │   ├── timeline_event.dart
        │   │   ├── note.dart
        │   │   └── similar_incident.dart
        │   ├── repositories/
        │   │   └── incident_repository.dart
        │   └── usecases/
        │       ├── analyze_incident_metadata.dart
        │       ├── create_incident.dart
        │       ├── get_incident_detail.dart
        │       ├── get_analysis_result.dart
        │       ├── select_fix_flow.dart
        │       ├── update_checklist_item.dart
        │       ├── save_note.dart
        │       ├── resolve_incident.dart
        │       └── get_archive_incidents.dart
        │
        ├── presentation/
        │   ├── shared/
        │   │   ├── providers/
        │   │   │   └── incident_detail_provider.dart
        │   │   └── widgets/
        │   │       ├── incident_detail_dialog.dart
        │   │       ├── timeline_list.dart
        │   │       ├── fix_flow_row.dart
        │   │       └── checklist_item_widget.dart
        │   │
        │   ├── registration/
        │   │   ├── providers/
        │   │   │   └── registration_provider.dart
        │   │   ├── screens/
        │   │   │   └── registration_screen.dart
        │   │   └── widgets/
        │   │       ├── architecture_component_list.dart
        │   │       └── metadata_panel.dart
        │   │
        │   ├── analysis/
        │   │   ├── providers/
        │   │   │   └── analysis_provider.dart
        │   │   ├── screens/
        │   │   │   └── analysis_screen.dart
        │   │   └── widgets/
        │   │       ├── root_cause_panel.dart
        │   │       └── similar_incident_item.dart
        │   │
        │   ├── workspace/
        │   │   ├── providers/
        │   │   │   └── workspace_provider.dart
        │   │   ├── screens/
        │   │   │   └── workspace_screen.dart
        │   │   └── widgets/
        │   │       ├── resolution_checklist.dart
        │   │       └── incident_notes_editor.dart
        │   │
        │   └── archive/
        │       ├── providers/
        │       │   └── archive_provider.dart
        │       ├── screens/
        │       │   └── archive_screen.dart
        │       └── widgets/
        │           └── archive_table.dart
        │
        └── di/
            └── incident_module.dart
```

/// Tom Forge UI — Panel shell interfaces, components, and services.
library;

// ── Actions ──
export 'src/actions/forge_action.dart';
export 'src/actions/forge_shortcut_binding.dart';
export 'src/actions/status_bar_item.dart';

// ── Adapters ──
export 'src/adapters/forge_dart_editor.dart';
export 'src/adapters/forge_md_editor.dart';
export 'src/adapters/forge_yaml_editor.dart';
export 'src/adapters/tom_forge_shell_module.dart';

// ── Components ──
export 'src/components/component_history_manager.dart';
export 'src/components/forge_component.dart';
export 'src/components/forge_editor.dart';
export 'src/components/forge_schema_editor.dart';
export 'src/components/forge_text_editor.dart';
export 'src/components/forge_view.dart';
export 'src/components/forge_visual_editor.dart';

// ── Model ──
export 'src/model/forge_application.dart';
export 'src/model/forge_config.dart';

// ── Module ──
export 'src/module/forge_module.dart';

// ── Shell ──
export 'src/shell/forge_layout_controller.dart';
export 'src/shell/forge_module_registry.dart';
export 'src/shell/forge_shell_api.dart';
export 'src/shell/forge_status_bar_controller.dart';
export 'src/shell/forge_system_state.dart';

// ── Services ──
export 'src/services/forge_clipboard.dart';
export 'src/services/forge_config_manager.dart';
export 'src/services/forge_action_registry.dart';
export 'src/services/forge_dialog_manager.dart';
export 'src/services/forge_diagnostic_manager.dart';
export 'src/services/forge_disposable.dart';
export 'src/services/forge_environment.dart';
export 'src/services/forge_file_decoration_manager.dart';
export 'src/services/forge_file_system.dart';
export 'src/services/forge_module_storage.dart';
export 'src/services/forge_notification_manager.dart';
export 'src/services/forge_outline_manager.dart';
export 'src/services/forge_output_channel_manager.dart';
export 'src/services/forge_preferences_service.dart';
export 'src/services/forge_progress_manager.dart';
export 'src/services/forge_search_manager.dart';
export 'src/services/forge_secret_storage.dart';
export 'src/services/forge_shortcut_manager.dart';
export 'src/services/forge_terminal_manager.dart';
export 'src/services/forge_undo_manager.dart';
export 'src/services/forge_virtual_document_manager.dart';
export 'src/services/forge_workspace_state_manager.dart';

// ── Testing ──
export 'src/testing/test_document.dart';
export 'src/testing/test_module.dart';
export 'src/testing/test_text_editor.dart';
export 'src/testing/test_workspace.dart';

// ── Defaults ──
export 'src/defaults/default_clipboard.dart';
export 'src/defaults/default_action_registry.dart';
export 'src/defaults/default_config_manager.dart';
export 'src/defaults/default_diagnostic_manager.dart';
export 'src/defaults/default_dialog_manager.dart';
export 'src/defaults/default_layout_controller.dart';
export 'src/defaults/default_module_registry.dart';
export 'src/defaults/default_notification_manager.dart';
export 'src/defaults/default_outline_manager.dart';
export 'src/defaults/default_output_manager.dart';
export 'src/defaults/default_progress_manager.dart';
export 'src/defaults/default_search_manager.dart';
export 'src/defaults/default_shell_api.dart';
export 'src/defaults/default_status_bar_controller.dart';
export 'src/defaults/default_system_state.dart';
export 'src/defaults/default_undo_manager.dart';
export 'src/defaults/default_workspace_state_manager.dart';
export 'src/defaults/memory_file_system.dart';
export 'src/defaults/real_file_system.dart';
export 'src/defaults/real_search_manager.dart';
export 'src/defaults/stub_services.dart';
export 'src/integrations/shell_editor_integration.dart';

// ── Widgets ──
export 'src/widgets/forge_command_palette.dart';
export 'src/widgets/forge_configuration_dialog.dart';
export 'src/widgets/forge_editor_tab_bar.dart';
export 'src/widgets/forge_menu_bar.dart';
export 'src/widgets/forge_notification_overlay.dart';
export 'src/widgets/forge_panel_widget.dart';
export 'src/widgets/forge_shell_scaffold.dart';
export 'src/widgets/forge_status_bar_widget.dart';
export 'src/widgets/workspace_folder_selector.dart';

// ── Views ──
export 'src/views/forge_file_explorer_view.dart';
export 'src/views/forge_outline_view.dart';
export 'src/views/forge_output_view.dart';
export 'src/views/forge_problems_view.dart';
export 'src/views/forge_search_view.dart';
export 'src/views/forge_terminal_view.dart';

// ── Theme ──
export 'src/theme/forge_shell_theme.dart';


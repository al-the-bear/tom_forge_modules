/// Tom Forge Shell — Forge's panel shell: its interfaces, components,
/// services and widgets, without the terminal, the code editors or the
/// platform keychain.
///
/// Those come as packages of their own (`tom_forge_terminal`,
/// `tom_forge_code_editors`, `tom_forge_platform_secrets`) and plug into the
/// shell through [ForgeShellComponents]; `package:tom_forge_ui` is all of
/// them together, with `useForgeDesktopComponents()` registering them.
library;

// ── Components the shell is assembled from ──
export 'src/shell/forge_host_ports.dart';
export 'src/shell/forge_shell_components.dart';

// ── Actions ──
export 'src/actions/forge_action.dart';
export 'src/actions/forge_shortcut_binding.dart';
export 'src/actions/forge_shortcut_menu.dart';
export 'src/actions/status_bar_item.dart';

// ── Adapters ──
export 'src/adapters/forge_plain_text_editor.dart';
export 'src/adapters/tom_forge_shell_module.dart';

// ── Components ──
export 'src/components/component_history_manager.dart';
export 'src/components/forge_component.dart';
export 'src/components/forge_editor.dart';
export 'src/components/forge_find_target.dart';
export 'src/components/forge_editor_choice.dart';
export 'src/components/forge_schema_editor.dart';
export 'src/components/forge_surface_editor.dart';
export 'src/components/forge_text_editor.dart';
export 'src/components/forge_view.dart';
export 'src/components/forge_visual_editor.dart';

// ── Model ──
export 'src/model/forge_application.dart';
export 'src/model/forge_config.dart';

// ── Providers ──
export 'src/providers/modified_file_decoration_provider.dart';

// ── Module ──
export 'src/module/forge_config_panel.dart';
export 'src/module/forge_module.dart';

// ── Shell ──
export 'src/shell/forge_context_menu_controller.dart';
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
export 'src/services/forge_module_storage.dart';
export 'src/services/forge_navigation_history.dart';
export 'src/services/forge_notification_manager.dart';
export 'src/services/forge_outline_manager.dart';
export 'src/services/forge_output_channel_manager.dart';
export 'src/services/forge_accessibility.dart';
export 'src/services/forge_preferences_service.dart';
export 'src/tools/external_tools_trail.dart' show kForgeExternalToolsDebug;
export 'src/tools/forge_external_tool.dart';
export 'src/tools/forge_external_tools_section.dart';
export 'src/services/forge_progress_manager.dart';
export 'src/services/forge_search_manager.dart';
export 'src/services/forge_secret_storage.dart';
export 'src/services/forge_shortcut_manager.dart';
export 'src/services/forge_terminal_manager.dart';
export 'src/services/forge_undo_manager.dart';
export 'src/services/forge_virtual_document_manager.dart';
export 'src/services/forge_workspace_state_manager.dart';

// The test doubles (ForgeTestDocument, ForgeTestTextEditor, ForgeTestModule,
// ForgeTestWorkspace) and the undo conformance harness are in
// package:tom_forge_ui_testing, a dev dependency of the suites using them.

// ── Defaults ──
export 'src/defaults/default_clipboard.dart';
export 'src/defaults/editor_save.dart';
export 'src/defaults/default_action_registry.dart';
export 'src/defaults/default_config_manager.dart';
export 'src/defaults/default_diagnostic_manager.dart';
export 'src/defaults/default_dialog_manager.dart';
export 'src/defaults/default_layout_controller.dart';
export 'src/defaults/default_module_registry.dart';
export 'src/defaults/default_navigation_history.dart';
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
export 'src/defaults/persistent_module_storage.dart';
export 'src/defaults/shell_autosave_controller.dart';
export 'src/defaults/stub_services.dart';
export 'src/integrations/shell_editor_integration.dart';

// ── Widgets ──
export 'src/widgets/forge_chord_overlay.dart';
export 'src/widgets/forge_command_palette.dart';
export 'src/widgets/forge_configuration_dialog.dart';
export 'src/widgets/forge_configuration_panel.dart';
export 'src/widgets/forge_drag_data.dart';
export 'src/widgets/forge_drop_zone_overlay.dart';
export 'src/widgets/forge_editor_tab_bar.dart';
export 'src/widgets/forge_error_recovery_dialog.dart';
export 'src/widgets/forge_focus_indicator.dart';
export 'src/widgets/forge_input_box_overlay.dart';
export 'src/widgets/forge_menu_bar.dart';
export 'src/widgets/forge_notification_overlay.dart';
export 'src/widgets/forge_open_with_dialog.dart';
export 'src/widgets/forge_panel_widget.dart';
export 'src/widgets/forge_quick_pick_overlay.dart';
export 'src/widgets/forge_shell_scaffold.dart';
export 'src/widgets/forge_shortcut_menu_popup.dart';
export 'src/widgets/forge_status_bar_widget.dart';

// ── Views ──
export 'src/views/forge_file_explorer_view.dart';
export 'src/views/forge_outline_view.dart';
export 'src/views/forge_output_view.dart';
export 'src/views/forge_problems_view.dart';
export 'src/views/forge_revision_view.dart';
export 'src/views/forge_search_view.dart';

// ── Theme ──
export 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart';

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
export 'src/services/forge_progress_manager.dart';
export 'src/services/forge_search_manager.dart';
export 'src/services/forge_secret_storage.dart';
export 'src/services/forge_shortcut_manager.dart';
export 'src/services/forge_terminal_manager.dart';
export 'src/services/forge_undo_manager.dart';
export 'src/services/forge_virtual_document_manager.dart';


/// Tom Forge Shell — Forge's panel shell: its interfaces, components,
/// services and widgets, without the terminal, the code editors or the
/// platform keychain.
///
/// Those come as packages of their own (`tom_forge_terminal`, the editor
/// adapters `tom_forge_md_editor`, `tom_forge_dart_editor` and
/// `tom_forge_yaml_editor`, `tom_forge_platform_secrets`) and plug into the
/// shell through [ForgeShellComponents]; `package:tom_forge_ui` is all of
/// them together, with `useForgeDesktopComponents()` registering them.
library;

// ── The kit ──
// The layout-free part of Forge — components, editors, modules, actions,
// shortcuts, the kit API, the editor host port and the default services —
// is package:tom_forge_kit. Re-exported for one release so the shell's
// consumers keep compiling; new code imports the kit itself.
export 'package:tom_forge_kit/tom_forge_kit.dart';

// ── Components the shell is assembled from ──
export 'src/shell/forge_shell_components.dart';
export 'src/shell/forge_tab_editor_host.dart';

// ── Actions ──
export 'src/actions/status_bar_item.dart';

// ── Adapters ──
export 'src/adapters/tom_forge_shell_module.dart';

// ── Components ──
export 'src/components/forge_editor_choice.dart';

// ── Model ──
export 'src/model/forge_application.dart';
export 'src/model/forge_config.dart';

// ── Module ──
export 'src/module/forge_config_panel.dart';
export 'src/module/forge_module.dart';

// ── Shell ──
export 'src/shell/forge_contributed_panels.dart';
export 'src/shell/forge_layout_controller.dart';
export 'src/shell/forge_module_registry.dart';
export 'src/shell/forge_shell_api.dart';
export 'src/shell/forge_status_bar_controller.dart';
export 'src/shell/forge_system_state.dart';

// ── Services ──
export 'src/services/forge_environment.dart';
export 'src/services/forge_preferences_service.dart';
export 'src/tools/external_tools_trail.dart' show kForgeExternalToolsDebug;
export 'src/tools/forge_external_tool.dart';
export 'src/tools/forge_external_tools_section.dart';
export 'src/services/forge_secret_storage.dart';
export 'src/services/forge_terminal_manager.dart';
export 'src/services/forge_virtual_document_manager.dart';

// The test doubles (ForgeTestDocument, ForgeTestTextEditor, ForgeTestModule,
// ForgeTestWorkspace) and the undo conformance harness are in
// package:tom_forge_ui_testing, a dev dependency of the suites using them.

// ── Defaults ──
export 'src/defaults/default_layout_controller.dart';
export 'src/defaults/default_module_registry.dart';
export 'src/defaults/default_navigation_history.dart';
export 'src/defaults/default_shell_api.dart';
export 'src/defaults/default_status_bar_controller.dart';
export 'src/defaults/default_system_state.dart';
export 'src/defaults/shell_autosave_controller.dart';
export 'src/defaults/stub_services.dart';

// ── Widgets ──
export 'src/widgets/forge_chord_overlay.dart';
export 'src/widgets/forge_command_palette.dart';
export 'src/widgets/forge_configuration_dialog.dart';
export 'src/widgets/forge_configuration_panel.dart';
export 'src/widgets/forge_drag_data.dart';
export 'src/widgets/forge_drop_zone_overlay.dart';
export 'src/widgets/forge_editor_tab_bar.dart';
export 'src/widgets/forge_menu_bar.dart';
export 'src/widgets/forge_open_with_dialog.dart';
export 'src/widgets/forge_panel_widget.dart';
export 'src/widgets/forge_shell_scaffold.dart';
export 'src/widgets/forge_shortcut_menu_popup.dart';
export 'src/widgets/forge_status_bar_widget.dart';

// ── Views ──
// The views still in the shell; the Outline, Output and Revisions views are
// packages of their own on the kit (tom_forge_outline_view,
// tom_forge_output_view, tom_forge_revision_view), contributed through the
// module registry and placed by their hints (forgeContributedPanelTabs).
export 'src/views/forge_file_explorer_view.dart';
export 'src/views/forge_problems_view.dart';
export 'src/views/forge_search_view.dart';

// ── Theme ──
export 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart';

import '../actions/forge_action.dart';
import '../actions/forge_shortcut_binding.dart';
import '../actions/forge_shortcut_menu.dart';
import '../actions/status_bar_item.dart';
import '../components/forge_editor.dart';
import '../components/forge_view.dart';
import '../model/forge_application.dart';
import '../shell/forge_shell_api.dart';
import 'forge_config_panel.dart';

/// Registration interface for shell modules.
///
/// Each module provides editors, views, actions, and shortcuts.
/// Modules are activated when the shell starts and deactivated on shutdown.
abstract class ForgeModule {
  /// Display name for the module.
  String get displayName;

  /// Called when the module is activated.
  void activate(ForgeShellApi shell);

  /// Called when the module is deactivated (shutdown).
  void deactivate();

  /// All editors this module provides.
  List<ForgeEditor> get editors;

  /// All views this module provides.
  List<ForgeView> get views;

  /// Actions this module contributes to menus and command palette.
  List<ForgeAction> get actions;

  /// Shortcut bindings this module contributes.
  List<ForgeShortcutBinding> get shortcuts;

  /// Context menu contributions.
  List<ForgeContextMenuContribution> get contextMenus => [];

  /// Custom shortcut menus activated by `Shift+Cmd/Ctrl+<key>`.
  List<ForgeShortcutMenu> get shortcutMenus => [];

  /// Status bar items this module contributes.
  List<StatusBarItem> get statusBarItems => [];

  /// Pre-configured applications this module provides.
  ///
  /// Modules can expose ready-to-use applications with pre-defined layouts
  /// that reference the module's views and editors. This allows modules
  /// to provide complete working environments.
  List<ForgeApplication> get applications => [];

  /// Configuration panels this module contributes to the settings dialog.
  ///
  /// Panels appear in the sidebar alongside built-in panels. Use
  /// [ForgeConfigPanel.priority] to control ordering (100+ recommended
  /// for modules; 0–99 is reserved for built-in panels).
  List<ForgeConfigPanel> get configPanels => [];

  /// Opens [uri] itself, when this module owns documents of that kind, and
  /// answers whether it did.
  ///
  /// The shell asks every module **before** it reads a file as text. That is
  /// the whole point: a document that is not one string — a directory bundle,
  /// an encrypted container, an archive — cannot survive the text read that
  /// the editor-routing path starts with, and a module that opens it creates
  /// its own editor per document and hands it to `layout.openEditor`. The
  /// default claims nothing, so every other file takes the usual path.
  bool openUri(Uri uri, {int? middlePanelIndex}) => false;
}

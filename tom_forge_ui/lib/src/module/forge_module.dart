import '../actions/forge_action.dart';
import '../actions/forge_shortcut_binding.dart';
import '../actions/status_bar_item.dart';
import '../components/forge_editor.dart';
import '../components/forge_view.dart';
import '../model/forge_application.dart';
import '../shell/forge_shell_api.dart';

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

  /// Status bar items this module contributes.
  List<StatusBarItem> get statusBarItems => [];

  /// Pre-configured applications this module provides.
  ///
  /// Modules can expose ready-to-use applications with pre-defined layouts
  /// that reference the module's views and editors. This allows modules
  /// to provide complete working environments.
  List<ForgeApplication> get applications => [];
}

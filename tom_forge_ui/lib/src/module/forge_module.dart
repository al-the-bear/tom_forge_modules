import 'package:tom_forge_core/tom_forge_core.dart'
    show ForgeContextMenuContribution;

import '../actions/forge_action.dart';
import '../actions/forge_shortcut_binding.dart';
import '../actions/forge_shortcut_menu.dart';
import '../actions/status_bar_item.dart';
import '../components/forge_editor.dart';
import '../components/forge_view.dart';
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
  ///
  /// A module that provides applications adds its static ones with
  /// `shell.applications.add` and registers a factory per kind it can open at
  /// run time (and recreate at the next start) with
  /// `shell.applications.registerFactory`.
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

  /// Context-menu contributions: where this module's actions are drawn as
  /// menu entries, keyed by the target kind they apply at.
  ///
  /// The shell draws them — at its own file explorer's rows
  /// ([ForgeContextTarget.explorerFileKind] and
  /// [ForgeContextTarget.explorerDirectoryKind]) and at the targets an
  /// editor reports (a [ForgeContextTargetProvider], or a call to
  /// `shell.contextMenus.show`). Each contribution names one of this
  /// module's [actions] by id, says whether it applies at a given target and
  /// why it cannot run there; the shell resolves the action, draws the entry
  /// enabled or disabled with the reason as its tooltip, and runs the action
  /// with the target under [ForgeContextTarget.parameterKey].
  List<ForgeContextMenuContribution> get contextMenus => [];

  /// Custom shortcut menus activated by `Shift+Cmd/Ctrl+<key>`.
  List<ForgeShortcutMenu> get shortcutMenus => [];

  /// Status bar items this module contributes.
  List<StatusBarItem> get statusBarItems => [];

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

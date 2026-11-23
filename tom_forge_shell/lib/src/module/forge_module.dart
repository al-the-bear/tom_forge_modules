import 'package:tom_forge_core/tom_forge_core.dart'
    show ForgeContextMenuContribution;
import 'package:tom_forge_kit/tom_forge_kit.dart';

import '../components/forge_editor_choice.dart';
import '../actions/status_bar_item.dart';
import '../shell/forge_shell_api.dart';
import '../tools/forge_external_tool.dart';
import 'forge_config_panel.dart';

/// Registration interface for shell modules: the kit's [ForgeKitModule]
/// with what the panel shell offers beyond it.
///
/// Each module provides editors, views, actions, and shortcuts.
/// Modules are activated when the shell starts and deactivated on shutdown.
/// What it contributes to the shell alone — [statusBarItems],
/// [configPanels], [externalTools] — a reader typed on [ForgeKitModule] finds
/// among its extras ([ForgeKitModuleExtras.extras]) as
/// [ForgeStatusItemsExtra], [ForgeSettingsSectionExtra] and
/// [ForgeExternalToolsExtra].
abstract class ForgeModule extends ForgeKitModule {
  ForgeModule() {
    ForgeModuleExtras.addResolver(forgeShellModuleExtras);
  }

  /// Display name for the module.
  @override
  String get displayName;

  /// Called when the module is activated.
  ///
  /// A module that provides applications adds its static ones with
  /// `shell.applications.add` and registers a factory per kind it can open at
  /// run time (and recreate at the next start) with
  /// `shell.applications.registerFactory`.
  @override
  void activate(ForgeShellApi shell);

  /// Called when the module is deactivated (shutdown).
  @override
  void deactivate();

  /// All editors this module provides.
  @override
  List<ForgeEditor> get editors;

  /// All views this module provides.
  @override
  List<ForgeView> get views;

  /// Actions this module contributes to menus and command palette.
  @override
  List<ForgeAction> get actions;

  /// Shortcut bindings this module contributes.
  @override
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
  @override
  List<ForgeContextMenuContribution> get contextMenus => [];

  /// Custom shortcut menus activated by `Shift+Cmd/Ctrl+<key>`.
  @override
  List<ForgeShortcutMenu> get shortcutMenus => [];

  /// Status bar items this module contributes.
  List<StatusBarItem> get statusBarItems => [];

  /// Configuration panels this module contributes to the settings dialog.
  ///
  /// Panels appear in the sidebar alongside built-in panels. Use
  /// [ForgeConfigPanel.priority] to control ordering (100+ recommended
  /// for modules; 0–99 is reserved for built-in panels).
  List<ForgeConfigPanel> get configPanels => [];

  /// External tools this module uses (LibreOffice, pandoc, ...): each is a
  /// row of the Configuration panel's *External Tools* section, with its path
  /// setting `forge.tools.<id>.path`.
  List<ForgeExternalTool> get externalTools => [];

  /// Opens [uri] itself, when this module owns documents of that kind, and
  /// answers whether it did.
  ///
  /// The shell asks every module **before** it reads a file as text. That is
  /// the whole point: a document that is not one string — a directory bundle,
  /// an encrypted container, an archive — cannot survive the text read that
  /// the editor-routing path starts with, and a module that opens it creates
  /// its own editor per document and hands it to `layout.openEditor`. The
  /// default claims nothing, so every other file takes the usual path.
  @override
  bool openUri(Uri uri, {int? middlePanelIndex}) => false;

  /// The editors this module has for [uri], as **Open With** offers them
  /// (`ForgeLayoutController.openFileWith`): the shell gathers every
  /// module's and lets the user pick when there is more than one. A module
  /// that opens files of a kind names its editor for them, and any other it
  /// offers for this file; the default offers none.
  @override
  List<ForgeEditorChoice> editorChoicesFor(Uri uri) => const [];
}

/// The shell's contributions of [module] as [ForgeModuleExtra]s: its status
/// items, each settings section and its external tools — the resolver
/// [ForgeModule] registers with [ForgeModuleExtras]; null for a module that
/// is not a [ForgeModule].
List<ForgeModuleExtra>? forgeShellModuleExtras(ForgeKitModule module) {
  if (module is! ForgeModule) return null;
  final statusItems = module.statusBarItems;
  final tools = module.externalTools;
  return [
    if (statusItems.isNotEmpty) ForgeStatusItemsExtra(statusItems),
    for (final panel in module.configPanels) ForgeSettingsSectionExtra(panel),
    if (tools.isNotEmpty) ForgeExternalToolsExtra(tools),
  ];
}

/// A module's status bar items ([ForgeModule.statusBarItems]) as an extra.
class ForgeStatusItemsExtra extends ForgeModuleExtra {
  const ForgeStatusItemsExtra(List<StatusBarItem> items)
    : super(kind: kindId, value: items);

  /// The kind of this extra.
  static const kindId = 'forge.shell.statusItems';

  /// The items.
  List<StatusBarItem> get items => value as List<StatusBarItem>;
}

/// One settings section of a module ([ForgeModule.configPanels]) as an
/// extra.
class ForgeSettingsSectionExtra extends ForgeModuleExtra {
  const ForgeSettingsSectionExtra(ForgeConfigPanel section)
    : super(kind: kindId, value: section);

  /// The kind of this extra.
  static const kindId = 'forge.shell.settingsSection';

  /// The section.
  ForgeConfigPanel get section => value as ForgeConfigPanel;
}

/// A module's external tools ([ForgeModule.externalTools]) as an extra.
class ForgeExternalToolsExtra extends ForgeModuleExtra {
  const ForgeExternalToolsExtra(List<ForgeExternalTool> tools)
    : super(kind: kindId, value: tools);

  /// The kind of this extra.
  static const kindId = 'forge.shell.externalTools';

  /// The tools.
  List<ForgeExternalTool> get tools => value as List<ForgeExternalTool>;
}

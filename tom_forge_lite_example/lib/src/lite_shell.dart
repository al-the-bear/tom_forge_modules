import 'package:flutter/material.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show ForgePanelLocation;
import 'package:tom_forge_file_explorer/tom_forge_file_explorer.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart'
    show forgeThemeData;
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show
        DefaultLayoutController,
        DefaultModuleRegistry,
        DefaultShellApi,
        DefaultSystemState,
        ForgeApplication,
        ForgePreferencesService,
        ForgeShellComponents,
        ForgeShellScaffold,
        MiddlePanelConfig,
        PanelConfig,
        PanelLayout,
        TomForgeShellModule,
        forgeContributedPanelTabs;
import 'package:tom_forge_yaml_editor/tom_forge_yaml_editor.dart';

/// The id of the example's one application.
const liteApplicationId = 'tom-forge-lite';

/// What the light shell is given: the YAML editor type, nothing else. The
/// shell falls back to its plain-text editor for every other file; there is
/// no terminal, no code editor beside YAML, no keychain and no desktop host.
final ForgeShellComponents liteShellComponents = ForgeShellComponents(
  editorTypes: [forgeYamlEditorType],
);

/// The light panel shell: Forge's panel shell over [fileSystem] with the
/// file explorer on the left and the YAML editor in the middle.
///
/// Assembled from the parts themselves, without `composeForgeSuite`:
///
/// 1. a [DefaultShellApi] over the workspace's file system, given
///    [liteShellComponents] (the YAML editor type);
/// 2. the shell's own module ([TomForgeShellModule]: the shell actions and
///    the standard editing actions, undo and redo among them, and the owner
///    of the editors the editor types make);
/// 3. the file explorer's kit module ([forgeFileExplorerModule]), which
///    makes the view at activation and hands over its placement hint;
/// 4. one panel application whose left panel is laid out from the
///    contributed views ([forgeContributedPanelTabs]), the middle a single
///    editor panel, right and bottom empty.
class LiteForgeShell {
  LiteForgeShell._(
    this.shell,
    this.navigatorKey,
    this.shellModule,
    this.explorerModule,
  );

  /// Composes the light shell for [workspaceRoot] over [fileSystem].
  ///
  /// [stateStore] keeps the shell's preferences (default: the platform's
  /// shared preferences); a test gives a [ForgeMemoryStateStore].
  factory LiteForgeShell.compose({
    required TomFileSystem fileSystem,
    required String workspaceRoot,
    GlobalKey<NavigatorState>? navigatorKey,
    ForgeStateStore? stateStore,
  }) {
    final key = navigatorKey ?? GlobalKey<NavigatorState>();
    final shell = DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: fileSystem,
      appName: 'Tom Forge Lite',
      navigatorKey: key,
      components: liteShellComponents,
      stateStore: stateStore,
    );
    (shell.systemState as DefaultSystemState).setWorkspaceRootPath(
      workspaceRoot,
    );
    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);
    (shell.modules as DefaultModuleRegistry).register(shellModule);
    final explorerModule = forgeFileExplorerModule(
      rootUri: Uri.directory(workspaceRoot),
    );
    shell.registerModule(explorerModule);
    shell.applications.add(
      ForgeApplication(
        id: liteApplicationId,
        title: 'Tom Forge Lite',
        workspaceFolder: Uri.directory(
          workspaceRoot,
        ).pathSegments.where((s) => s.isNotEmpty).lastOrNull,
        layout: PanelLayout(
          leftPanel: PanelConfig(
            initialSize: 260,
            tabs: forgeContributedPanelTabs(
              shell.modules,
              ForgePanelLocation.left,
            ),
          ),
          rightPanel: const PanelConfig(initialSize: 200, tabs: []),
          bottomPanel: const PanelConfig(initialSize: 160, tabs: []),
          middlePanels: const [MiddlePanelConfig()],
        ),
      ),
    );
    return LiteForgeShell._(shell, key, shellModule, explorerModule);
  }

  /// The shell API: the layout, the file system, the actions.
  final DefaultShellApi shell;

  /// The navigator the shell routes its dialogs through: the app's.
  final GlobalKey<NavigatorState> navigatorKey;

  /// The shell's own module.
  final TomForgeShellModule shellModule;

  /// The file explorer's module; its view is [ForgeFileExplorerModule.view]
  /// once registered.
  final ForgeFileExplorerModule explorerModule;

  /// The shell's layout controller (opens files, holds the panels).
  DefaultLayoutController get layout => shell.layout as DefaultLayoutController;
}

/// The example's root widget: the shell's scaffold in a [MaterialApp] with
/// Forge's theme. The scaffold disposes the shell when it leaves the tree.
class LiteForgeApp extends StatelessWidget {
  const LiteForgeApp({super.key, required this.lite, this.preferences});

  final LiteForgeShell lite;

  /// The preferences the scaffold reads; default the shell's store's.
  final ForgePreferencesService? preferences;

  @override
  Widget build(BuildContext context) {
    final shell = lite.shell;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tom Forge Lite',
      navigatorKey: lite.navigatorKey,
      theme: forgeThemeData(Brightness.light),
      darkTheme: forgeThemeData(Brightness.dark),
      home: ForgeShellScaffold(
        shell: shell,
        layoutController: lite.layout,
        systemState: shell.systemState as DefaultSystemState,
        statusBarController: shell.statusBar,
        notificationManager: shell.notifications as DefaultNotificationManager,
        preferencesService: preferences,
      ),
    );
  }
}

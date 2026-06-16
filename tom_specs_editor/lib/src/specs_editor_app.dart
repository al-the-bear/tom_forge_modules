import 'package:flutter/material.dart';
import 'package:tom_forge_agentic/tom_forge_agentic.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'spec_structure_module.dart';
import 'specs_shell_module.dart';

/// Root widget for the TomSpecs Editor.
///
/// Step 9 registers the [SpecsShellModule], which contributes the three
/// top-level applications (DocSpecs / CodeSpecs / Implementation) and their
/// 4-region layouts (§4.2, §5). DocSpecs is shown on launch and is the only
/// functional one — its four regions are populated with placeholder
/// views/editors. The shell toolbar's application switcher lets the user move
/// between the three; selecting one calls [onApplicationSwitch], which
/// re-renders the scaffold with the chosen application's layout.
///
/// The spec-specific editors/views (structure browser, document editor, chat
/// suite, change log) arrive in later steps (10–18).
class SpecsEditorApp extends StatefulWidget {
  const SpecsEditorApp({super.key, this.chatModule});

  /// The agent chat module hosting the bottom-panel connection picker. The
  /// production app supplies its own (which scans 19900–19909 on launch);
  /// tests inject one whose controller wraps a fake service so no real sockets
  /// are opened.
  final AgentChatModule? chatModule;

  @override
  State<SpecsEditorApp> createState() => _SpecsEditorAppState();
}

class _SpecsEditorAppState extends State<SpecsEditorApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final DefaultShellApi _shell;
  late final SpecStructureModule _structureModule;
  late final AgentChatModule _chatModule;
  late final SpecsShellModule _shellModule;
  late ForgeApplication _application;

  @override
  void initState() {
    super.initState();
    _shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'TomSpecs Editor',
      navigatorKey: _navigatorKey,
    );

    // The structure module owns the structure browser + review store; it is
    // registered first so its view exists before the shell builds the DocSpecs
    // layout that hosts it as a panel tab.
    _structureModule = SpecStructureModule();
    _structureModule.activate(_shell);
    (_shell.modules as DefaultModuleRegistry).register(_structureModule);

    // The agent chat module owns the bridge connection picker; it is registered
    // before the shell so its chat view exists when the DocSpecs bottom panel
    // is built. Activation kicks off the port scan (19900–19909).
    _chatModule = widget.chatModule ?? AgentChatModule();
    _chatModule.activate(_shell);
    (_shell.modules as DefaultModuleRegistry).register(_chatModule);

    // The shell module registers the three applications and selects DocSpecs,
    // hosting the structure view as the DocSpecs left panel's "Structure" tab
    // and the agent chat view as the bottom panel's "Chat" tab.
    _shellModule = SpecsShellModule(
      structureView: _structureModule.structureView,
      chatView: _chatModule.chatView,
    );
    _shellModule.activate(_shell);
    (_shell.modules as DefaultModuleRegistry).register(_shellModule);

    // Start on DocSpecs — the one functional application.
    _application = _shellModule.docSpecs;
  }

  // The shell owns app-lifetime layout/system notifiers that the
  // [ForgeShellScaffold] subtree listens to; disposing it here would race the
  // framework's own teardown of those listeners. Like `tom_forge_app`, the
  // shell lives for the lifetime of the process and is not disposed per-widget.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: _application.title,
      navigatorKey: _navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: ForgeShellScaffold(
        shell: _shell,
        application: _application,
        layoutController: _shell.layout as DefaultLayoutController,
        systemState: _shell.systemState as DefaultSystemState,
        statusBarController: _shell.statusBar,
        notificationManager:
            _shell.notifications as DefaultNotificationManager,
        onApplicationSwitch: (app) =>
            setState(() => _application = app),
      ),
    );
  }
}

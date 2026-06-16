import 'package:flutter/material.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

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
  const SpecsEditorApp({super.key});

  @override
  State<SpecsEditorApp> createState() => _SpecsEditorAppState();
}

class _SpecsEditorAppState extends State<SpecsEditorApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final DefaultShellApi _shell;
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

    // The shell module registers the three applications and selects DocSpecs.
    _shellModule = SpecsShellModule();
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

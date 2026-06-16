import 'package:flutter/material.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

/// Root widget for the TomSpecs Editor.
///
/// Step 8 (scaffold) launches a **blank Forge shell**: an in-memory
/// [DefaultShellApi] and an empty [ForgeApplication] rendered through the
/// standard [ForgeShellScaffold]. No custom modules or panels are wired yet —
/// the `SpecsShellModule` and the 4-region DocSpecs layout arrive in step 9,
/// and the spec-specific editors/views in later steps.
class SpecsEditorApp extends StatefulWidget {
  const SpecsEditorApp({super.key});

  @override
  State<SpecsEditorApp> createState() => _SpecsEditorAppState();
}

class _SpecsEditorAppState extends State<SpecsEditorApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final DefaultShellApi _shell;
  late final ForgeApplication _application;

  @override
  void initState() {
    super.initState();
    _shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'TomSpecs Editor',
      navigatorKey: _navigatorKey,
    );
    _application = ForgeApplication(
      title: 'TomSpecs Editor',
      layout: const ApplicationLayout(
        leftPanel: PanelConfig(initialSize: 250, tabs: []),
        rightPanel: PanelConfig(initialSize: 220, tabs: []),
        bottomPanel: PanelConfig(initialSize: 180, tabs: []),
        middlePanels: [MiddlePanelConfig()],
      ),
    );
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
      ),
    );
  }
}

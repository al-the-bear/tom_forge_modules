import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

void main() {
  testWidgets('save shortcut uses platform primary modifier', (
    WidgetTester tester,
  ) async {
    // Suppress layout overflow errors – the default test surface is too
    // small for the full scaffold, but that's irrelevant for shortcut logic.
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      oldOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = oldOnError);

    final harness = _ShortcutHarness.create();

    await tester.pumpWidget(harness.buildShellApp());
    await tester.pumpAndSettle();

    // ForgeShellScaffold registers its own concrete file.saveAll handler in
    // initState, which shadows any earlier module registration. Reinstall the
    // probe action as the effective handler so this test can observe that the
    // primary+S shortcut dispatches the file.saveAll action id.
    for (final action in harness.module.actions) {
      harness.shell.actionRegistry.registerAction(action);
    }

    final usesMeta = defaultTargetPlatform == TargetPlatform.macOS;
    final modifier = usesMeta
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;

    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();

    expect(harness.module.executedActionIds, contains('file.saveAll'));
  });
}

class _ShortcutHarness {
  _ShortcutHarness._({
    required this.shell,
    required this.module,
    required this.application,
  });

  final DefaultShellApi shell;
  final _SaveActionModule module;
  final ForgeApplication application;

  static _ShortcutHarness create() {
    final navigatorKey = GlobalKey<NavigatorState>();
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'Shortcut Test',
      navigatorKey: navigatorKey,
    );

    final module = _SaveActionModule();
    module.activate(shell);
    (shell.modules as DefaultModuleRegistry).register(module);

    final application = ForgeApplication(
      title: 'Shortcut Test',
      layout: const ApplicationLayout(
        leftPanel: PanelConfig(initialSize: 250, tabs: []),
        rightPanel: PanelConfig(initialSize: 220, tabs: []),
        bottomPanel: PanelConfig(initialSize: 180, tabs: []),
        middlePanels: [MiddlePanelConfig()],
      ),
    );

    return _ShortcutHarness._(
      shell: shell,
      module: module,
      application: application,
    );
  }

  Widget buildShellApp() {
    return MaterialApp(
      home: ForgeShellScaffold(
        shell: shell,
        application: application,
        layoutController: shell.layout as DefaultLayoutController,
        systemState: shell.systemState as DefaultSystemState,
        statusBarController: shell.statusBar,
        notificationManager: shell.notifications as DefaultNotificationManager,
      ),
    );
  }
}

class _SaveActionModule extends ForgeModule {
  final List<String> executedActionIds = <String>[];

  @override
  String get displayName => 'Save Action Module';

  @override
  void activate(ForgeShellApi shell) {
    final saveAction = actions.first;
    shell.actionRegistry.registerAction(saveAction);
  }

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  List<ForgeAction> get actions => <ForgeAction>[
        ForgeAction(
          id: 'file.saveAll',
          label: 'Save All',
          execute: (_) async {
            executedActionIds.add('file.saveAll');
            return null;
          },
          isEnabled: () => true,
          isVisible: () => true,
        ),
      ];
}

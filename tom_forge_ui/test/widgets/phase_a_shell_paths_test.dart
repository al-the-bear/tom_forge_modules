import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Command palette executes file.save action', (
    WidgetTester tester,
  ) async {
    final harness = _PhaseAHarness.create();

    await tester.pumpWidget(harness.buildPaletteApp());
    await tester.pumpAndSettle();

    // Type in the search field to filter down to the Save action.
    await tester.enterText(find.byType(TextField), 'Save');
    await tester.pumpAndSettle();

    // Tap the "Save" item in the list (not the search field text).
    final saveInList = find.descendant(
      of: find.byType(InkWell),
      matching: find.text('Save'),
    );
    await tester.tap(saveInList.first);
    await tester.pumpAndSettle();

    expect(harness.module.executedActionIds, contains('file.save'));
  });

  testWidgets('Shell shortcut executes file.save action', (
    WidgetTester tester,
  ) async {
    final harness = _PhaseAHarness.create();

    await tester.pumpWidget(harness.buildShellApp());
    await tester.pumpAndSettle();

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

class _PhaseAHarness {
  _PhaseAHarness._({
    required this.shell,
    required this.module,
    required this.application,
    required this.navigatorKey,
  });

  final DefaultShellApi shell;
  final _ActionProbeModule module;
  final ForgeApplication application;
  final GlobalKey<NavigatorState> navigatorKey;

  static _PhaseAHarness create() {
    final navigatorKey = GlobalKey<NavigatorState>();
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'Phase A Harness',
      navigatorKey: navigatorKey,
    );

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);

    final module = _ActionProbeModule();
    module.activate(shell);

    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(shellModule);
    registry.register(module);

    final application = ForgeApplication(
      title: 'Phase A Harness',
      layout: const ApplicationLayout(
        leftPanel: PanelConfig(initialSize: 250, tabs: []),
        rightPanel: PanelConfig(initialSize: 220, tabs: []),
        bottomPanel: PanelConfig(initialSize: 180, tabs: []),
        middlePanels: [MiddlePanelConfig()],
      ),
    );

    return _PhaseAHarness._(
      shell: shell,
      module: module,
      application: application,
      navigatorKey: navigatorKey,
    );
  }

  Widget buildPaletteApp() {
    return MaterialApp(
      home: Scaffold(
        body: ForgeCommandPalette(
          shellApi: shell,
          onDismiss: () {},
        ),
      ),
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

class _ActionProbeModule extends ForgeModule {
  final List<String> executedActionIds = <String>[];

  @override
  String get displayName => 'Action Probe Module';

  @override
  void activate(ForgeShellApi shell) {}

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
          id: 'file.save',
          label: 'Save',
          execute: (_) async {
            executedActionIds.add('file.save');
            return null;
          },
          isEnabled: () => true,
          isVisible: () => true,
        ),
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

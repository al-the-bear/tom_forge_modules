import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_forge_core/tom_forge_core.dart'
  show FileHandlingResult;
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';

import 'support/shell_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase Q: configuration auto-save, layout, and limits', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('01: opening Terminal collapses unpinned Shell section', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseQHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      expect(configSettingEntry(ForgeShellConfiguration.themeMode), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);

      await _openConfigSection(tester, 'Terminal');

      expect(find.text('Default Shell'), findsOneWidget);
      expect(find.text('Theme'), findsNothing);
      expect(configSettingEntry(ForgeShellConfiguration.themeMode), findsNothing);
    });

    testWidgets('02: reopening Shell collapses Terminal section again', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseQHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'Terminal');
      expect(find.text('Default Shell'), findsOneWidget);
      expect(find.text('Theme'), findsNothing);

      await _openConfigSection(tester, 'Shell');

      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Default Shell'), findsNothing);
    });

    testWidgets('03: auto-save Enabled toggle updates shell config', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseQHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);

      final before = harness.shell.config.current.autoSave.enabled;
      await tapConfigSwitch(tester, ForgeShellConfiguration.autoSaveEnabled);

      expect(harness.shell.config.current.autoSave.enabled, equals(!before));
    });

    testWidgets('04: auto-save focus-loss toggle updates shell config', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseQHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);

      final before = harness.shell.config.current.autoSave.saveOnFocusLoss;
      await tapConfigSwitch(
        tester,
        ForgeShellConfiguration.autoSaveOnFocusLoss,
      );

      expect(
        harness.shell.config.current.autoSave.saveOnFocusLoss,
        equals(!before),
      );
    });

    testWidgets('05: idle delay value 0 is refused and the delay kept', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseQHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);

      final setting = ForgeShellConfiguration.autoSaveIdleDelay;
      await enterConfigSetting(tester, setting, '5');
      expect(
        harness.shell.config.current.autoSave.idleDelay,
        equals(const Duration(seconds: 5)),
      );

      // Below the minimum: refused with the reason, nothing written.
      await enterConfigSetting(tester, setting, '0');
      expect(configSettingError(setting, 'At least 1.'), findsOneWidget);
      expect(
        harness.shell.config.current.autoSave.idleDelay,
        equals(const Duration(seconds: 5)),
      );
    });

    testWidgets('06: search max results below 1 is refused', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseQHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);

      final setting = ForgeShellConfiguration.searchMaxFileResults;
      await enterConfigSetting(tester, setting, '1');
      expect(harness.preferences.searchConfig.maxFileResults, equals(1));

      await enterConfigSetting(tester, setting, '0');
      expect(configSettingError(setting, 'At least 1.'), findsOneWidget);
      expect(harness.preferences.searchConfig.maxFileResults, equals(1));
    });

    testWidgets('07: search max results above 1000 is refused', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseQHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);

      final setting = ForgeShellConfiguration.searchMaxFileResults;
      await enterConfigSetting(tester, setting, '1000');
      expect(harness.preferences.searchConfig.maxFileResults, equals(1000));

      await enterConfigSetting(tester, setting, '50000');
      expect(configSettingError(setting, 'At most 1000.'), findsOneWidget);
      expect(harness.preferences.searchConfig.maxFileResults, equals(1000));
    });

    testWidgets('08: shell layout dimension fields persist to preferences', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseQHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);

      await enterConfigSetting(
        tester,
        ForgeShellConfiguration.panelContentMinWidth,
        '510',
      );
      await enterConfigSetting(
        tester,
        ForgeShellConfiguration.rightPanelDefaultWidth,
        '366',
      );
      await enterConfigSetting(
        tester,
        ForgeShellConfiguration.bottomPanelDefaultHeight,
        '244',
      );
      await enterConfigSetting(
        tester,
        ForgeShellConfiguration.dividerHitTarget,
        '21',
      );

      expect(harness.preferences.panelContentMinWidth, equals(510));
      expect(harness.preferences.rightPanelDefaultWidth, equals(366));
      expect(harness.preferences.bottomPanelDefaultHeight, equals(244));
      expect(harness.preferences.dividerHitTarget, equals(21));
    });

    testWidgets('09: terminal size and scrollback fields update preferences', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseQHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'Terminal');

      await enterConfigSetting(
        tester,
        ForgeShellConfiguration.terminalFontSize,
        '18',
      );
      await enterConfigSetting(
        tester,
        ForgeShellConfiguration.terminalScrollbackLines,
        '22222',
      );

      expect(harness.preferences.terminalFontSize, equals(18));
      expect(harness.preferences.terminalScrollbackLines, equals(22222));
    });

    testWidgets('10: primary+R toggles right panel while settings are open', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseQHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);

      final layout = harness.shell.layout as DefaultLayoutController;
      expect(layout.rightPanel.value.isVisible, isTrue);

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyR);
      await tester.pumpAndSettle();
      expect(layout.rightPanel.value.isVisible, isFalse);

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyR);
      await tester.pumpAndSettle();
      expect(layout.rightPanel.value.isVisible, isTrue);
    });
  });
}

Future<void> _openSettingsViaFileMenu(WidgetTester tester) async {
  await tester.tap(find.text('File'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Settings...').last);
  await tester.pumpAndSettle();
}

Future<void> _openConfigSection(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

class _PhaseQHarness {
  _PhaseQHarness._({
    required this.shell,
    required this.module,
    required this.application,
    required this.preferences,
  });

  final DefaultShellApi shell;
  final _PhaseQModule module;
  final ForgeApplication application;
  final ForgePreferencesService preferences;

  static _PhaseQHarness create() {
    final workspaceRoot =
        '${Directory.current.path}/test/phase_q_fixture_workspace';
    final workspaceDir = Directory(workspaceRoot);
    if (workspaceDir.existsSync()) {
      workspaceDir.deleteSync(recursive: true);
    }
    workspaceDir.createSync(recursive: true);

    addTearDown(() {
      if (workspaceDir.existsSync()) {
        workspaceDir.deleteSync(recursive: true);
      }
    });

    final navigatorKey = GlobalKey<NavigatorState>();
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: {
        '$workspaceRoot/test-fixtures/main.test': 'main\n',
      },
      appName: 'Phase Q Harness',
      navigatorKey: navigatorKey,
    );
    (shell.systemState as DefaultSystemState).setWorkspaceRootPath(workspaceRoot);

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);

    final module = _PhaseQModule(workspaceRoot: workspaceRoot);
    module.activate(shell);

    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(shellModule);
    registry.register(module);

    final application = ForgeApplication(
      id: 'phase-q-harness',
      title: 'Phase Q Harness',
      layout: PanelLayout(
        leftPanel: PanelConfig(
          initialSize: 240,
          tabs: [
            PanelTabConfig(
              title: 'Explorer',
              icon: Icons.folder,
              sections: [module.explorerView],
            ),
          ],
        ),
        rightPanel: PanelConfig(
          initialSize: 220,
          tabs: [
            PanelTabConfig(
              title: 'Outline',
              icon: Icons.account_tree,
              sections: [module.outlineView],
            ),
          ],
        ),
        bottomPanel: PanelConfig(
          initialSize: 180,
          tabs: [
            const PanelTabConfig(
              title: 'Terminal',
              terminalSections: true,
              icon: Icons.terminal,
              sections: [],
            ),
            PanelTabConfig(
              title: 'Problems',
              icon: Icons.error_outline,
              sections: [module.problemsView],
            ),
          ],
        ),
        middlePanels: const [MiddlePanelConfig()],
      ),
    );
    shell.applications.add(application);

    final layout = shell.layout as DefaultLayoutController;
    layout.openEditor(module.mainEditor, module.mainEditor.uri, middlePanelIndex: 0);

    final preferences = ForgePreferencesService();

    return _PhaseQHarness._(
      shell: shell,
      module: module,
      application: application,
      preferences: preferences,
    );
  }

  Widget buildShellApp() {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 2200,
          height: 1200,
          child: ForgeShellScaffold(
            shell: shell,
            layoutController: shell.layout as DefaultLayoutController,
            systemState: shell.systemState as DefaultSystemState,
            statusBarController: shell.statusBar,
            notificationManager: shell.notifications as DefaultNotificationManager,
            preferencesService: preferences,
          ),
        ),
      ),
    );
  }
}

class _PhaseQModule extends ForgeModule {
  _PhaseQModule({required String workspaceRoot}) {
    mainEditor = _PhaseQMainEditor(this, workspaceRoot: workspaceRoot);
    explorerView = _StubView('Explorer View', Icons.folder);
    outlineView = _StubView('Outline View', Icons.account_tree);
    problemsView = _StubView('Problems View', Icons.error_outline);
  }

  late final _PhaseQMainEditor mainEditor;
  late final _StubView explorerView;
  late final _StubView outlineView;
  late final _StubView problemsView;

  @override
  String get displayName => 'Phase Q Module';

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => [mainEditor];

  @override
  List<ForgeView> get views => [explorerView, outlineView, problemsView];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
}

class _PhaseQMainEditor extends ForgeTestTextEditor {
  _PhaseQMainEditor(
    super.module, {
    required String workspaceRoot,
  }) : super(
          document: ForgeTestDocument(
            uri: Uri.file('$workspaceRoot/test-fixtures/main.test'),
            content: 'main\n',
          ),
        );

  @override
  FileHandlingResult canHandle(Uri uri) {
    return uri.path.endsWith('/main.test')
        ? FileHandlingResult.accept
        : FileHandlingResult.reject;
  }
}

class _StubView extends ForgeView {
  _StubView(this._title, this._icon);

  final String _title;
  final IconData _icon;
  final ValueNotifier<String> _titleNotifier = ValueNotifier<String>('');
  final ValueNotifier<String?> _titleExtension = ValueNotifier<String?>(null);

  @override
  ValueListenable<String> get title {
    _titleNotifier.value = _title;
    return _titleNotifier;
  }

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => _icon;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) {
    return Center(child: Text(_title));
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

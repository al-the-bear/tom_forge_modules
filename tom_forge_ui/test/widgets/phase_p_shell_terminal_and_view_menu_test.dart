import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_forge_core/tom_forge_core.dart'
  show FileHandlingResult, ForgePanelLocation;
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';

import 'support/shell_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase P: shell and terminal settings with view menu paths', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('01: shell theme segmented button updates preferences', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhasePHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      final lightSegment = find.widgetWithText(TextButton, 'Light');
      expect(lightSegment, findsOneWidget);
      await tester.ensureVisible(lightSegment);
      await tester.pumpAndSettle();
      await tester.tap(lightSegment);
      await tester.pumpAndSettle();

      expect(harness.preferences.themeMode, equals(ThemeMode.light));
    });

    testWidgets('02: shell max recent field updates preferences', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhasePHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await enterConfigSetting(
        tester,
        ForgeShellConfiguration.maxRecentWorkspaces,
        '17',
      );

      expect(harness.preferences.maxRecentWorkspaces, equals(17));
    });

    testWidgets('03: shell reduce motion toggle updates preferences', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhasePHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);

      final before = harness.preferences.reduceMotion;
      expect(
        configSettingSwitchValue(tester, ForgeShellConfiguration.reduceMotion),
        equals(before),
      );
      await tapConfigSwitch(tester, ForgeShellConfiguration.reduceMotion);

      expect(harness.preferences.reduceMotion, equals(!before));
    });

    testWidgets('04: shell left panel width field updates preferences', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhasePHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await enterConfigSetting(
        tester,
        ForgeShellConfiguration.leftPanelDefaultWidth,
        '333',
      );

      expect(harness.preferences.leftPanelDefaultWidth, equals(333));
    });

    testWidgets('05: terminal default shell empty value persists as null', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhasePHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'Terminal');

      final shellField = _terminalDefaultShellField();
      expect(shellField, findsOneWidget);

      await tester.enterText(shellField, '/bin/zsh');
      await tester.pumpAndSettle();
      expect(harness.preferences.terminalDefaultShell, equals('/bin/zsh'));

      await tester.enterText(shellField, '');
      await tester.pumpAndSettle();
      expect(harness.preferences.terminalDefaultShell, isNull);
    });

    testWidgets('06: terminal start folder dropdown updates preferences', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhasePHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'Terminal');

      final dropdown = find.byType(DropdownButtonFormField<String>).first;
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Last used directory').last);
      await tester.pumpAndSettle();

      expect(harness.preferences.terminalStartFolder, equals('lastUsed'));
    });

    testWidgets('07: terminal font family field updates preferences', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhasePHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'Terminal');

      await enterConfigSetting(
        tester,
        ForgeShellConfiguration.terminalFontFamily,
        'FiraCode',
      );

      expect(harness.preferences.terminalFontFamily, equals('FiraCode'));
    });

    testWidgets('08: View menu Toggle Right Panel hides and reopens panel', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhasePHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      expect(layout.rightPanel.value.isVisible, isTrue);

      await _selectViewMenuItem(tester, 'Toggle Right Panel');
      expect(layout.rightPanel.value.isVisible, isFalse);

      await _selectViewMenuItem(tester, 'Toggle Right Panel');
      expect(layout.rightPanel.value.isVisible, isTrue);
    });

    testWidgets('09: View menu theme item updates shell theme preference', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhasePHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _selectViewMenuItem(tester, 'Light Theme');
      expect(harness.preferences.themeMode, equals(ThemeMode.light));

      await _selectViewMenuItem(tester, 'Dark Theme');
      expect(harness.preferences.themeMode, equals(ThemeMode.dark));
    });

    testWidgets('10: View menu Middle Panel 4 keeps index when only three panels', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhasePHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      layout.splitMiddlePanel();
      layout.splitMiddlePanel();
      await tester.pumpAndSettle();
      expect(layout.middlePanels.value.length, equals(3));

      layout.setActiveMiddlePanelIndex(2);
      expect(layout.activeMiddlePanelIndex, equals(2));

      await _selectViewMenuItem(tester, 'Middle Panel 4');

      expect(layout.activeMiddlePanelIndex, equals(2));
      expect(
        harness.shell.systemState.focusedPanelLocation,
        equals(ForgePanelLocation.middle),
      );
    });
  });
}

Future<void> _openSettingsViaFileMenu(WidgetTester tester) async {
  await tester.tap(find.text('File'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Settings...').last);
  await tester.pumpAndSettle();
}

Future<void> _selectViewMenuItem(WidgetTester tester, String label) async {
  await tester.tap(find.text('View'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _openConfigSection(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

Finder _terminalDefaultShellField() {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == '/bin/bash',
  );
}

class _PhasePHarness {
  _PhasePHarness._({
    required this.shell,
    required this.module,
    required this.application,
    required this.preferences,
  });

  final DefaultShellApi shell;
  final _PhasePModule module;
  final ForgeApplication application;
  final ForgePreferencesService preferences;

  static _PhasePHarness create() {
    final workspaceRoot =
        '${Directory.current.path}/test/phase_p_fixture_workspace';
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
      appName: 'Phase P Harness',
      navigatorKey: navigatorKey,
    );
    (shell.systemState as DefaultSystemState).setWorkspaceRootPath(workspaceRoot);

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);

    final module = _PhasePModule(workspaceRoot: workspaceRoot);
    module.activate(shell);

    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(shellModule);
    registry.register(module);

    final application = ForgeApplication(
      id: 'phase-p-harness',
      title: 'Phase P Harness',
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

    return _PhasePHarness._(
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

class _PhasePModule extends ForgeModule {
  _PhasePModule({required String workspaceRoot}) {
    mainEditor = _PhasePMainEditor(this, workspaceRoot: workspaceRoot);
    explorerView = _StubView('Explorer View', Icons.folder);
    outlineView = _StubView('Outline View', Icons.account_tree);
    problemsView = _StubView('Problems View', Icons.error_outline);
  }

  late final _PhasePMainEditor mainEditor;
  late final _StubView explorerView;
  late final _StubView outlineView;
  late final _StubView problemsView;

  @override
  String get displayName => 'Phase P Module';

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

class _PhasePMainEditor extends ForgeTestTextEditor {
  _PhasePMainEditor(
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

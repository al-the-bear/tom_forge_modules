import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show ForgePanelLocation;
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';

import 'support/shell_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase I: configuration panel deep coverage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('01: opening settings re-opens hidden side panels', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseIHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      layout.closePanel(ForgePanelLocation.left);
      layout.closePanel(ForgePanelLocation.right);
      await tester.pumpAndSettle();

      expect(layout.leftPanel.value.isVisible, isFalse);
      expect(layout.rightPanel.value.isVisible, isFalse);

      await _openSettingsViaAction(harness, tester);

      expect(layout.leftPanel.value.isVisible, isTrue);
      expect(layout.rightPanel.value.isVisible, isTrue);
    });

    testWidgets('02: shell auto-save enabled toggle updates runtime config', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseIHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();
      await _openSettingsViaAction(harness, tester);

      expect(harness.shell.config.current.autoSave.enabled, isTrue);

      final enabledToggle = find.widgetWithText(CheckboxListTile, 'Enabled');
      expect(enabledToggle, findsOneWidget);
      await tester.tap(enabledToggle);
      await tester.pumpAndSettle();

      expect(harness.shell.config.current.autoSave.enabled, isFalse);
    });

    testWidgets('03: shell focus-loss toggle updates runtime config', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseIHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();
      await _openSettingsViaAction(harness, tester);

      expect(harness.shell.config.current.autoSave.saveOnFocusLoss, isTrue);

      final focusLossToggle = find.widgetWithText(
        CheckboxListTile,
        'Save on focus loss',
      );
      expect(focusLossToggle, findsOneWidget);
      await tester.tap(focusLossToggle);
      await tester.pumpAndSettle();

      expect(harness.shell.config.current.autoSave.saveOnFocusLoss, isFalse);
    });

    testWidgets('04: shell idle delay field updates runtime config', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseIHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();
      await _openSettingsViaAction(harness, tester);

      final row = find.ancestor(
        of: find.text('Idle delay (s):'),
        matching: find.byType(Row),
      ).first;
      final field = find.descendant(
        of: row,
        matching: find.byType(TextField),
      );
      expect(field, findsOneWidget);

      await tester.enterText(field, '7');
      await tester.pumpAndSettle();

      expect(
        harness.shell.config.current.autoSave.idleDelay,
        equals(const Duration(seconds: 7)),
      );
    });

    testWidgets('05: shell layout defaults feed reset panel sizes action', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseIHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();
      await _openSettingsViaAction(harness, tester);

      final field = find.byWidgetPredicate((widget) {
        return widget is TextField &&
            widget.decoration?.labelText == 'Left panel';
      });
      expect(field, findsOneWidget);
      await tester.enterText(field, '333');
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      layout.setPanelSize(ForgePanelLocation.left, 470);
      await tester.pumpAndSettle();
      expect(layout.leftPanel.value.size, equals(470));

      final resetSizes = find.byTooltip('Reset Panel Sizes');
      await tester.tap(resetSizes);
      await tester.pumpAndSettle();

      expect(layout.leftPanel.value.size, equals(333));
    });

    testWidgets('06: terminal default shell updates preferences', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseIHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();
      await _openSettingsViaAction(harness, tester);
      await _openConfigSection(tester, 'Terminal');

      final shellField = find.byWidgetPredicate((widget) {
        return widget is TextField &&
            widget.decoration?.hintText == '/bin/bash';
      });
      expect(shellField, findsOneWidget);

      await tester.enterText(shellField, '/bin/fish');
      await tester.pumpAndSettle();

      expect(harness.preferences.terminalDefaultShell, equals('/bin/fish'));
    });

    testWidgets('07: terminal start folder dropdown updates preferences', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseIHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();
      await _openSettingsViaAction(harness, tester);
      await _openConfigSection(tester, 'Terminal');

      final dropdown = find.byType(DropdownButtonFormField<String>).first;
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home directory').last);
      await tester.pumpAndSettle();

      expect(harness.preferences.terminalStartFolder, equals('home'));
    });

    testWidgets('08: YAML tree lines toggle updates YAML editor config', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseIHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();
      await _openSettingsViaAction(harness, tester);
      await _openConfigSection(tester, 'YAML Editor');

      final treeLines = find.widgetWithText(CheckboxListTile, 'Tree lines');
      expect(treeLines, findsOneWidget);
      await tester.tap(treeLines);
      await tester.pumpAndSettle();

      final yamlConfig = harness.shell.getEditorSpecificConfig('yaml');
      expect(yamlConfig['showTreeLines'], isFalse);
    });

    testWidgets('09: Markdown mermaid toggle updates Markdown config', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseIHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();
      await _openSettingsViaAction(harness, tester);
      await _openConfigSection(tester, 'Markdown Editor');

      final mermaid = find.widgetWithText(
        CheckboxListTile,
        'Mermaid diagrams',
      );
      expect(mermaid, findsOneWidget);
      await tester.ensureVisible(mermaid);
      await tester.pumpAndSettle();
      await tester.tap(mermaid);
      await tester.pumpAndSettle();

      final mdConfig = harness.shell.getEditorSpecificConfig('md');
      expect(mdConfig['enableMermaid'], isFalse);
    });

    testWidgets('10: shortcuts reset restores a custom one-key rebind', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseIHarness.create();

      final before = harness.shell.shortcuts.getBinding('forge.toggleLeftPanel');
      expect(before, isNotNull);

      harness.shell.shortcuts.rebind(
        before!.action,
        const ForgeShortcutKey(
          key: LogicalKeyboardKey.keyL,
          primaryModifier: true,
          shift: true,
        ),
      );
      expect(
        harness.shell.shortcuts
            .getBinding('forge.toggleLeftPanel')
            ?.displayString,
        equals('Ctrl+Shift+L'),
      );

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();
      await _openSettingsViaAction(harness, tester);
      await _openConfigSection(tester, 'Shortcuts');

      final resetButton = find.widgetWithText(TextButton, 'Reset');
      expect(resetButton, findsOneWidget);
      await tester.ensureVisible(resetButton);
      await tester.pumpAndSettle();
      final reset = tester.widget<TextButton>(resetButton);
      expect(reset.onPressed, isNotNull);
      reset.onPressed!.call();
      await tester.pumpAndSettle();

      expect(
        harness.shell.shortcuts
            .getBinding('forge.toggleLeftPanel')
            ?.displayString,
        equals(before.displayString),
      );
    });
  });
}

Future<void> _openSettingsViaAction(
  _PhaseIHarness harness,
  WidgetTester tester,
) async {
  final opened = harness.shell.executeAction('forge.openSettings');
  expect(opened, isTrue);
  await tester.pumpAndSettle();
}

Future<void> _openConfigSection(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

class _PhaseIHarness {
  _PhaseIHarness._({
    required this.shell,
    required this.module,
    required this.application,
    required this.preferences,
  });

  final DefaultShellApi shell;
  final _PhaseIModule module;
  final ForgeApplication application;
  final ForgePreferencesService preferences;

  static _PhaseIHarness create() {
    final navigatorKey = GlobalKey<NavigatorState>();
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {
        '/workspace/test-fixtures/sample.md': '# Phase I\n',
      },
      appName: 'Phase I Harness',
      navigatorKey: navigatorKey,
    );

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);

    final module = _PhaseIModule();
    module.activate(shell);

    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(shellModule);
    registry.register(module);

    final application = ForgeApplication(
      id: 'phase-i-harness',
      title: 'Phase I Harness',
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
        middlePanels: const [MiddlePanelConfig(), MiddlePanelConfig()],
      ),
    );
    shell.applications.add(application);

    final layout = shell.layout as DefaultLayoutController;
    layout.openEditor(module.editor, module.editor.uri, middlePanelIndex: 0);

    final preferences = ForgePreferencesService();

    return _PhaseIHarness._(
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
          height: 1000,
          child: ForgeShellScaffold(
            shell: shell,
            layoutController: shell.layout as DefaultLayoutController,
            systemState: shell.systemState as DefaultSystemState,
            statusBarController: shell.statusBar,
            notificationManager:
                shell.notifications as DefaultNotificationManager,
            preferencesService: preferences,
          ),
        ),
      ),
    );
  }
}

class _PhaseIModule extends ForgeModule {
  late final ForgeTestTextEditor editor;
  late final _StubView explorerView;
  late final _StubView outlineView;
  late final _StubView problemsView;

  _PhaseIModule() {
    editor = ForgeTestTextEditor(
      this,
      document: ForgeTestDocument(
        uri: Uri.parse('file:///workspace/test-fixtures/sample.md'),
        content: '# Phase I\n',
      ),
    );
    explorerView = _StubView('Explorer View', Icons.folder);
    outlineView = _StubView('Outline View', Icons.account_tree);
    problemsView = _StubView('Problems View', Icons.error_outline);
  }

  @override
  String get displayName => 'Phase I Module';

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => [editor];

  @override
  List<ForgeView> get views => [explorerView, outlineView, problemsView];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
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
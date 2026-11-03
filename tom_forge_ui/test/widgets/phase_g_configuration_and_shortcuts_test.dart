import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'support/shell_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase G: configuration, shortcuts, and layout coverage', () {
    testWidgets('01: settings menu path opens all built-in sections', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseGHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings...').last);
      await tester.pumpAndSettle();

      expect(find.text('Shell'), findsWidgets);
      expect(find.text('Terminal'), findsWidgets);
      expect(find.text('Dart Editor'), findsWidgets);
      expect(find.text('YAML Editor'), findsWidgets);
      expect(find.text('Markdown Editor'), findsWidgets);
      expect(find.text('Shortcuts'), findsWidgets);
      expect(find.text('Chord Shortcuts'), findsWidgets);
      expect(find.text('File Types'), findsWidgets);
    });

    testWidgets('02: YAML settings toggle persists to shell config', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseGHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaAction(harness, tester);

      await tester.tap(find.text('YAML Editor').first);
      await tester.pumpAndSettle();

      final treeLines = find.widgetWithText(CheckboxListTile, 'Tree lines');
      expect(treeLines, findsOneWidget);
      await tester.ensureVisible(treeLines);
      await tester.pumpAndSettle();
      await tester.tap(treeLines);
      await tester.pumpAndSettle();

      final yamlConfig = harness.shell.getEditorSpecificConfig('yaml');
      expect(yamlConfig['showTreeLines'], isFalse);
    });

    testWidgets('03: Markdown settings toggle persists to shell config', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseGHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaAction(harness, tester);

      await tester.tap(find.text('Markdown Editor').first);
      await tester.pumpAndSettle();

      final mermaid = find.widgetWithText(CheckboxListTile, 'Mermaid diagrams');
      expect(mermaid, findsOneWidget);
      await tester.ensureVisible(mermaid);
      await tester.pumpAndSettle();
      await tester.tap(mermaid);
      await tester.pumpAndSettle();

      final mdConfig = harness.shell.getEditorSpecificConfig('md');
      expect(mdConfig['enableMermaid'], isFalse);
    });

    testWidgets('04: file-type default editor updates wildcard mapping', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseGHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaAction(harness, tester);

      await tester.tap(find.text('File Types').first);
      await tester.pumpAndSettle();

      await _selectDefaultFileTypeEditor(tester, 'Dart');
      await tester.pumpAndSettle();

      expect(harness.shell.getFileTypeDefaults()['*'], equals('dart'));
    });

    testWidgets('05: new extension mapping controls opened editor type', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseGHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaAction(harness, tester);

      await tester.tap(find.text('File Types').first);
      await tester.pumpAndSettle();

      await _selectDefaultFileTypeEditor(tester, 'Dart');
      await tester.pumpAndSettle();

      final extField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '.ext',
      );
      expect(extField, findsOneWidget);
      await tester.ensureVisible(extField);
      await tester.pumpAndSettle();
      await tester.enterText(extField, '.spec');

      final addButton = find.byTooltip('Add Extension');
      await tester.ensureVisible(addButton);
      await tester.pumpAndSettle();
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(harness.shell.getFileTypeDefaults()['.spec'], equals('dart'));

      final layout = harness.shell.layout as DefaultLayoutController;
      layout.openFile(Uri.parse('file:///workspace/test-fixtures/sample.spec'));
      await tester.pumpAndSettle();

      expect(harness.shell.systemState.activeEditor, isA<ForgeDartEditor>());
    });

    testWidgets('06: shortcuts search filters to no-matches and back', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseGHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaAction(harness, tester);

      await tester.tap(find.text('Shortcuts').first);
      await tester.pumpAndSettle();

      final searchField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Search shortcuts...',
      );
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'definitely-not-a-shortcut');
      await tester.pumpAndSettle();

      expect(find.text('No matches'), findsOneWidget);

      await tester.enterText(searchField, 'toggle left panel');
      await tester.pumpAndSettle();

      expect(find.text('Toggle Left Panel'), findsOneWidget);
    });

    testWidgets('07: reset restores default from a custom rebind', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseGHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaAction(harness, tester);

      await tester.tap(find.text('Shortcuts').first);
      await tester.pumpAndSettle();

      final searchField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Search shortcuts...',
      );
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'toggle left panel');
      await tester.pumpAndSettle();

      final beforeReset = harness.shell.shortcuts.getBinding(
        'forge.toggleLeftPanel',
      );
      expect(beforeReset, isNotNull);

      harness.shell.shortcuts.rebind(
        beforeReset!.action,
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
        isNotNull,
      );

      expect(
        harness.shell.shortcuts
            .getBinding('forge.toggleLeftPanel')
            ?.displayString,
        equals(beforeReset.displayString),
      );
    });

    testWidgets('08: chord shortcuts section lists contributed chord action', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseGHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaAction(harness, tester);

      await tester.tap(find.text('Chord Shortcuts').first);
      await tester.pumpAndSettle();

      expect(find.text('Fixture Chord Action'), findsOneWidget);
      expect(find.textContaining('Ctrl+K'), findsOneWidget);
    });

    testWidgets('09: shortcut menu trigger and follow-up key execute action', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseGHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyE, shift: true);
      await tester.pumpAndSettle();

      expect(find.text('Fixture Commands'), findsOneWidget);
      expect(find.text('Run Fixture Tool'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pumpAndSettle();

      expect(harness.module.executedActionIds, contains('fixture.menuAction'));
    });

    testWidgets('10: primary+3 and primary+4 focus middle panels', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseGHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      layout.splitMiddlePanel();
      layout.splitMiddlePanel();
      layout.splitMiddlePanel();
      await tester.pumpAndSettle();

      expect(layout.middlePanels.value.length, equals(4));

      layout.setActiveMiddlePanelIndex(0);
      expect(layout.activeMiddlePanelIndex, equals(0));

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.digit3);
      await tester.pumpAndSettle();
      expect(layout.activeMiddlePanelIndex, equals(2));

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.digit4);
      await tester.pumpAndSettle();
      expect(layout.activeMiddlePanelIndex, equals(3));
    });
  });
}

Future<void> _openSettingsViaAction(
  _PhaseGHarness harness,
  WidgetTester tester,
) async {
  final opened = harness.shell.executeAction('forge.openSettings');
  expect(opened, isTrue);
  await tester.pumpAndSettle();
}

Future<void> _selectDefaultFileTypeEditor(
  WidgetTester tester,
  String next,
) async {
  final dropdown = find.byType(DropdownButtonFormField<String>).first;
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(next).last);
  await tester.pumpAndSettle();
}

class _PhaseGHarness {
  _PhaseGHarness._({
    required this.shell,
    required this.module,
    required this.application,
  });

  final DefaultShellApi shell;
  final _PhaseGModule module;
  final ForgeApplication application;

  static _PhaseGHarness create() {
    final navigatorKey = GlobalKey<NavigatorState>();
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {
        '/workspace/test-fixtures/sample.spec': 'void fixtureSpec() {}\n',
        '/workspace/test-fixtures/sample.md': '# Fixture\n',
      },
      appName: 'Phase G Harness',
      navigatorKey: navigatorKey,
    );

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);

    final module = _PhaseGModule();
    module.activate(shell);

    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(shellModule);
    registry.register(module);

    final application = ForgeApplication(
      title: 'Phase G Harness',
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

    final layout = shell.layout as DefaultLayoutController;
    layout.openEditor(module.editor, module.editor.uri, middlePanelIndex: 0);

    return _PhaseGHarness._(
      shell: shell,
      module: module,
      application: application,
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
            application: application,
            layoutController: shell.layout as DefaultLayoutController,
            systemState: shell.systemState as DefaultSystemState,
            statusBarController: shell.statusBar,
            notificationManager:
                shell.notifications as DefaultNotificationManager,
          ),
        ),
      ),
    );
  }
}

class _PhaseGModule extends ForgeModule {
  final List<String> executedActionIds = <String>[];

  late final ForgeTestTextEditor editor;
  late final _StubView explorerView;
  late final _StubView outlineView;
  late final _StubView problemsView;
  late final ForgeAction fixtureMenuAction;
  late final ForgeAction fixtureChordAction;

  _PhaseGModule() {
    editor = ForgeTestTextEditor(
      this,
      document: ForgeTestDocument(
        uri: Uri.parse('file:///workspace/test-fixtures/sample.md'),
        content: '# Fixture\n',
      ),
    );
    explorerView = _StubView('Explorer View', Icons.folder);
    outlineView = _StubView('Outline View', Icons.account_tree);
    problemsView = _StubView('Problems View', Icons.error_outline);

    fixtureMenuAction = ForgeAction(
      id: 'fixture.menuAction',
      label: 'Run Fixture Tool',
      menu: ForgeMenuLocation.tools,
      execute: (_) async {
        executedActionIds.add('fixture.menuAction');
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );

    fixtureChordAction = ForgeAction(
      id: 'fixture.chordAction',
      label: 'Fixture Chord Action',
      menu: ForgeMenuLocation.commandPalette,
      execute: (_) async {
        executedActionIds.add('fixture.chordAction');
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );
  }

  @override
  String get displayName => 'Phase G Module';

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => [editor];

  @override
  List<ForgeView> get views => [explorerView, outlineView, problemsView];

  @override
  List<ForgeAction> get actions => [fixtureMenuAction, fixtureChordAction];

  @override
  List<ForgeShortcutBinding> get shortcuts => [
    ForgeShortcutBinding(
      action: fixtureChordAction,
      key: const ForgeShortcutKey(
        key: LogicalKeyboardKey.keyK,
        primaryModifier: true,
      ),
      chord: const ForgeChordKey(
        firstKey: ForgeShortcutKey(
          key: LogicalKeyboardKey.keyK,
          primaryModifier: true,
        ),
        secondKey: ForgeShortcutKey(
          key: LogicalKeyboardKey.keyX,
          primaryModifier: true,
        ),
      ),
    ),
  ];

  @override
  List<ForgeShortcutMenu> get shortcutMenus => [
    ForgeShortcutMenu(
      triggerKey: LogicalKeyboardKey.keyE,
      label: 'Fixture Commands',
      entries: [
        ForgeShortcutMenuEntry(
          key: LogicalKeyboardKey.keyR,
          action: fixtureMenuAction,
        ),
      ],
    ),
  ];
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

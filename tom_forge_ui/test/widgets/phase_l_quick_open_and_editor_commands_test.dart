import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';

import 'support/shell_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase L: quick-open keyboard flows and editor commands', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('01: F1 opens quick-open all mode and Escape closes it', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseLHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await tester.pumpAndSettle();

      expect(find.byType(ForgeQuickOpen), findsOneWidget);
      expect(find.byTooltip('Match Case'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(ForgeQuickOpen), findsNothing);
    });

    testWidgets('02: primary+P toggles actions-only quick-open open and close', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseLHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyP);
      await tester.pumpAndSettle();

      expect(find.byType(ForgeQuickOpen), findsOneWidget);
      expect(find.byTooltip('Match Case'), findsNothing);
      expect(_searchFieldWithHint('Type an action...'), findsOneWidget);

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyP);
      await tester.pumpAndSettle();

      expect(find.byType(ForgeQuickOpen), findsNothing);
    });

    testWidgets('03: actions mode arrow navigation executes second fixture action', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseLHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyP);
      await tester.pumpAndSettle();

      await tester.enterText(_titleSearchField(), 'Fixture Action');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(
        harness.module.executedActionIds,
        contains('fixture.action.two'),
      );
    });

    testWidgets('04: Match Case toggle filters case-mismatched results', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseLHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openQuickOpenWithQuery(tester, 'terminal shell');

      final terminalSetting = _quickOpenText('Terminal Shell');
      expect(terminalSetting, findsOneWidget);

      await tester.tap(find.byTooltip('Match Case'));
      await tester.pumpAndSettle();

      expect(terminalSetting, findsNothing);
    });

    testWidgets('05: Match Whole Word hides partial query matches', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseLHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openQuickOpenWithQuery(tester, 'Term');

      final terminalSetting = _quickOpenText('Terminal Shell');
      expect(terminalSetting, findsOneWidget);

      await tester.tap(find.byTooltip('Match Whole Word'));
      await tester.pumpAndSettle();

      expect(terminalSetting, findsNothing);
    });

    testWidgets('06: Enter on open-editor result focuses that editor', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseLHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      layout.openEditor(
        harness.module.secondaryEditor,
        harness.module.secondaryEditor.uri,
      );
      await tester.pumpAndSettle();
      expect(
        harness.shell.systemState.activeEditor,
        equals(harness.module.secondaryEditor),
      );

      await _openQuickOpenWithQuery(tester, 'main.test');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(
        harness.shell.systemState.activeEditor?.uri.path,
        endsWith('main.test'),
      );
    });

    testWidgets('07: quick-open File Type Defaults opens file-types section', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseLHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openQuickOpenWithQuery(tester, 'File Type Defaults');
      await tester.tap(_quickOpenText('File Type Defaults'));
      await tester.pumpAndSettle();

      expect(find.text('Default Editor (unmapped extensions)'), findsOneWidget);
    });

    testWidgets('08: primary+S save-all clears dirty state in active editor', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseLHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      harness.module.primaryEditor.insertText('dirty');
      await tester.pumpAndSettle();
      expect(harness.module.primaryEditor.isDirty.value, isTrue);

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyS);
      await tester.pumpAndSettle();

      expect(harness.module.primaryEditor.isDirty.value, isFalse);
    });

    testWidgets('09: moveComponent moves editor into target middle panel', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseLHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      layout.openEditor(
        harness.module.primaryEditor,
        harness.module.primaryEditor.uri,
        middlePanelIndex: 0,
      );
      layout.openEditor(
        harness.module.secondaryEditor,
        harness.module.secondaryEditor.uri,
        middlePanelIndex: 0,
      );
      await tester.pumpAndSettle();

      layout.moveComponent(harness.module.secondaryEditor, 1);
      await tester.pumpAndSettle();

      expect(layout.middlePanels.value.length, equals(2));
      expect(layout.middlePanels.value[0], isNot(contains(harness.module.secondaryEditor)));
      expect(layout.middlePanels.value[1], contains(harness.module.secondaryEditor));
      expect(layout.activeMiddlePanelIndex, equals(1));
    });

    testWidgets('10: closeAllEditors resets layout to single empty middle panel', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseLHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      layout.openEditor(
        harness.module.secondaryEditor,
        harness.module.secondaryEditor.uri,
      );
      await tester.pumpAndSettle();

      layout.closeAllEditors();
      await tester.pumpAndSettle();

      expect(harness.shell.systemState.openEditors, isEmpty);
      expect(layout.middlePanels.value.length, equals(1));
      expect(layout.middlePanels.value.first, isEmpty);
    });
  });
}

Future<void> _openQuickOpenWithQuery(WidgetTester tester, String query) async {
  await tester.enterText(_titleSearchField(), query);
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pumpAndSettle();
}

Finder _titleSearchField() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        (widget.decoration?.hintText == 'Search files, actions, and settings' ||
            widget.decoration?.hintText == 'Type an action...' ||
            widget.decoration?.hintText ==
                'Search shortcuts or press key...'),
  );
}

Finder _searchFieldWithHint(String hint) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == hint,
  );
}

Finder _quickOpenText(String label) {
  return find.descendant(
    of: find.byType(ForgeQuickOpen),
    matching: find.text(label),
  );
}

class _PhaseLHarness {
  _PhaseLHarness._({
    required this.shell,
    required this.module,
    required this.application,
    required this.preferences,
  });

  final DefaultShellApi shell;
  final _PhaseLModule module;
  final ForgeApplication application;
  final ForgePreferencesService preferences;

  static _PhaseLHarness create() {
    final navigatorKey = GlobalKey<NavigatorState>();
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {
        '/workspace/test-fixtures/main.test': 'main file\n',
        '/workspace/test-fixtures/secondary.test': 'secondary file\n',
      },
      appName: 'Phase L Harness',
      navigatorKey: navigatorKey,
    );

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);

    final module = _PhaseLModule();
    module.activate(shell);

    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(shellModule);
    registry.register(module);
    // Quick open, a package of its own: the overlay the scaffold shows.
    shell.registerModule(forgeQuickOpenModule());

    final application = ForgeApplication(
      id: 'phase-l-harness',
      title: 'Phase L Harness',
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
    layout.openEditor(
      module.primaryEditor,
      module.primaryEditor.uri,
      middlePanelIndex: 0,
    );

    final preferences = ForgePreferencesService();

    return _PhaseLHarness._(
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
            notificationManager:
                shell.notifications as DefaultNotificationManager,
            preferencesService: preferences,
          ),
        ),
      ),
    );
  }
}

class _PhaseLModule extends ForgeModule {
  late final ForgeTestTextEditor primaryEditor;
  late final ForgeTestTextEditor secondaryEditor;
  late final ForgeAction saveAllAction;
  late final ForgeAction fixtureActionOne;
  late final ForgeAction fixtureActionTwo;
  late final _StubView explorerView;
  late final _StubView outlineView;
  late final _StubView problemsView;

  final List<String> executedActionIds = <String>[];

  _PhaseLModule() {
    primaryEditor = ForgeTestTextEditor(
      this,
      document: ForgeTestDocument(
        uri: Uri.parse('file:///workspace/test-fixtures/main.test'),
        content: 'phase l main\n',
      ),
    );
    secondaryEditor = ForgeTestTextEditor(
      this,
      document: ForgeTestDocument(
        uri: Uri.parse('file:///workspace/test-fixtures/secondary.test'),
        content: 'phase l secondary\n',
      ),
    );

    saveAllAction = ForgeAction(
      id: 'file.saveAll',
      label: 'Save All',
      menu: ForgeMenuLocation.file,
      execute: (_) async {
        primaryEditor.markClean();
        secondaryEditor.markClean();
        executedActionIds.add('file.saveAll');
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );

    fixtureActionOne = ForgeAction(
      id: 'fixture.action.one',
      label: 'Fixture Action One',
      menu: ForgeMenuLocation.commandPalette,
      execute: (_) async {
        executedActionIds.add('fixture.action.one');
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );

    fixtureActionTwo = ForgeAction(
      id: 'fixture.action.two',
      label: 'Fixture Action Two',
      menu: ForgeMenuLocation.commandPalette,
      execute: (_) async {
        executedActionIds.add('fixture.action.two');
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );

    explorerView = _StubView('Explorer View', Icons.folder);
    outlineView = _StubView('Outline View', Icons.account_tree);
    problemsView = _StubView('Problems View', Icons.error_outline);
  }

  @override
  String get displayName => 'Phase L Module';

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => [primaryEditor, secondaryEditor];

  @override
  List<ForgeView> get views => [explorerView, outlineView, problemsView];

  @override
  List<ForgeAction> get actions => [
        saveAllAction,
        fixtureActionOne,
        fixtureActionTwo,
      ];

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
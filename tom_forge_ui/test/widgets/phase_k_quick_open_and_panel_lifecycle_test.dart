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

  group('Phase K: quick-open and panel lifecycle coverage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets(
      '01: typing in search opens quick-open and shows dirty bullet',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseKHarness.create();

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        harness.module.primaryEditor.insertText('dirty');
        await tester.pumpAndSettle();

        await _openQuickOpenWithQuery(tester, 'main.test');

        expect(find.byType(ForgeQuickOpen), findsOneWidget);
        expect(find.byTooltip('Match Case'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                (widget.data?.contains('main.test ●') ?? false),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('02: primary+P opens actions-only quick-open mode', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseKHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyP);
      await tester.pumpAndSettle();

      expect(find.byType(ForgeQuickOpen), findsOneWidget);
      expect(find.byTooltip('Match Case'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == 'Type an action...',
        ),
        findsOneWidget,
      );
    });

    testWidgets('03: actions mode Enter executes highlighted action', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseKHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyP);
      await tester.pumpAndSettle();

      await tester.enterText(_titleSearchField(), 'Fixture Palette Action');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(
        harness.module.executedActionIds,
        contains('fixture.paletteAction'),
      );
    });

    testWidgets('04: quick-open Terminal setting opens terminal section', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseKHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openQuickOpenWithQuery(tester, 'Terminal Shell');
      final terminalSetting = find.descendant(
        of: find.byType(ForgeQuickOpen),
        matching: find.text('Terminal Shell'),
      );
      expect(terminalSetting, findsOneWidget);
      await tester.tap(terminalSetting);
      await tester.pumpAndSettle();

      expect(find.text('Default Shell'), findsOneWidget);
    });

    testWidgets('05: quick-open Shortcuts setting opens shortcuts section', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseKHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openQuickOpenWithQuery(tester, 'Shortcuts');
      final shortcutsSetting = find.descendant(
        of: find.byType(ForgeQuickOpen),
        matching: find.text('Shortcuts'),
      );
      expect(shortcutsSetting, findsOneWidget);
      await tester.tap(shortcutsSetting);
      await tester.pumpAndSettle();

      expect(shortcutTableSearch(), findsOneWidget);
    });

    testWidgets('06: invalid regex query surfaces quick-open regex error', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseKHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openQuickOpenWithQuery(tester, 'md');

      await tester.tap(find.byTooltip('Use Regex'));
      await tester.pumpAndSettle();

      await tester.enterText(_titleSearchField(), '(');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(find.text('Invalid regex'), findsOneWidget);
    });

    testWidgets('07: whole-word toggle clears regex error state', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseKHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openQuickOpenWithQuery(tester, 'md');

      await tester.tap(find.byTooltip('Use Regex'));
      await tester.pumpAndSettle();
      await tester.enterText(_titleSearchField(), '(');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.text('Invalid regex'), findsOneWidget);

      await tester.tap(find.byTooltip('Match Whole Word'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid regex'), findsNothing);
    });

    testWidgets('08: primary+4 focuses fourth middle panel when present', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseKHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      layout.splitMiddlePanel();
      layout.splitMiddlePanel();
      layout.splitMiddlePanel();
      await tester.pumpAndSettle();

      expect(layout.middlePanels.value.length, equals(4));

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.digit4);
      await tester.pumpAndSettle();

      expect(layout.activeMiddlePanelIndex, equals(3));
    });

    testWidgets('09: splitMiddlePanel remains capped at four panels', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseKHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      layout.splitMiddlePanel();
      layout.splitMiddlePanel();
      layout.splitMiddlePanel();
      layout.splitMiddlePanel();
      layout.splitMiddlePanel();
      await tester.pumpAndSettle();

      expect(layout.middlePanels.value.length, equals(4));
    });

    testWidgets('10: closing last editor in panel collapses panel count', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseKHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      layout.openEditor(
        harness.module.secondaryEditor,
        harness.module.secondaryEditor.uri,
        middlePanelIndex: 0,
      );
      layout.splitAndInsertPanel(1, harness.module.secondaryEditor);
      await tester.pumpAndSettle();

      expect(layout.middlePanels.value.length, equals(2));
      expect(
        harness.shell.systemState.openEditors,
        contains(harness.module.secondaryEditor),
      );

      final secondaryTab = find.ancestor(
        of: find.text('secondary.test'),
        matching: find.byType(InkWell),
      );
      expect(secondaryTab, findsWidgets);

      final closeButton = find.descendant(
        of: secondaryTab.first,
        matching: find.byTooltip('Close'),
      );
      expect(closeButton, findsOneWidget);

      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(layout.middlePanels.value.length, equals(1));
      expect(
        harness.shell.systemState.openEditors,
        isNot(contains(harness.module.secondaryEditor)),
      );
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
            widget.decoration?.hintText == 'Search shortcuts or press key...'),
  );
}

class _PhaseKHarness {
  _PhaseKHarness._({
    required this.shell,
    required this.module,
    required this.application,
    required this.preferences,
  });

  final DefaultShellApi shell;
  final _PhaseKModule module;
  final ForgeApplication application;
  final ForgePreferencesService preferences;

  static _PhaseKHarness create() {
    final navigatorKey = GlobalKey<NavigatorState>();
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {
        '/workspace/test-fixtures/main.test': 'main file\n',
        '/workspace/test-fixtures/secondary.test': 'secondary file\n',
      },
      appName: 'Phase K Harness',
      navigatorKey: navigatorKey,
    );

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);

    final module = _PhaseKModule();
    module.activate(shell);

    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(shellModule);
    registry.register(module);
    // Quick open, a package of its own: the overlay the scaffold shows.
    shell.registerModule(forgeQuickOpenModule());

    final application = ForgeApplication(
      id: 'phase-k-harness',
      title: 'Phase K Harness',
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
        middlePanels: const [MiddlePanelConfig(), MiddlePanelConfig()],
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

    return _PhaseKHarness._(
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

class _PhaseKModule extends ForgeModule {
  late final ForgeTestTextEditor primaryEditor;
  late final ForgeTestTextEditor secondaryEditor;
  late final ForgeAction fixturePaletteAction;
  late final _StubView explorerView;
  late final _StubView outlineView;
  late final _StubView problemsView;

  final List<String> executedActionIds = <String>[];

  _PhaseKModule() {
    primaryEditor = ForgeTestTextEditor(
      this,
      document: ForgeTestDocument(
        uri: Uri.parse('file:///workspace/test-fixtures/main.test'),
        content: 'phase k main\n',
      ),
    );
    secondaryEditor = ForgeTestTextEditor(
      this,
      document: ForgeTestDocument(
        uri: Uri.parse('file:///workspace/test-fixtures/secondary.test'),
        content: 'phase k secondary\n',
      ),
    );

    fixturePaletteAction = ForgeAction(
      id: 'fixture.paletteAction',
      label: 'Fixture Palette Action',
      menu: ForgeMenuLocation.commandPalette,
      execute: (_) async {
        executedActionIds.add('fixture.paletteAction');
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
  String get displayName => 'Phase K Module';

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => [primaryEditor, secondaryEditor];

  @override
  List<ForgeView> get views => [explorerView, outlineView, problemsView];

  @override
  List<ForgeAction> get actions => [fixturePaletteAction];

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

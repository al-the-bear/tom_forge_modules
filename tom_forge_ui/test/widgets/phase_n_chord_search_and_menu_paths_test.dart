import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_forge_core/tom_forge_core.dart'
    show FileHandlingResult, ForgePanelLocation;
import 'package:tom_forge_ui/src/widgets/forge_quick_open.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'support/shell_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase N: chord quick-open, search config, and menu click paths', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('01: primary+K opens chord quick-open mode', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseNHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyK);
      await tester.pumpAndSettle();

      expect(find.byType(ForgeQuickOpen), findsOneWidget);
      expect(_searchFieldWithHint('Search shortcuts or press key...'), findsOneWidget);
      expect(_quickOpenText('Fixture Chord X'), findsOneWidget);
      expect(_quickOpenText('Fixture Chord Y'), findsOneWidget);
    });

    testWidgets('02: chord second key executes bound action and closes quick-open', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseNHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyK);
      await tester.pumpAndSettle();

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyX);
      await tester.pumpAndSettle();

      expect(harness.module.executedActionIds, contains('fixture.chord.x'));
      expect(find.byType(ForgeQuickOpen), findsNothing);
    });

    testWidgets('03: Escape cancels chord so second key no longer executes', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseNHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyK);
      await tester.pumpAndSettle();
      expect(find.byType(ForgeQuickOpen), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(ForgeQuickOpen), findsNothing);

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyY);
      await tester.pumpAndSettle();

      expect(harness.module.executedActionIds, isNot(contains('fixture.chord.y')));
    });

    testWidgets('04: chord search filter with Enter executes filtered completion', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseNHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyK);
      await tester.pumpAndSettle();

      await tester.enterText(_titleSearchField(), 'Chord Y');
      await tester.pumpAndSettle();

      expect(_quickOpenText('Fixture Chord Y'), findsOneWidget);
      expect(_quickOpenText('Fixture Chord X'), findsNothing);

      // The chord list keeps "Help" as the first static row, so move
      // selection to the filtered command row before execution.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(harness.module.executedActionIds, contains('fixture.chord.y'));
    });

    testWidgets('05: shell excluded extensions hides note files from quick-open search', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseNHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);

      await tester.enterText(_shellExcludedExtensionsField(), 'note');
      await tester.pumpAndSettle();

      await _openQuickOpenWithQuery(tester, 'zz');

      expect(_visibleNoteResultCount(), equals(0));
    });

    testWidgets('06: shell max file results limits quick-open file section count', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseNHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);

      await tester.enterText(_shellExcludedExtensionsField(), '');
      await tester.pumpAndSettle();
      await tester.enterText(_shellMaxResultsField(), '2');
      await tester.pumpAndSettle();

      await _openQuickOpenWithQuery(tester, 'zz');

      expect(_visibleNoteResultCount(), equals(2));
    });

    testWidgets('07: terminal font size field updates terminal preferences', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseNHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'Terminal');

      final fontSizeField = find.byWidgetPredicate((widget) {
        return widget is TextField && widget.decoration?.labelText == 'Size';
      });
      expect(fontSizeField, findsOneWidget);

      await tester.enterText(fontSizeField, '18');
      await tester.pumpAndSettle();

      expect(harness.preferences.terminalFontSize, equals(18));
    });

    testWidgets('08: terminal scrollback field updates terminal preferences', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseNHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'Terminal');

      final scrollbackRow = find.ancestor(
        of: find.text('Scrollback:'),
        matching: find.byType(Row),
      ).first;
      final scrollbackField = find.descendant(
        of: scrollbackRow,
        matching: find.byType(TextField),
      );
      expect(scrollbackField, findsOneWidget);

      await tester.enterText(scrollbackField, '8000');
      await tester.pumpAndSettle();

      expect(harness.preferences.terminalScrollbackLines, equals(8000));
    });

    testWidgets('09: View menu toggle left panel hides and reopens left panel', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseNHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      expect(layout.leftPanel.value.isVisible, isTrue);

      await _selectViewMenuItem(tester, 'Toggle Left Panel');
      expect(layout.leftPanel.value.isVisible, isFalse);

      await _selectViewMenuItem(tester, 'Toggle Left Panel');
      expect(layout.leftPanel.value.isVisible, isTrue);
    });

    testWidgets('10: View menu Middle Panel 2 sets active panel and focus', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseNHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      layout.splitMiddlePanel();
      await tester.pumpAndSettle();
      expect(layout.middlePanels.value.length, equals(2));

      await _selectViewMenuItem(tester, 'Middle Panel 2');

      expect(layout.activeMiddlePanelIndex, equals(1));
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

Future<void> _openQuickOpenWithQuery(WidgetTester tester, String query) async {
  await tester.enterText(_titleSearchField(), query);
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 500));
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

Finder _searchFieldWithHint(String hint) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == hint,
  );
}

Finder _quickOpenText(String text) {
  return find.descendant(of: find.byType(ForgeQuickOpen), matching: find.text(text));
}

Finder _shellExcludedExtensionsField() {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == 'Excluded extensions',
  );
}

Finder _shellMaxResultsField() {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == 'Max results',
  );
}

int _visibleNoteResultCount() {
  const names = <String>[
    'zz-alpha.note',
    'zz-beta.note',
    'zz-gamma.note',
    'zz-delta.note',
  ];
  var count = 0;
  for (final name in names) {
    if (_quickOpenText(name).evaluate().isNotEmpty) count++;
  }
  return count;
}

class _PhaseNHarness {
  _PhaseNHarness._({
    required this.shell,
    required this.module,
    required this.application,
    required this.preferences,
  });

  final DefaultShellApi shell;
  final _PhaseNModule module;
  final ForgeApplication application;
  final ForgePreferencesService preferences;

  static _PhaseNHarness create() {
    final workspaceRoot =
        '${Directory.current.path}/test/phase_n_fixture_workspace';
    final workspaceDir = Directory(workspaceRoot);
    if (workspaceDir.existsSync()) {
      workspaceDir.deleteSync(recursive: true);
    }
    addTearDown(() {
      if (workspaceDir.existsSync()) {
        workspaceDir.deleteSync(recursive: true);
      }
    });

    final navigatorKey = GlobalKey<NavigatorState>();
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: {
        '$workspaceRoot/test-fixtures/main.test': 'main\n',
        '$workspaceRoot/test-fixtures/zz-alpha.note': 'alpha\n',
        '$workspaceRoot/test-fixtures/zz-beta.note': 'beta\n',
        '$workspaceRoot/test-fixtures/zz-gamma.note': 'gamma\n',
        '$workspaceRoot/test-fixtures/zz-delta.note': 'delta\n',
      },
      appName: 'Phase N Harness',
      navigatorKey: navigatorKey,
    );
    (shell.systemState as DefaultSystemState).setWorkspaceRootPath(workspaceRoot);

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);

    final module = _PhaseNModule(workspaceRoot: workspaceRoot);
    module.activate(shell);

    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(shellModule);
    registry.register(module);

    final application = ForgeApplication(
      title: 'Phase N Harness',
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
        middlePanels: const [MiddlePanelConfig()],
      ),
    );

    final layout = shell.layout as DefaultLayoutController;
    layout.openEditor(module.mainEditor, module.mainEditor.uri, middlePanelIndex: 0);

    final preferences = ForgePreferencesService();

    return _PhaseNHarness._(
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
            application: application,
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

class _PhaseNModule extends ForgeModule {
  _PhaseNModule({required String workspaceRoot}) {
    mainEditor = _PhaseNMainEditor(this, workspaceRoot: workspaceRoot);
    explorerView = _StubView('Explorer View', Icons.folder);
    outlineView = _StubView('Outline View', Icons.account_tree);
    problemsView = _StubView('Problems View', Icons.error_outline);

    fixtureChordActionX = ForgeAction(
      id: 'fixture.chord.x',
      label: 'Fixture Chord X',
      menu: ForgeMenuLocation.commandPalette,
      execute: (_) async {
        executedActionIds.add('fixture.chord.x');
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );

    fixtureChordActionY = ForgeAction(
      id: 'fixture.chord.y',
      label: 'Fixture Chord Y',
      menu: ForgeMenuLocation.commandPalette,
      execute: (_) async {
        executedActionIds.add('fixture.chord.y');
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );
  }

  final List<String> executedActionIds = <String>[];

  late final _PhaseNMainEditor mainEditor;
  late final _StubView explorerView;
  late final _StubView outlineView;
  late final _StubView problemsView;
  late final ForgeAction fixtureChordActionX;
  late final ForgeAction fixtureChordActionY;

  @override
  String get displayName => 'Phase N Module';

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => [mainEditor];

  @override
  List<ForgeView> get views => [explorerView, outlineView, problemsView];

  @override
  List<ForgeAction> get actions => [fixtureChordActionX, fixtureChordActionY];

  @override
  List<ForgeShortcutBinding> get shortcuts => [
        ForgeShortcutBinding(
          action: fixtureChordActionX,
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
        ForgeShortcutBinding(
          action: fixtureChordActionY,
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
              key: LogicalKeyboardKey.keyY,
              primaryModifier: true,
            ),
          ),
        ),
      ];
}

class _PhaseNMainEditor extends ForgeTestTextEditor {
  _PhaseNMainEditor(
    super.module, {
    required String workspaceRoot,
  })
      : super(
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

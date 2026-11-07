import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show ForgePanelLocation;
import 'package:tom_forge_ui/src/widgets/forge_quick_open.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'support/shell_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase O: shell search config and file-type behavior', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('01: excluded directories remove matching quick-open file hits', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseOHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _setCheckbox(tester, 'Use .gitignore', false);

      await _openQuickOpenWithQuery(tester, 'nested');
      expect(_quickOpenText('zz-nested.note'), findsOneWidget);

      await _dismissQuickOpen(tester);
      await tester.enterText(_shellExcludedDirectoriesField(), 'nested');
      await tester.pumpAndSettle();

      await _openQuickOpenWithQuery(tester, 'nested');
      expect(_quickOpenText('zz-nested.note'), findsNothing);
    });

    testWidgets('02: disabling hide-hidden-dirs reveals hidden directory files', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseOHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _setCheckbox(tester, 'Use .gitignore', false);

      await _openQuickOpenWithQuery(tester, 'hidden');
      expect(_quickOpenText('zz-hidden.note'), findsNothing);

      await _dismissQuickOpen(tester);
      await _setCheckbox(tester, 'Hide hidden dirs', false);

      await _openQuickOpenWithQuery(tester, 'hidden');
      expect(_quickOpenText('zz-hidden.note'), findsOneWidget);
    });

    testWidgets('03: enabled gitignore hides ignored files in quick-open search', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseOHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openQuickOpenWithQuery(tester, 'alpha');

      expect(_quickOpenText('alpha.note'), findsNothing);
    });

    testWidgets('04: disabling gitignore reveals previously ignored files', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseOHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _setCheckbox(tester, 'Use .gitignore', false);

      await _openQuickOpenWithQuery(tester, 'alpha');

      expect(_quickOpenText('alpha.note'), findsOneWidget);
    });

    testWidgets('05: Dart editor show-toolbar toggle updates runtime config', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseOHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'Dart Editor');

      final before = harness.shell.getEditorSpecificConfig('dart')['showToolbar'];
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Show toolbar'));
      await tester.pumpAndSettle();
      final after = harness.shell.getEditorSpecificConfig('dart')['showToolbar'];

      expect(after, isNot(equals(before)));
    });

    testWidgets('06: YAML inline-validation toggle updates runtime config', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseOHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'YAML Editor');

      final before =
          harness.shell.getEditorSpecificConfig('yaml')['showInlineValidation'];
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Inline validation'));
      await tester.pumpAndSettle();
      final after =
          harness.shell.getEditorSpecificConfig('yaml')['showInlineValidation'];

      expect(after, isNot(equals(before)));
    });

    testWidgets('07: Markdown show-tree toggle updates runtime config', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseOHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'Markdown Editor');

      final before = harness.shell.getEditorSpecificConfig('md')['showTree'];
      final showTreeToggle = find.widgetWithText(CheckboxListTile, 'Show tree');
      expect(showTreeToggle, findsOneWidget);
      await tester.ensureVisible(showTreeToggle);
      await tester.pumpAndSettle();
      await tester.tap(showTreeToggle);
      await tester.pumpAndSettle();
      final after = harness.shell.getEditorSpecificConfig('md')['showTree'];

      expect(after, isNot(equals(before)));
    });

    testWidgets('08: added extension uses current default editor mapping', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseOHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'File Types');

      await _selectDefaultFileTypeEditor(tester, 'Dart');
      await _addExtensionMapping(tester, '.oext');

      final layout = harness.shell.layout as DefaultLayoutController;
      layout.openFile(Uri.file('${harness.workspaceRoot}/test-fixtures/target-one.oext'));
      await tester.pumpAndSettle();

      expect(harness.shell.systemState.activeEditor, isA<ForgeDartEditor>());
    });

    testWidgets('09: default editor handles unmapped extension fallback', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseOHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'File Types');

      await _selectDefaultFileTypeEditor(tester, 'Markdown');

      final layout = harness.shell.layout as DefaultLayoutController;
      layout.closeAllEditors();
      await tester.pumpAndSettle();

      layout.openFile(Uri.file('${harness.workspaceRoot}/test-fixtures/target-three.ufree'));
      await tester.pumpAndSettle();

      expect(harness.shell.systemState.activeEditor, isA<ForgeMdEditor>());
    });

    testWidgets('10: View menu Middle Panel 3 keeps index when only two panels', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseOHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      layout.splitMiddlePanel();
      await tester.pumpAndSettle();
      expect(layout.middlePanels.value.length, equals(2));

      layout.setActiveMiddlePanelIndex(1);
      expect(layout.activeMiddlePanelIndex, equals(1));

      await _selectViewMenuItem(tester, 'Middle Panel 3');

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

Future<void> _dismissQuickOpen(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
}

Future<void> _setCheckbox(
  WidgetTester tester,
  String label,
  bool expected,
) async {
  final checkbox = find.widgetWithText(CheckboxListTile, label);
  expect(checkbox, findsOneWidget);
  await tester.ensureVisible(checkbox);
  await tester.pumpAndSettle();
  final tile = tester.widget<CheckboxListTile>(checkbox);
  if ((tile.value ?? false) != expected) {
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
  }
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

Future<void> _addExtensionMapping(
  WidgetTester tester,
  String ext,
) async {
  await tester.enterText(_fileTypeExtensionField(), ext);
  await tester.pumpAndSettle();
  final add = find.byTooltip('Add Extension');
  await tester.tap(add);
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

Finder _quickOpenText(String text) {
  return find.descendant(of: find.byType(ForgeQuickOpen), matching: find.text(text));
}

Finder _shellExcludedDirectoriesField() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        widget.decoration?.labelText == 'Excluded directories',
  );
}

Finder _fileTypeExtensionField() {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == '.ext',
  );
}

class _PhaseOHarness {
  _PhaseOHarness._({
    required this.shell,
    required this.module,
    required this.application,
    required this.preferences,
    required this.workspaceRoot,
  });

  final DefaultShellApi shell;
  final _PhaseOModule module;
  final ForgeApplication application;
  final ForgePreferencesService preferences;
  final String workspaceRoot;

  static _PhaseOHarness create() {
    final workspaceRoot =
        '${Directory.current.path}/test/phase_o_fixture_workspace';
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
        // Quick open reads the rules through the shell's file system.
        '$workspaceRoot/.gitignore': '*.note\n',
        '$workspaceRoot/test-fixtures/main.test': 'main\n',
        '$workspaceRoot/test-fixtures/alpha.note': 'alpha\n',
        '$workspaceRoot/test-fixtures/nested/zz-nested.note': 'nested\n',
        '$workspaceRoot/test-fixtures/.hidden/zz-hidden.note': 'hidden\n',
        '$workspaceRoot/test-fixtures/target-one.oext': 'target one\n',
        '$workspaceRoot/test-fixtures/target-two.oext': 'target two\n',
        '$workspaceRoot/test-fixtures/target-three.ufree': 'target three\n',
      },
      appName: 'Phase O Harness',
      navigatorKey: navigatorKey,
    );
    (shell.systemState as DefaultSystemState).setWorkspaceRootPath(workspaceRoot);

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);

    final module = _PhaseOModule(workspaceRoot: workspaceRoot);
    module.activate(shell);

    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(shellModule);
    registry.register(module);

    final application = ForgeApplication(
      id: 'phase-o-harness',
      title: 'Phase O Harness',
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
    shell.applications.add(application);

    final layout = shell.layout as DefaultLayoutController;
    layout.openEditor(module.mainEditor, module.mainEditor.uri, middlePanelIndex: 0);

    final preferences = ForgePreferencesService();

    return _PhaseOHarness._(
      shell: shell,
      module: module,
      application: application,
      preferences: preferences,
      workspaceRoot: workspaceRoot,
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

class _PhaseOModule extends ForgeModule {
  _PhaseOModule({required String workspaceRoot}) {
    mainEditor = _PhaseOMainEditor(this, workspaceRoot: workspaceRoot);
    explorerView = _StubView('Explorer View', Icons.folder);
    outlineView = _StubView('Outline View', Icons.account_tree);
    problemsView = _StubView('Problems View', Icons.error_outline);
  }

  late final _PhaseOMainEditor mainEditor;
  late final _StubView explorerView;
  late final _StubView outlineView;
  late final _StubView problemsView;

  @override
  String get displayName => 'Phase O Module';

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

class _PhaseOMainEditor extends ForgeTestTextEditor {
  _PhaseOMainEditor(
    super.module, {
    required String workspaceRoot,
  }) : super(
          document: ForgeTestDocument(
            uri: Uri.file('$workspaceRoot/test-fixtures/main.test'),
            content: 'main\n',
          ),
        );
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

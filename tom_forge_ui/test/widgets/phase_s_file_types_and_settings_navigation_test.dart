import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show FileHandlingResult;
import 'package:tom_forge_ui/src/widgets/forge_quick_open.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'support/shell_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase S: file types and settings navigation paths', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('01: quick-open File Type Defaults opens file-types section', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseSHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openQuickOpenWithQuery(tester, 'File Type Defaults');
      final item = find.descendant(
        of: find.byType(ForgeQuickOpen),
        matching: find.text('File Type Defaults'),
      );
      expect(item, findsOneWidget);
      await tester.tap(item);
      await tester.pumpAndSettle();

      expect(find.text('Default Editor (unmapped extensions)'), findsOneWidget);
      expect(find.text('File Type Associations'), findsOneWidget);
    });

    testWidgets('02: quick-open Chord Shortcuts opens chord search view', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseSHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openQuickOpenWithQuery(tester, 'Chord Shortcuts');
      final item = find.descendant(
        of: find.byType(ForgeQuickOpen),
        matching: find.text('Chord Shortcuts'),
      );
      expect(item, findsOneWidget);
      await tester.tap(item);
      await tester.pumpAndSettle();

      expect(_shortcutSearchField('Search chords...'), findsOneWidget);
    });

    testWidgets('03: keyboard quick-open Enter opens Markdown Mermaid setting', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseSHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyP, shift: true);
      await tester.pumpAndSettle();

      await tester.enterText(_titleSearchField(), 'Markdown: Mermaid');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('Markdown Features'), findsOneWidget);
      expect(find.widgetWithText(CheckboxListTile, 'Mermaid diagrams'), findsOneWidget);
    });

    testWidgets('04: wildcard default Dart opens unknown extension as Dart editor', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseSHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'File Types');
      await _selectDefaultFileTypeEditor(tester, 'Dart');

      final layout = harness.shell.layout as DefaultLayoutController;
      layout.openFile(Uri.file('${harness.workspaceRoot}/test-fixtures/unknown.zzz'));
      await tester.pumpAndSettle();

      expect(harness.shell.systemState.activeEditor, isA<ForgeDartEditor>());
      expect(harness.shell.getFileTypeDefaults()['*'], equals('dart'));
    });

    testWidgets('05: add extension without dot normalizes and maps', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseSHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'File Types');
      await _selectDefaultFileTypeEditor(tester, 'YAML');

      await tester.enterText(_newExtensionField(), 'phaseS');
      await tester.tap(find.byTooltip('Add Extension'));
      await tester.pumpAndSettle();

      expect(harness.shell.getFileTypeDefaults()['.phases'], equals('yaml'));
      expect(harness.preferences.fileTypeDefaultEditors['.phases'], equals('yaml'));
    });

    testWidgets('06: changing .json mapping updates opened editor type', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseSHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'File Types');

      await _setExtensionMapping(tester, '.json', 'Dart');

      final layout = harness.shell.layout as DefaultLayoutController;
      layout.openFile(Uri.file('${harness.workspaceRoot}/test-fixtures/sample.json'));
      await tester.pumpAndSettle();

      expect(harness.shell.systemState.activeEditor, isA<ForgeDartEditor>());
      expect(harness.shell.getFileTypeDefaults()['.json'], equals('dart'));
    });

    testWidgets('07: removing custom extension mapping deletes it', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseSHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'File Types');
      await _selectDefaultFileTypeEditor(tester, 'YAML');

      await tester.enterText(_newExtensionField(), '.gone');
      await tester.tap(find.byTooltip('Add Extension'));
      await tester.pumpAndSettle();
      expect(harness.shell.getFileTypeDefaults()['.gone'], equals('yaml'));

      await _removeExtensionMapping(tester, '.gone');
      await tester.pumpAndSettle();

      expect(harness.shell.getFileTypeDefaults().containsKey('.gone'), isFalse);
      expect(harness.preferences.fileTypeDefaultEditors.containsKey('.gone'), isFalse);
    });

    testWidgets('08: removing mapping falls back to wildcard editor', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseSHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'File Types');
      await _selectDefaultFileTypeEditor(tester, 'YAML');
      await _setExtensionMapping(tester, '.json', 'Dart');
      await _removeExtensionMapping(tester, '.json');

      final layout = harness.shell.layout as DefaultLayoutController;
      layout.openFile(Uri.file('${harness.workspaceRoot}/test-fixtures/sample.json'));
      await tester.pumpAndSettle();

      expect(harness.shell.systemState.activeEditor, isA<ForgeYamlEditor>());
    });

    testWidgets('09: duplicate extension add is ignored', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseSHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'File Types');

      await tester.enterText(_newExtensionField(), '.dupe');
      await tester.tap(find.byTooltip('Add Extension'));
      await tester.pumpAndSettle();
      final beforeKeys = Set<String>.from(harness.shell.getFileTypeDefaults().keys);

      await tester.enterText(_newExtensionField(), '.dupe');
      await tester.tap(find.byTooltip('Add Extension'));
      await tester.pumpAndSettle();
      final afterKeys = Set<String>.from(harness.shell.getFileTypeDefaults().keys);

      expect(afterKeys.length, equals(beforeKeys.length));
      expect(afterKeys.contains('.dupe'), isTrue);
    });

    testWidgets('10: existing extension mapping remains after wildcard change', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseSHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'File Types');

      await _selectDefaultFileTypeEditor(tester, 'YAML');
      await tester.enterText(_newExtensionField(), '.sticky');
      await tester.tap(find.byTooltip('Add Extension'));
      await tester.pumpAndSettle();
      expect(harness.shell.getFileTypeDefaults()['.sticky'], equals('yaml'));

      await _selectDefaultFileTypeEditor(tester, 'Dart');
      await tester.pumpAndSettle();

      expect(harness.shell.getFileTypeDefaults()['*'], equals('dart'));
      expect(harness.shell.getFileTypeDefaults()['.sticky'], equals('yaml'));
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

Future<void> _openQuickOpenWithQuery(WidgetTester tester, String query) async {
  await tester.enterText(_titleSearchField(), query);
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pumpAndSettle();
}

Future<void> _selectDefaultFileTypeEditor(WidgetTester tester, String next) async {
  final dropdown = find.byKey(const Key('file-type-default-editor'));
  expect(dropdown, findsOneWidget);
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(next).last);
  await tester.pumpAndSettle();
}

Future<void> _setExtensionMapping(
  WidgetTester tester,
  String extension,
  String editorName,
) async {
  final dropdown = find.byKey(Key('file-type-editor-$extension'));
  expect(dropdown, findsOneWidget);
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();

  final formField = tester.widget<DropdownButtonFormField<String>>(dropdown);
  formField.onChanged?.call(_editorIdFromTitle(editorName));
  await tester.pumpAndSettle();
}

Future<void> _removeExtensionMapping(WidgetTester tester, String extension) async {
  final removeButton = find.byKey(Key('file-type-remove-$extension'));
  expect(removeButton, findsOneWidget);
  await tester.ensureVisible(removeButton);

  final inkwell = tester.widget<InkWell>(removeButton);
  inkwell.onTap?.call();
  await tester.pumpAndSettle();
}

String _editorIdFromTitle(String title) {
  return switch (title) {
    'Markdown' => 'md',
    'Dart' => 'dart',
    'YAML' => 'yaml',
    'Plain Text' => 'plaintext',
    _ => throw ArgumentError('Unsupported editor title: $title'),
  };
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

Finder _shortcutSearchField(String hintText) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == hintText,
  );
}

Finder _newExtensionField() {
  return find.byKey(const Key('file-type-new-extension'));
}

class _PhaseSHarness {
  _PhaseSHarness._({
    required this.shell,
    required this.module,
    required this.application,
    required this.preferences,
    required this.workspaceRoot,
  });

  final DefaultShellApi shell;
  final _PhaseSModule module;
  final ForgeApplication application;
  final ForgePreferencesService preferences;
  final String workspaceRoot;

  static _PhaseSHarness create() {
    final workspaceRoot =
        '${Directory.current.path}/test/phase_s_fixture_workspace';
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
        '$workspaceRoot/test-fixtures/sample.json': '{"k":1}\n',
        '$workspaceRoot/test-fixtures/unknown.zzz': 'unknown\n',
      },
      appName: 'Phase S Harness',
      navigatorKey: navigatorKey,
    );
    (shell.systemState as DefaultSystemState).setWorkspaceRootPath(workspaceRoot);

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);

    final module = _PhaseSModule(workspaceRoot: workspaceRoot);
    module.activate(shell);

    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(shellModule);
    registry.register(module);

    final application = ForgeApplication(
      title: 'Phase S Harness',
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

    return _PhaseSHarness._(
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

class _PhaseSModule extends ForgeModule {
  _PhaseSModule({required String workspaceRoot}) {
    mainEditor = _PhaseSMainEditor(this, workspaceRoot: workspaceRoot);
    explorerView = _StubView('Explorer View', Icons.folder);
    outlineView = _StubView('Outline View', Icons.account_tree);
    problemsView = _StubView('Problems View', Icons.error_outline);
  }

  late final _PhaseSMainEditor mainEditor;
  late final _StubView explorerView;
  late final _StubView outlineView;
  late final _StubView problemsView;

  @override
  String get displayName => 'Phase S Module';

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

class _PhaseSMainEditor extends ForgeTestTextEditor {
  _PhaseSMainEditor(
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

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

  group('Phase R: editor settings and quick-open setting paths', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('01: Dart font size field updates text settings', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseRHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'Dart Editor');

      await tester.enterText(_textFormFieldByLabel('Size').first, '19');
      await tester.pumpAndSettle();

      expect(harness.shell.getTextSettings('dart').fontSize, equals(19));
    });

    testWidgets('02: Dart tab size field updates text settings', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseRHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'Dart Editor');

      await tester.enterText(_textFormFieldByLabel('Tab'), '6');
      await tester.pumpAndSettle();

      expect(harness.shell.getTextSettings('dart').tabSize, equals(6));
    });

    testWidgets('03: Dart max completion items field updates config', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseRHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'Dart Editor');

      await tester.enterText(_textFormFieldByLabel('Max items'), '13');
      await tester.pumpAndSettle();

      expect(
        harness.shell.getEditorSpecificConfig('dart')['maxCompletionItems'],
        equals(13),
      );
    });

    testWidgets('04: Dart info toggles checkbox updates config', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseRHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'Dart Editor');

      final infoToggle =
          find.widgetWithText(CheckboxListTile, 'Info toggles').first;
      expect(infoToggle, findsOneWidget);
      final before = harness.shell
              .getEditorSpecificConfig('dart')['showInfoToggles']
          as bool? ??
          true;

        await tester.ensureVisible(infoToggle);
        await tester.pumpAndSettle();
          final infoCheckbox =
            find.descendant(of: infoToggle, matching: find.byType(Checkbox));
          expect(infoCheckbox, findsOneWidget);
          await tester.tap(infoCheckbox);
      await tester.pumpAndSettle();

      expect(
        harness.shell.getEditorSpecificConfig('dart')['showInfoToggles'],
        equals(!before),
      );
    });

    testWidgets('05: YAML indent width field updates config', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseRHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'YAML Editor');

      await tester.enterText(_textFormFieldByLabel('Indent'), '32');
      await tester.pumpAndSettle();

      expect(
        harness.shell.getEditorSpecificConfig('yaml')['indentWidth'],
        equals(32),
      );
    });

    testWidgets('06: YAML preview lines accepts zero', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseRHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'YAML Editor');

      await tester.enterText(_textFormFieldByLabel('Preview lines'), '0');
      await tester.pumpAndSettle();

      expect(
        harness.shell.getEditorSpecificConfig('yaml')['collapsedPreviewLines'],
        equals(0),
      );
    });

    testWidgets('07: Markdown regex toggle updates config', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseRHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'Markdown Editor');

      final regexToggle = find.widgetWithText(CheckboxListTile, 'Regex').first;
      expect(regexToggle, findsOneWidget);
      await tester.ensureVisible(regexToggle);
      await tester.pumpAndSettle();
      final before = harness.shell
              .getEditorSpecificConfig('md')['enableRegexSearch']
          as bool? ??
          false;

      await tester.tap(regexToggle);
      await tester.pumpAndSettle();

      expect(
        harness.shell.getEditorSpecificConfig('md')['enableRegexSearch'],
        equals(!before),
      );
    });

    testWidgets('08: Markdown read-only toggle updates config', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseRHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaFileMenu(tester);
      await _openConfigSection(tester, 'Markdown Editor');

      final readOnlyToggle =
          find.widgetWithText(CheckboxListTile, 'Read only').first;
      expect(readOnlyToggle, findsOneWidget);
      await tester.ensureVisible(readOnlyToggle);
      await tester.pumpAndSettle();
      final before =
          harness.shell.getEditorSpecificConfig('md')['readOnly'] as bool? ??
              false;

      await tester.tap(readOnlyToggle);
      await tester.pumpAndSettle();

      expect(
        harness.shell.getEditorSpecificConfig('md')['readOnly'],
        equals(!before),
      );
    });

    testWidgets('09: quick-open setting opens Dart editor section', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseRHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openQuickOpenWithQuery(tester, 'Dart: Font Family');
      final dartSetting = find.descendant(
        of: find.byType(ForgeQuickOpen),
        matching: find.text('Dart: Font Family'),
      );
      expect(dartSetting, findsOneWidget);
      await tester.tap(dartSetting);
      await tester.pumpAndSettle();

      expect(find.text('Dart — Font'), findsOneWidget);
    });

    testWidgets(
        '10: primary+shift+P then Enter opens Markdown math setting section', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseRHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyP, shift: true);
      await tester.pumpAndSettle();

      await tester.enterText(_titleSearchField(), 'Markdown: Math (KaTeX)');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('Markdown Features'), findsOneWidget);
      expect(find.text('Math (KaTeX)'), findsOneWidget);
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

Finder _textFormFieldByLabel(String label) {
  return find.ancestor(
    of: find.text(label),
    matching: find.byType(TextFormField),
  );
}

class _PhaseRHarness {
  _PhaseRHarness._({
    required this.shell,
    required this.module,
    required this.application,
    required this.preferences,
  });

  final DefaultShellApi shell;
  final _PhaseRModule module;
  final ForgeApplication application;
  final ForgePreferencesService preferences;

  static _PhaseRHarness create() {
    final workspaceRoot =
        '${Directory.current.path}/test/phase_r_fixture_workspace';
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
      appName: 'Phase R Harness',
      navigatorKey: navigatorKey,
    );
    (shell.systemState as DefaultSystemState).setWorkspaceRootPath(workspaceRoot);

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);

    final module = _PhaseRModule(workspaceRoot: workspaceRoot);
    module.activate(shell);

    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(shellModule);
    registry.register(module);

    final application = ForgeApplication(
      title: 'Phase R Harness',
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

    return _PhaseRHarness._(
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

class _PhaseRModule extends ForgeModule {
  _PhaseRModule({required String workspaceRoot}) {
    mainEditor = _PhaseRMainEditor(this, workspaceRoot: workspaceRoot);
    explorerView = _StubView('Explorer View', Icons.folder);
    outlineView = _StubView('Outline View', Icons.account_tree);
    problemsView = _StubView('Problems View', Icons.error_outline);
  }

  late final _PhaseRMainEditor mainEditor;
  late final _StubView explorerView;
  late final _StubView outlineView;
  late final _StubView problemsView;

  @override
  String get displayName => 'Phase R Module';

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

class _PhaseRMainEditor extends ForgeTestTextEditor {
  _PhaseRMainEditor(
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

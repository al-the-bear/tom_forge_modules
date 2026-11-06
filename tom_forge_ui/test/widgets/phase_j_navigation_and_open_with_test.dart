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

  group('Phase J: navigation, configuration accordion, and open-with', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('01: title-bar command palette button opens and closes', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseJHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Command Palette'));
      await tester.pumpAndSettle();

      expect(find.byType(ForgeQuickOpen), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(ForgeQuickOpen), findsNothing);
    });

    testWidgets('02: back and forward buttons are disabled by default', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseJHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final back = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.arrow_back),
          matching: find.byType(IconButton),
        ),
      );
      final forward = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.arrow_forward),
          matching: find.byType(IconButton),
        ),
      );

      expect(back.onPressed, isNull);
      expect(forward.onPressed, isNull);
    });

    testWidgets('03: application switcher activates the selected application', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseJHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Switch Application'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Phase J Alt').last);
      await tester.pumpAndSettle();

      expect(harness.shell.applications.active, harness.altApplication);
    });

    testWidgets('04: settings open with shell section expanded by default', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseJHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaAction(harness, tester);

      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Default Shell'), findsNothing);
    });

    testWidgets('05: tapping terminal section reveals terminal settings', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseJHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();
      await _openSettingsViaAction(harness, tester);

      await tester.tap(find.text('Terminal').first);
      await tester.pumpAndSettle();

      expect(find.text('Default Shell'), findsOneWidget);
    });

    testWidgets('06: switching sections toggles shell and terminal content', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseJHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();
      await _openSettingsViaAction(harness, tester);

      await tester.tap(find.text('Terminal').first);
      await tester.pumpAndSettle();

      expect(find.text('Default Shell'), findsOneWidget);

      await tester.tap(find.text('Shell').first);
      await tester.pumpAndSettle();

      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Default Shell'), findsNothing);
    });

    testWidgets('07: openFileWith shows chooser when multiple editors match', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseJHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      await layout.openFileWith(
        Uri.parse('file:///workspace/test-fixtures/choice.multi'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open With'), findsOneWidget);
      expect(find.text('Dart Code Editor'), findsOneWidget);
      expect(find.text('YAML Editor'), findsOneWidget);
    });

    testWidgets('08: open-with cancel clears pending selection', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseJHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      final beforeCount = harness.shell.systemState.openEditors.length;

      await layout.openFileWith(
        Uri.parse('file:///workspace/test-fixtures/choice.multi'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Open With'), findsNothing);
      expect(layout.pendingEditorChoice.value, isNull);
      expect(harness.shell.systemState.openEditors.length, equals(beforeCount));
    });

    testWidgets('09: selecting YAML candidate opens YAML-based choice editor', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseJHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      await layout.openFileWith(
        Uri.parse('file:///workspace/test-fixtures/choice.multi'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('YAML Editor').first);
      await tester.pumpAndSettle();

      expect(harness.shell.systemState.activeEditor, isA<_AltYamlChoiceEditor>());
    });

    testWidgets('10: reset panel locations keeps middle index in bounds', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseJHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      layout.splitMiddlePanel();
      layout.setActiveMiddlePanelIndex(1);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Reset Panel Locations'));
      await tester.pumpAndSettle();

      expect(layout.activeMiddlePanelIndex, greaterThanOrEqualTo(0));
      expect(
        layout.activeMiddlePanelIndex,
        lessThan(layout.middlePanels.value.length),
      );
    });
  });
}

Future<void> _openSettingsViaAction(
  _PhaseJHarness harness,
  WidgetTester tester,
) async {
  final opened = harness.shell.executeAction('forge.openSettings');
  expect(opened, isTrue);
  await tester.pumpAndSettle();
}

class _PhaseJHarness {
  _PhaseJHarness._({
    required this.shell,
    required this.module,
    required this.application,
    required this.altApplication,
    required this.preferences,
  });

  final DefaultShellApi shell;
  final _PhaseJModule module;
  final ForgeApplication application;
  final ForgeApplication altApplication;
  final ForgePreferencesService preferences;

  static _PhaseJHarness create() {
    final navigatorKey = GlobalKey<NavigatorState>();
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {
        '/workspace/test-fixtures/sample.md': '# Phase J\n',
        '/workspace/test-fixtures/choice.multi': 'choice content\n',
      },
      appName: 'Phase J Harness',
      navigatorKey: navigatorKey,
    );

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);

    final module = _PhaseJModule();
    module.activate(shell);

    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(shellModule);
    registry.register(module);

    final application = ForgeApplication(
      id: 'phase-j-harness',
      title: 'Phase J Harness',
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

    final altApplication = ForgeApplication(
      id: 'phase-j-alt',
      title: 'Phase J Alt',
      layout: const PanelLayout(
        leftPanel: PanelConfig(initialSize: 200, tabs: []),
        rightPanel: PanelConfig(initialSize: 200, tabs: []),
        bottomPanel: PanelConfig(initialSize: 150, tabs: []),
        middlePanels: [MiddlePanelConfig()],
      ),
    );
    shell.applications.add(altApplication);

    final layout = shell.layout as DefaultLayoutController;
    layout.openEditor(module.editor, module.editor.uri, middlePanelIndex: 0);

    final preferences = ForgePreferencesService();

    return _PhaseJHarness._(
      shell: shell,
      module: module,
      application: application,
      altApplication: altApplication,
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

class _PhaseJModule extends ForgeModule {
  late final ForgeTestTextEditor editor;
  late final _AltDartChoiceEditor altDartEditor;
  late final _AltYamlChoiceEditor altYamlEditor;
  late final _StubView explorerView;
  late final _StubView outlineView;
  late final _StubView problemsView;

  _PhaseJModule() {
    editor = ForgeTestTextEditor(
      this,
      document: ForgeTestDocument(
        uri: Uri.parse('file:///workspace/test-fixtures/sample.md'),
        content: '# Phase J\n',
      ),
    );
    altDartEditor = _AltDartChoiceEditor(this);
    altYamlEditor = _AltYamlChoiceEditor(this);
    explorerView = _StubView('Explorer View', Icons.folder);
    outlineView = _StubView('Outline View', Icons.account_tree);
    problemsView = _StubView('Problems View', Icons.error_outline);
  }

  @override
  String get displayName => 'Phase J Module';

  ForgeShellApi? _shell;

  @override
  void activate(ForgeShellApi shell) => _shell = shell;

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

  /// The two editors offered for a `.multi` file (Open With).
  @override
  List<ForgeEditorChoice> editorChoicesFor(Uri uri) {
    if (!uri.path.endsWith('.multi')) return const [];
    ForgeEditorChoice choice(String id, String label, ForgeEditor editor) =>
        ForgeEditorChoice(
          id: id,
          label: label,
          icon: editor.icon,
          open: (uri, {middlePanelIndex}) => _shell!.layout.openEditor(
            editor,
            uri,
            middlePanelIndex: middlePanelIndex,
          ),
        );
    return [
      choice('multi-dart', 'Dart Code Editor', altDartEditor),
      choice('multi-yaml', 'YAML Editor', altYamlEditor),
    ];
  }
}

class _AltDartChoiceEditor extends ForgeTestTextEditor {
  _AltDartChoiceEditor(super.module)
      : super(
          document: ForgeTestDocument(
            uri: Uri.parse('file:///workspace/test-fixtures/choice.multi'),
            content: 'dart candidate\n',
          ),
        );

  @override
  FileHandlingResult canHandle(Uri uri) {
    return uri.path.endsWith('.multi')
        ? FileHandlingResult.accept
        : FileHandlingResult.reject;
  }
}

class _AltYamlChoiceEditor extends ForgeTestTextEditor {
  _AltYamlChoiceEditor(super.module)
      : super(
          document: ForgeTestDocument(
            uri: Uri.parse('file:///workspace/test-fixtures/choice.multi'),
            content: 'yaml candidate\n',
          ),
        );

  @override
  FileHandlingResult canHandle(Uri uri) {
    return uri.path.endsWith('.multi')
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
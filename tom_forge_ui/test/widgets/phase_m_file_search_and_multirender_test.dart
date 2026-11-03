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

  group('Phase M: file search and multi-render lifecycle coverage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('01: primary+shift+P toggles quick-open open and closed', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseMHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyP, shift: true);
      await tester.pumpAndSettle();
      expect(find.byType(ForgeQuickOpen), findsOneWidget);

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyP, shift: true);
      await tester.pumpAndSettle();
      expect(find.byType(ForgeQuickOpen), findsNothing);
    });

    testWidgets('02: one-character query does not trigger workspace file search', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseMHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openQuickOpenWithQuery(tester, 'n');

      expect(_quickOpenText('notes.test'), findsNothing);
    });

    testWidgets('03: two-character query includes unopened workspace file result', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseMHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final seeded = await harness.shell.fileSystem.list(
        Uri.file('/workspace/test-fixtures/'),
      );
      expect(
        seeded.any((entry) => entry.name == 'notes.test'),
        isTrue,
      );

      await _openQuickOpenWithQuery(tester, 'no');
      expect(find.byType(ForgeQuickOpen), findsOneWidget);

      expect(_quickOpenText('notes.test'), findsOneWidget);
    });

    testWidgets('04: selecting file-search result opens notes editor', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseMHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openQuickOpenWithQuery(tester, 'no');
      expect(find.byType(ForgeQuickOpen), findsOneWidget);
      await tester.tap(_quickOpenText('notes.test'));
      await tester.pumpAndSettle();

      expect(
        harness.shell.systemState.activeEditor?.uri.path,
        endsWith('notes.test'),
      );
    });

    testWidgets('05: openFileWith with two .multi editors shows chooser dialog', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseMHarness.create();

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

    testWidgets('06: selecting YAML candidate opens yaml multi editor', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseMHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      await layout.openFileWith(
        Uri.parse('file:///workspace/test-fixtures/choice.multi'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('YAML Editor'));
      await tester.pumpAndSettle();

      expect(harness.shell.systemState.activeEditor, isA<_PhaseMMultiYamlEditor>());
    });

    testWidgets('07: canceling open-with clears pending choice without opening', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseMHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      final before = harness.shell.systemState.openEditors.length;

      await layout.openFileWith(
        Uri.parse('file:///workspace/test-fixtures/choice.multi'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(layout.pendingEditorChoice.value, isNull);
      expect(harness.shell.systemState.openEditors.length, equals(before));
    });

    testWidgets('08: copyComponent creates second panel copy without duplicating open editor list', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseMHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      final main = harness.module.mainEditor;

      layout.copyComponent(main, 1);
      await tester.pumpAndSettle();

      expect(layout.middlePanels.value.length, equals(2));
      expect(layout.middlePanels.value[0], contains(main));
      expect(layout.middlePanels.value[1], contains(main));
      expect(
        harness.shell.systemState.openEditors.where((e) => e == main).length,
        equals(1),
      );
    });

    testWidgets('09: closing copied tab keeps original editor tab open', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseMHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      final main = harness.module.mainEditor;

      layout.copyComponent(main, 1);
      await tester.pumpAndSettle();
      expect(layout.middlePanels.value.length, equals(2));

      final closeButtons = find.byTooltip('Close');
      expect(closeButtons, findsNWidgets(2));
      await tester.tap(closeButtons.last);
      await tester.pumpAndSettle();

      expect(layout.middlePanels.value.length, equals(1));
      expect(layout.middlePanels.value.first, contains(main));
      expect(harness.shell.systemState.openEditors, contains(main));
    });

    testWidgets('10: closeAllEditors clears all copies and leaves one empty panel', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseMHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      layout.copyComponent(harness.module.mainEditor, 1);
      await tester.pumpAndSettle();
      expect(layout.middlePanels.value.length, equals(2));

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
  await tester.pump(const Duration(milliseconds: 600));
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

Finder _quickOpenText(String text) {
  return find.descendant(of: find.byType(ForgeQuickOpen), matching: find.text(text));
}

class _PhaseMHarness {
  _PhaseMHarness._({
    required this.shell,
    required this.module,
    required this.application,
    required this.preferences,
  });

  final DefaultShellApi shell;
  final _PhaseMModule module;
  final ForgeApplication application;
  final ForgePreferencesService preferences;

  static _PhaseMHarness create() {
    final navigatorKey = GlobalKey<NavigatorState>();
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {
        '/workspace/test-fixtures/main.test': 'main\n',
        '/workspace/test-fixtures/notes.test': 'notes\n',
        '/workspace/test-fixtures/choice.multi': 'choice\n',
      },
      appName: 'Phase M Harness',
      navigatorKey: navigatorKey,
    );
    (shell.systemState as DefaultSystemState).setWorkspaceRootPath('/workspace');

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);

    final module = _PhaseMModule();
    module.activate(shell);

    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(shellModule);
    registry.register(module);

    final application = ForgeApplication(
      id: 'phase-m-harness',
      title: 'Phase M Harness',
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

    return _PhaseMHarness._(
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

class _PhaseMModule extends ForgeModule {
  late final _PhaseMMainEditor mainEditor;
  late final _PhaseMNotesEditor notesEditor;
  late final _PhaseMMultiDartEditor multiDartEditor;
  late final _PhaseMMultiYamlEditor multiYamlEditor;
  late final _StubView explorerView;
  late final _StubView outlineView;
  late final _StubView problemsView;

  _PhaseMModule() {
    mainEditor = _PhaseMMainEditor(this);
    notesEditor = _PhaseMNotesEditor(this);
    multiDartEditor = _PhaseMMultiDartEditor(this);
    multiYamlEditor = _PhaseMMultiYamlEditor(this);
    explorerView = _StubView('Explorer View', Icons.folder);
    outlineView = _StubView('Outline View', Icons.account_tree);
    problemsView = _StubView('Problems View', Icons.error_outline);
  }

  @override
  String get displayName => 'Phase M Module';

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => [
        mainEditor,
        notesEditor,
        multiDartEditor,
        multiYamlEditor,
      ];

  @override
  List<ForgeView> get views => [explorerView, outlineView, problemsView];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
}

class _PhaseMMainEditor extends ForgeTestTextEditor {
  _PhaseMMainEditor(super.module)
      : super(
          document: ForgeTestDocument(
            uri: Uri.parse('file:///workspace/test-fixtures/main.test'),
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

class _PhaseMNotesEditor extends ForgeTestTextEditor {
  _PhaseMNotesEditor(super.module)
      : super(
          document: ForgeTestDocument(
            uri: Uri.parse('file:///workspace/test-fixtures/notes.test'),
            content: 'notes\n',
          ),
        );

  @override
  FileHandlingResult canHandle(Uri uri) {
    return uri.path.endsWith('/notes.test')
        ? FileHandlingResult.accept
        : FileHandlingResult.reject;
  }
}

class _PhaseMMultiDartEditor extends ForgeTestTextEditor {
  _PhaseMMultiDartEditor(super.module)
      : super(
          document: ForgeTestDocument(
            uri: Uri.parse('file:///workspace/test-fixtures/choice.multi'),
            content: 'multi dart\n',
          ),
        );

  @override
  FileHandlingResult canHandle(Uri uri) {
    return uri.path.endsWith('.multi')
        ? FileHandlingResult.accept
        : FileHandlingResult.reject;
  }
}

class _PhaseMMultiYamlEditor extends ForgeTestTextEditor {
  _PhaseMMultiYamlEditor(super.module)
      : super(
          document: ForgeTestDocument(
            uri: Uri.parse('file:///workspace/test-fixtures/choice.multi'),
            content: 'multi yaml\n',
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
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_forge_core/tom_forge_core.dart'
    show
        FileHandlingResult,
        ForgeDiagnostic,
        ForgePanelLocation,
        ForgeSeverity,
        ForgeTextPosition,
        ForgeTextRange;
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'support/shell_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase W: search, output, explorer, and focus', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('01: output channel view displays channel content', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseWHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Create an output channel and write content
      final outputManager = harness.shell.output as DefaultOutputChannelManager;
      final channel = outputManager.create('Build');
      channel.appendLine('Building project...');
      channel.appendLine('Compilation complete.');

      await tester.pumpAndSettle();

      // Open Output panel tab in bottom panel
      final outputTab = find.text('Output');
      if (outputTab.evaluate().isNotEmpty) {
        await tester.tap(outputTab.first);
        await tester.pumpAndSettle();
      }

      // Verify content appears
      expect(
        find.textContaining('Building').evaluate().isNotEmpty ||
            find.textContaining('Compilation').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('02: output channel clear removes all content', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseWHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Create and populate output channel
      final outputManager = harness.shell.output as DefaultOutputChannelManager;
      final channel = outputManager.create('Test Output') as DefaultOutputChannel;
      channel.appendLine('Line 1');
      channel.appendLine('Line 2');

      await tester.pumpAndSettle();

      // Clear channel
      channel.clear();
      await tester.pumpAndSettle();

      // Channel should be empty
      expect(channel.lines, isEmpty);
    });

    testWidgets('03: focusNextPanel cycles through visible panels', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseWHarness.create();
      final systemState = harness.shell.systemState as DefaultSystemState;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Initially focus should be on middle panel (editor area)
      systemState.setFocusedPanelLocation(ForgePanelLocation.middle);
      await tester.pumpAndSettle();

      expect(systemState.focusedPanelLocation, equals(ForgePanelLocation.middle));

      // Focus next panel
      systemState.focusNextPanel();
      await tester.pumpAndSettle();

      // Should cycle to next visible panel
      expect(systemState.focusedPanelLocation, isNotNull);
      expect(
        systemState.focusedPanelLocation,
        isNot(equals(ForgePanelLocation.middle)),
      );
    });

    testWidgets('04: togglePanel changes panel visibility', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseWHarness.create();
      final layout = harness.shell.layout as DefaultLayoutController;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Left panel initially visible
      expect(layout.leftPanel.value.isVisible, isTrue);

      // Toggle left panel off
      layout.togglePanel(ForgePanelLocation.left);
      await tester.pumpAndSettle();

      expect(layout.leftPanel.value.isVisible, isFalse);

      // Toggle left panel back on
      layout.togglePanel(ForgePanelLocation.left);
      await tester.pumpAndSettle();

      expect(layout.leftPanel.value.isVisible, isTrue);
    });

    testWidgets('05: diagnostics summary updates when diagnostics added', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseWHarness.create();
      final diagnosticsManager =
          harness.shell.diagnostics as DefaultDiagnosticManager;
      final systemState = harness.shell.systemState as DefaultSystemState;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Initially no diagnostics
      expect(systemState.diagnosticSummary.errors, equals(0));

      // Add some diagnostics
      final collection = diagnosticsManager.createCollection('test');
      collection.set(Uri.file('${harness.workspaceRoot}/test.dart'), [
        ForgeDiagnostic(
          uri: Uri.file('${harness.workspaceRoot}/test.dart'),
          range: ForgeTextRange(
            start: const ForgeTextPosition(line: 1, column: 0),
            end: const ForgeTextPosition(line: 1, column: 10),
          ),
          message: 'Test error',
          severity: ForgeSeverity.error,
          source: 'test',
        ),
        ForgeDiagnostic(
          uri: Uri.file('${harness.workspaceRoot}/test.dart'),
          range: ForgeTextRange(
            start: const ForgeTextPosition(line: 2, column: 0),
            end: const ForgeTextPosition(line: 2, column: 10),
          ),
          message: 'Test warning',
          severity: ForgeSeverity.warning,
          source: 'test',
        ),
      ]);

      await tester.pumpAndSettle();

      // Summary should be updated
      expect(systemState.diagnosticSummary.errors, equals(1));
      expect(systemState.diagnosticSummary.warnings, equals(1));
    });

    testWidgets('06: splitMiddlePanel adds a new editor panel', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseWHarness.create();
      final layout = harness.shell.layout as DefaultLayoutController;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Initially one middle panel
      expect(layout.middlePanels.value.length, equals(1));

      // Split to create second panel
      layout.splitMiddlePanel();
      await tester.pumpAndSettle();

      expect(layout.middlePanels.value.length, equals(2));

      // Split again
      layout.splitMiddlePanel();
      await tester.pumpAndSettle();

      expect(layout.middlePanels.value.length, equals(3));
    });

    testWidgets('07: active middle panel index updates on setActiveMiddlePanelIndex', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseWHarness.create();
      final layout = harness.shell.layout as DefaultLayoutController;
      final systemState = harness.shell.systemState as DefaultSystemState;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Create multiple panels
      layout.splitMiddlePanel();
      layout.splitMiddlePanel();
      await tester.pumpAndSettle();

      expect(layout.middlePanels.value.length, equals(3));
      
      // Initially active index should be 0
      expect(systemState.activeMiddlePanelIndex, equals(0));

      // Set active to panel 2
      layout.setActiveMiddlePanelIndex(2);
      await tester.pumpAndSettle();

      expect(systemState.activeMiddlePanelIndex, equals(2));
      
      // Set active back to panel 1
      layout.setActiveMiddlePanelIndex(1);
      await tester.pumpAndSettle();

      expect(systemState.activeMiddlePanelIndex, equals(1));
    });

    testWidgets('08: theme mode persists to preferences', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseWHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Switch to dark theme
      harness.preferences.themeMode = ThemeMode.dark;
      await harness.preferences.save();
      await tester.pumpAndSettle();

      expect(harness.preferences.themeMode, equals(ThemeMode.dark));

      // Switch to light theme
      harness.preferences.themeMode = ThemeMode.light;
      await harness.preferences.save();
      await tester.pumpAndSettle();

      expect(harness.preferences.themeMode, equals(ThemeMode.light));
    });

    testWidgets('09: copyComponent creates editor copy in another panel', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseWHarness.create();
      final layout = harness.shell.layout as DefaultLayoutController;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Split to have two panels
      layout.splitMiddlePanel();
      await tester.pumpAndSettle();

      // Get initial editor counts
      final panel0Count = layout.middlePanels.value[0].length;
      final panel1Count = layout.middlePanels.value[1].length;

      // Copy main editor to panel 1
      layout.copyComponent(harness.module.mainEditor, 1);
      await tester.pumpAndSettle();

      // Panel 0 should keep the editor
      expect(layout.middlePanels.value[0].length, equals(panel0Count));
      // Panel 1 should have one more editor copy
      expect(layout.middlePanels.value[1].length, equals(panel1Count + 1));
    });

    testWidgets('10: closeAllEditors removes all open editors', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseWHarness.create();
      final layout = harness.shell.layout as DefaultLayoutController;
      final systemState = harness.shell.systemState as DefaultSystemState;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Open additional editors
      layout.openEditor(
        harness.module.secondaryEditor,
        harness.module.secondaryEditor.uri,
        middlePanelIndex: 0,
      );
      layout.openEditor(
        harness.module.tertiaryEditor,
        harness.module.tertiaryEditor.uri,
        middlePanelIndex: 0,
      );
      await tester.pumpAndSettle();

      // Should have 3 editors open
      expect(systemState.openEditors.length, equals(3));

      // Close all editors
      layout.closeAllEditors();
      await tester.pumpAndSettle();

      // Should have no editors
      expect(systemState.openEditors.length, equals(0));
      expect(layout.middlePanels.value.length, equals(1));
      expect(layout.middlePanels.value[0], isEmpty);
    });
  });
}

class _PhaseWHarness {
  _PhaseWHarness._({
    required this.shell,
    required this.module,
    required this.application,
    required this.preferences,
    required this.workspaceRoot,
  });

  final DefaultShellApi shell;
  final _PhaseWModule module;
  final ForgeApplication application;
  final ForgePreferencesService preferences;
  final String workspaceRoot;

  static _PhaseWHarness create() {
    final workspaceRoot =
        '${Directory.current.path}/test/phase_w_fixture_workspace';
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
        '$workspaceRoot/test-fixtures/main.test': 'main content\n',
        '$workspaceRoot/test-fixtures/secondary.test': 'secondary content\n',
        '$workspaceRoot/test-fixtures/tertiary.test': 'tertiary content\n',
        '$workspaceRoot/test-fixtures/search.txt':
            'Hello world\nSearch for this\nAnother line\n',
      },
      appName: 'Phase W Harness',
      navigatorKey: navigatorKey,
    );
    (shell.systemState as DefaultSystemState)
        .setWorkspaceRootPath(workspaceRoot);

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);

    final module = _PhaseWModule(
      workspaceRoot: workspaceRoot,
      outputManager: shell.output,
    );
    module.activate(shell);

    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(shellModule);
    registry.register(module);

    final application = ForgeApplication(
      title: 'Phase W Harness',
      layout: PanelLayout(
        leftPanel: PanelConfig(
          initialSize: 240,
          tabs: [
            PanelTabConfig(
              title: 'Explorer',
              icon: Icons.folder,
              sections: [module.explorerView],
            ),
            PanelTabConfig(
              title: 'Search',
              icon: Icons.search,
              sections: [module.searchView],
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
            PanelTabConfig(
              title: 'Problems',
              icon: Icons.error_outline,
              sections: [module.problemsView],
            ),
            PanelTabConfig(
              title: 'Output',
              icon: Icons.output,
              sections: [module.outputView],
            ),
            const PanelTabConfig(
              title: 'Terminal',
              icon: Icons.terminal,
              sections: [],
            ),
          ],
        ),
        middlePanels: const [MiddlePanelConfig()],
      ),
    );

    final layout = shell.layout as DefaultLayoutController;
    layout.openEditor(
      module.mainEditor,
      module.mainEditor.uri,
      middlePanelIndex: 0,
    );

    final preferences = ForgePreferencesService();

    return _PhaseWHarness._(
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
            notificationManager:
                shell.notifications as DefaultNotificationManager,
            preferencesService: preferences,
          ),
        ),
      ),
    );
  }
}

class _PhaseWModule extends ForgeModule {
  _PhaseWModule({
    required String workspaceRoot,
    required ForgeOutputChannelManager outputManager,
  }) {
    mainEditor = _PhaseWMainEditor(
      this,
      workspaceRoot: workspaceRoot,
      fileName: 'main.test',
      title: 'Main Test',
    );
    secondaryEditor = _PhaseWMainEditor(
      this,
      workspaceRoot: workspaceRoot,
      fileName: 'secondary.test',
      title: 'Secondary',
    );
    tertiaryEditor = _PhaseWMainEditor(
      this,
      workspaceRoot: workspaceRoot,
      fileName: 'tertiary.test',
      title: 'Tertiary',
    );
    explorerView = _StubView('Explorer View', Icons.folder);
    searchView = _StubView('Search View', Icons.search);
    outlineView = _StubView('Outline View', Icons.account_tree);
    problemsView = _StubView('Problems View', Icons.error_outline);
    outputView = ForgeOutputView(channelManager: outputManager);
  }

  late final _PhaseWMainEditor mainEditor;
  late final _PhaseWMainEditor secondaryEditor;
  late final _PhaseWMainEditor tertiaryEditor;
  late final _StubView explorerView;
  late final _StubView searchView;
  late final _StubView outlineView;
  late final _StubView problemsView;
  late final ForgeView outputView;

  @override
  String get displayName => 'Phase W Module';

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors =>
      [mainEditor, secondaryEditor, tertiaryEditor];

  @override
  List<ForgeView> get views =>
      [explorerView, searchView, outlineView, problemsView, outputView];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
}

class _PhaseWMainEditor extends ForgeTestTextEditor {
  _PhaseWMainEditor(
    super.module, {
    required String workspaceRoot,
    required String fileName,
    required String title,
  }) : super(
          document: ForgeTestDocument(
            uri: Uri.file('$workspaceRoot/test-fixtures/$fileName'),
            content: '$title content\n',
          ),
        ) {
    _customTitle.value = title;
  }

  final _customTitle = ValueNotifier<String>('');

  @override
  ValueListenable<String> get title => _customTitle;

  @override
  FileHandlingResult canHandle(Uri uri) {
    return uri.path.endsWith('.test')
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

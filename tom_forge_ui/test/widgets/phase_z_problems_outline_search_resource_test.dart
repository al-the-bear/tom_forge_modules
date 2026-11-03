import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'support/shell_test_utils.dart';

const _caseToggleKey = ValueKey<String>('forge.search.toggle.case');
const _wordToggleKey = ValueKey<String>('forge.search.toggle.word');
const _regexToggleKey = ValueKey<String>('forge.search.toggle.regex');
const _stopSearchKey = ValueKey<String>('forge.search.stop');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase Z: problems, outline, search, and resources', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('01: Problems view hides system diagnostics in empty state', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseZHarness.create(includeProblems: true);
      final diagnostics = harness.shell.diagnostics as DefaultDiagnosticManager;
      final collection = diagnostics.createCollection('phase-z-problems-empty');

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      expect(find.text('No problems detected'), findsOneWidget);

      collection.set(harness.module.mainEditor.uri, [
        ForgeDiagnostic(
          uri: harness.module.mainEditor.uri,
          range: _range(),
          message: 'System-only warning',
          severity: ForgeSeverity.warning,
          source: 'shell',
          category: DiagnosticCategory.system,
        ),
      ]);
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('No problems detected'), findsOneWidget);

      collection.set(harness.module.mainEditor.uri, [
        ForgeDiagnostic(
          uri: harness.module.mainEditor.uri,
          range: _range(),
          message: 'Analysis error',
          severity: ForgeSeverity.error,
          source: 'analyzer',
        ),
      ]);
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('Analysis error'), findsOneWidget);
      expect(find.text('No problems detected'), findsNothing);
    });

    testWidgets('02: Problems severity chips filter diagnostics and counts', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseZHarness.create(includeProblems: true);
      final diagnostics = harness.shell.diagnostics as DefaultDiagnosticManager;
      final collection = diagnostics.createCollection('phase-z-problems-filter');

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      collection.set(harness.module.mainEditor.uri, [
        ForgeDiagnostic(
          uri: harness.module.mainEditor.uri,
          range: _range(0),
          message: 'Error alpha',
          severity: ForgeSeverity.error,
          source: 'analyzer',
        ),
        ForgeDiagnostic(
          uri: harness.module.mainEditor.uri,
          range: _range(1),
          message: 'Warning beta',
          severity: ForgeSeverity.warning,
          source: 'analyzer',
        ),
        ForgeDiagnostic(
          uri: harness.module.mainEditor.uri,
          range: _range(2),
          message: 'Info gamma',
          severity: ForgeSeverity.info,
          source: 'analyzer',
        ),
      ]);
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('All (3)'), findsOneWidget);
      expect(find.text('Errors (1)'), findsOneWidget);
      expect(
        find.text('Warnings (2)').evaluate().isNotEmpty ||
            find.text('Warnings (1)').evaluate().isNotEmpty,
        isTrue,
      );

      await tester.tap(find.text('Errors (1)'));
      await tester.pump();

      expect(find.text('Error alpha'), findsOneWidget);
      expect(find.text('Warning beta'), findsNothing);
      expect(find.text('Info gamma'), findsNothing);

        final warningsChip =
          find.text('Warnings (2)').evaluate().isNotEmpty
            ? find.text('Warnings (2)')
            : find.text('Warnings (1)');
        await tester.tap(warningsChip.first);
      await tester.pump();

      expect(find.text('Error alpha'), findsOneWidget);
      expect(find.text('Warning beta'), findsOneWidget);
      expect(find.text('Info gamma'), findsNothing);

      await tester.tap(find.text('All (3)'));
      await tester.pump();

      expect(find.text('Info gamma'), findsOneWidget);
    });

    testWidgets('03: Problems search toggles and row click focus editor', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseZHarness.create(includeProblems: true);
      final diagnostics = harness.shell.diagnostics as DefaultDiagnosticManager;
      final systemState = harness.shell.systemState as DefaultSystemState;
      final layout = harness.shell.layout as DefaultLayoutController;
      final collection = diagnostics.createCollection('phase-z-problems-search');

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      layout.openEditor(harness.module.secondaryEditor, harness.module.secondaryEditor.uri);
      layout.openEditor(harness.module.mainEditor, harness.module.mainEditor.uri);
      await tester.pump();
      expect(systemState.activeEditor, same(harness.module.mainEditor));

      collection.set(harness.module.secondaryEditor.uri, [
        ForgeDiagnostic(
          uri: harness.module.secondaryEditor.uri,
          range: _range(0),
          message: 'shell',
          severity: ForgeSeverity.warning,
          source: 'analyzer',
        ),
        ForgeDiagnostic(
          uri: harness.module.secondaryEditor.uri,
          range: _range(1),
          message: 'shells',
          severity: ForgeSeverity.warning,
          source: 'analyzer',
        ),
        ForgeDiagnostic(
          uri: harness.module.secondaryEditor.uri,
          range: _range(2),
          message: 'HELLO',
          severity: ForgeSeverity.info,
          source: 'analyzer',
        ),
      ]);
      await tester.pump(const Duration(milliseconds: 150));

      final filterField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Filter problems...',
      );
      expect(filterField, findsOneWidget);

      await tester.enterText(filterField, 'shell');
      await tester.pump();

      expect(find.text('shell'), findsAtLeast(2));
      expect(find.text('shells'), findsOneWidget);

      await _activateProblemsToggle(tester, 'W');
      await tester.pump();

      expect(find.text('shell'), findsAtLeast(2));
      expect(find.text('shells'), findsNothing);

      await tester.enterText(filterField, 'hello');
      await _activateProblemsToggle(tester, 'Aa');
      await tester.pump();

      expect(find.text('HELLO'), findsNothing);

      await _activateProblemsToggle(tester, 'Aa');
      await tester.pump();

      expect(find.text('HELLO'), findsOneWidget);

      await tester.enterText(filterField, 'shell');
      await _activateProblemsToggle(tester, 'W');
      await tester.pump();

      await tester.tap(find.text('shell').last);
      await tester.pump();

      expect(systemState.activeEditor, same(harness.module.secondaryEditor));
    });

    testWidgets('04: Outline view shows empty state with no provider', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseZHarness.create(includeOutline: true);

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      expect(find.text('No outline available'), findsOneWidget);
    });

    testWidgets('05: Outline updates on active editor and provider changes', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseZHarness.create(includeOutline: true);
      final outlineManager = harness.shell.outline as DefaultOutlineManager;
      final layout = harness.shell.layout as DefaultLayoutController;
      final provider = _MutableOutlineProvider();
      addTearDown(provider.dispose);

      provider.setItems(
        harness.module.mainEditor.uri,
        [
          ForgeOutlineItem(
            label: 'MainClass',
            kind: ForgeSymbolKind.classKind,
            range: _range(0),
            selectionRange: _range(0),
            children: [
              ForgeOutlineItem(
                label: 'build',
                detail: '(ctx)',
                kind: ForgeSymbolKind.method,
                range: _range(1),
                selectionRange: _range(1),
              ),
            ],
          ),
        ],
        notify: false,
      );
      final disposable = outlineManager.registerProvider(provider);
      addTearDown(disposable.dispose);

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      expect(find.text('MainClass'), findsOneWidget);
      expect(find.text('build'), findsOneWidget);
      expect(find.text('(ctx)'), findsOneWidget);
      expect(find.byIcon(Icons.class_outlined), findsOneWidget);
      expect(find.byIcon(Icons.functions), findsOneWidget);

      provider.setItems(
        harness.module.secondaryEditor.uri,
        [
          ForgeOutlineItem(
            label: 'SecondaryTop',
            kind: ForgeSymbolKind.section,
            range: _range(0),
            selectionRange: _range(0),
          ),
        ],
        notify: false,
      );
      layout.openEditor(harness.module.secondaryEditor, harness.module.secondaryEditor.uri);
      await tester.pumpAndSettle();

      expect(find.text('SecondaryTop'), findsOneWidget);
      expect(find.text('MainClass'), findsNothing);

      provider.setItems(
        harness.module.secondaryEditor.uri,
        [
          ForgeOutlineItem(
            label: 'SecondaryUpdated',
            kind: ForgeSymbolKind.section,
            range: _range(0),
            selectionRange: _range(0),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('SecondaryUpdated'), findsOneWidget);
      expect(find.text('SecondaryTop'), findsNothing);
    });

    testWidgets('06: Search streams results and match click focuses editor', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseZHarness.create(includeSearch: true);
      final layout = harness.shell.layout as DefaultLayoutController;
      final systemState = harness.shell.systemState as DefaultSystemState;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      layout.openEditor(harness.module.secondaryEditor, harness.module.secondaryEditor.uri);
      layout.openEditor(harness.module.mainEditor, harness.module.mainEditor.uri);
      await tester.pump();

      final searchField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Search',
      );
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'alpha');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.textContaining('matches in'), findsOneWidget);

      final firstLineNumber = find.byWidgetPredicate(
        (w) => w is Text && (w.data?.startsWith('1:') ?? false),
      );
      expect(firstLineNumber, findsAtLeast(1));
      await tester.tap(firstLineNumber.first);
      await tester.pump();

      expect(systemState.activeEditor, same(harness.module.secondaryEditor));
    });

    testWidgets('07: Search toggles case, word, and regex behaviors', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseZHarness.create(includeSearch: true);

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final searchField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Search',
      );

      await tester.enterText(searchField, 'shell');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.textContaining('3 matches in 1 files'), findsOneWidget);

      final caseToggle = tester.widget<InkWell>(find.byKey(_caseToggleKey).first);
      caseToggle.onTap?.call();
      await tester.pumpAndSettle();
      expect(find.textContaining('2 matches in 1 files'), findsOneWidget);

      final wordToggle = tester.widget<InkWell>(find.byKey(_wordToggleKey).first);
      wordToggle.onTap?.call();
      await tester.pumpAndSettle();
      expect(find.textContaining('1 matches in 1 files'), findsOneWidget);

      wordToggle.onTap?.call();

      await tester.enterText(searchField, 's.*s');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('No results found'), findsOneWidget);

      final regexToggle = tester.widget<InkWell>(find.byKey(_regexToggleKey).first);
      regexToggle.onTap?.call();
      await tester.pumpAndSettle();

      expect(find.textContaining('1 matches in 1 files'), findsOneWidget);
    });

    testWidgets('08: Search stop button cancels in-progress stream', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final slowManager = _SlowCancelableSearchManager();
      addTearDown(slowManager.dispose);
      final harness = _PhaseZHarness.create(
        includeSearch: true,
        searchManagerOverride: slowManager,
      );

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final searchField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Search',
      );
      await tester.enterText(searchField, 'never-finishes');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byKey(_stopSearchKey), findsOneWidget);

      final stopButton = tester.widget<IconButton>(find.byKey(_stopSearchKey).first);
      stopButton.onPressed?.call();
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(slowManager.wasCancelled, isTrue);
    });

    testWidgets('09: LRU eviction keeps dirty and active editors', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseZHarness.create(maxOpenEditors: 3);
      final layout = harness.shell.layout as DefaultLayoutController;
      final systemState = harness.shell.systemState as DefaultSystemState;

      layout.openEditor(harness.module.mainEditor, harness.module.mainEditor.uri);
      layout.openEditor(harness.module.secondaryEditor, harness.module.secondaryEditor.uri);
      layout.openEditor(harness.module.tertiaryEditor, harness.module.tertiaryEditor.uri);
      await tester.pump();

      harness.module.mainEditor.insertText('dirty-main');
      await tester.pump();
      expect(harness.module.mainEditor.isDirty.value, isTrue);

      layout.openEditor(harness.module.fourthEditor, harness.module.fourthEditor.uri);
      await tester.pump();

      expect(systemState.openEditors.length, equals(3));
      expect(systemState.openEditors, contains(harness.module.mainEditor));
      expect(systemState.openEditors, contains(harness.module.tertiaryEditor));
      expect(systemState.openEditors, contains(harness.module.fourthEditor));
      expect(systemState.openEditors, isNot(contains(harness.module.secondaryEditor)));

      layout.openEditor(harness.module.fifthEditor, harness.module.fifthEditor.uri);
      await tester.pump();

      expect(systemState.openEditors.length, equals(3));
      expect(systemState.openEditors, contains(harness.module.mainEditor));
      expect(systemState.openEditors, contains(harness.module.fourthEditor));
      expect(systemState.openEditors, contains(harness.module.fifthEditor));
      expect(systemState.openEditors, isNot(contains(harness.module.tertiaryEditor)));
    });

    test('10: Resource monitor aggregates budget thresholds and events', () async {
      final monitor = ForgeResourceMonitor();
      final cacheBudget = ForgeResourceBudget(name: 'search-cache', budget: 100);
      final editorBudget = ForgeResourceBudget(name: 'open-editors', budget: 5);
      monitor.register(cacheBudget);
      monitor.register(editorBudget);

      final events = <ForgeResourceEvent>[];
      final sub = monitor.onEvent.listen(events.add);
      addTearDown(sub.cancel);
      addTearDown(monitor.dispose);

      cacheBudget.allocate(81);
      editorBudget.allocate(2);
      cacheBudget.allocate(30);
      cacheBudget.release(20);

      await Future<void>.delayed(Duration.zero);

      expect(cacheBudget.isHighUsage, isTrue);
      expect(cacheBudget.isOverBudget, isFalse);
      expect(cacheBudget.utilizationRatio, closeTo(0.91, 0.0001));
      expect(monitor.getBudget('open-editors'), same(editorBudget));

      final snapshot = monitor.utilizationSnapshot;
      expect(snapshot['search-cache'], closeTo(0.91, 0.0001));
      expect(snapshot['open-editors'], closeTo(0.4, 0.0001));

      expect(
        events.any(
          (e) =>
              e.budget.name == 'search-cache' &&
              e.type == ForgeResourceEventType.highUsage,
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.budget.name == 'search-cache' &&
              e.type == ForgeResourceEventType.overBudget,
        ),
        isTrue,
      );
    });
  });
}

ForgeTextRange _range([int line = 0]) {
  return ForgeTextRange(
    start: ForgeTextPosition(line: line, column: 0),
    end: ForgeTextPosition(line: line, column: 1),
  );
}

Future<void> _activateProblemsToggle(WidgetTester tester, String label) async {
  final finder = find
      .ancestor(of: find.text(label), matching: find.byType(GestureDetector))
      .hitTestable();
  expect(finder, findsAtLeast(1));
  final gesture = tester.widget<GestureDetector>(finder.first);
  gesture.onTap?.call();
  await tester.pump();
}

class _PhaseZHarness {
  _PhaseZHarness._({
    required this.shell,
    required this.module,
    required this.application,
    required this.preferences,
    required this.workspaceRoot,
  });

  final DefaultShellApi shell;
  final _PhaseZModule module;
  final ForgeApplication application;
  final ForgePreferencesService preferences;
  final String workspaceRoot;

  static _PhaseZHarness create({
    bool includeProblems = false,
    bool includeOutline = false,
    bool includeSearch = false,
    ForgeSearchManager? searchManagerOverride,
    int maxOpenEditors = 20,
  }) {
    final workspaceRoot =
        '${Directory.current.path}/test/phase_z_fixture_workspace';
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
        '$workspaceRoot/test-fixtures/main.test':
          'main content without token\n',
        '$workspaceRoot/test-fixtures/secondary.test':
            'alpha line\nbeta alpha\nshell shells SHELL\nHELLO\n',
        '$workspaceRoot/test-fixtures/tertiary.test': 'tertiary content\n',
        '$workspaceRoot/test-fixtures/fourth.test': 'fourth content\n',
        '$workspaceRoot/test-fixtures/fifth.test': 'fifth content\n',
      },
      appName: 'Phase Z Harness',
      navigatorKey: navigatorKey,
      initialConfig: const ForgeConfig(),
      maxOpenEditors: maxOpenEditors,
    );
    (shell.systemState as DefaultSystemState)
        .setWorkspaceRootPath(workspaceRoot);

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);

    final module = _PhaseZModule(workspaceRoot: workspaceRoot);
    module.activate(shell);

    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(shellModule);
    registry.register(module);

    final sectionViews = <ForgeView>[];
    final leftTabs = <PanelTabConfig>[];
    final rightTabs = <PanelTabConfig>[];
    final bottomTabs = <PanelTabConfig>[];

    if (includeSearch) {
      final searchView = ForgeSearchView(
        searchManager: searchManagerOverride ?? shell.search,
        layoutController: shell.layout,
        systemState: shell.systemState as DefaultSystemState,
        workspaceRoot: workspaceRoot,
      );
      sectionViews.add(searchView);
      leftTabs.add(
        PanelTabConfig(
          title: 'Search',
          icon: Icons.search,
          sections: [searchView],
        ),
      );
    } else {
      final explorer = _StubView('Explorer', Icons.folder);
      sectionViews.add(explorer);
      leftTabs.add(
        PanelTabConfig(
          title: 'Explorer',
          icon: Icons.folder,
          sections: [explorer],
        ),
      );
    }

    if (includeOutline) {
      final outlineView = ForgeOutlineView(
        outlineManager: shell.outline as DefaultOutlineManager,
        systemState: shell.systemState,
      );
      sectionViews.add(outlineView);
      rightTabs.add(
        PanelTabConfig(
          title: 'Outline',
          icon: Icons.account_tree,
          sections: [outlineView],
        ),
      );
    }

    if (includeProblems) {
      final problemsView = ForgeProblemsView(
        diagnosticManager: shell.diagnostics,
        layoutController: shell.layout,
      );
      sectionViews.add(problemsView);
      bottomTabs.add(
        PanelTabConfig(
          title: 'Problems',
          icon: Icons.error_outline,
          sections: [problemsView],
        ),
      );
    }

    final application = ForgeApplication(
      id: 'phase-z-full',
      title: 'Phase Z Full',
      layout: PanelLayout(
        leftPanel: PanelConfig(
          initialSize: 300,
          tabs: leftTabs,
        ),
        rightPanel: PanelConfig(
          initialSize: 260,
          tabs: rightTabs,
        ),
        bottomPanel: PanelConfig(
          initialSize: 220,
          tabs: bottomTabs,
        ),
        middlePanels: const [MiddlePanelConfig()],
      ),
    );
    shell.applications.add(application);

    final systemState = shell.systemState as DefaultSystemState;
    systemState.activate(application.id);
    systemState.setFocusedPanelLocation(ForgePanelLocation.middle);

    final layout = shell.layout as DefaultLayoutController;
    layout.openEditor(
      module.mainEditor,
      module.mainEditor.uri,
      middlePanelIndex: 0,
    );

    final preferences = ForgePreferencesService();

    return _PhaseZHarness._(
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
            notificationManager:
                shell.notifications as DefaultNotificationManager,
            preferencesService: preferences,
          ),
        ),
      ),
    );
  }
}

class _PhaseZModule extends ForgeModule {
  _PhaseZModule({required String workspaceRoot}) {
    mainEditor = _PhaseZEditor(
      this,
      uri: Uri.file('$workspaceRoot/test-fixtures/main.test'),
      title: 'Main Test',
      content: 'main content\n',
    );
    secondaryEditor = _PhaseZEditor(
      this,
      uri: Uri.file('$workspaceRoot/test-fixtures/secondary.test'),
      title: 'Secondary',
      content: 'secondary content\n',
    );
    tertiaryEditor = _PhaseZEditor(
      this,
      uri: Uri.file('$workspaceRoot/test-fixtures/tertiary.test'),
      title: 'Tertiary',
      content: 'tertiary content\n',
    );
    fourthEditor = _PhaseZEditor(
      this,
      uri: Uri.file('$workspaceRoot/test-fixtures/fourth.test'),
      title: 'Fourth',
      content: 'fourth content\n',
    );
    fifthEditor = _PhaseZEditor(
      this,
      uri: Uri.file('$workspaceRoot/test-fixtures/fifth.test'),
      title: 'Fifth',
      content: 'fifth content\n',
    );
  }

  late final _PhaseZEditor mainEditor;
  late final _PhaseZEditor secondaryEditor;
  late final _PhaseZEditor tertiaryEditor;
  late final _PhaseZEditor fourthEditor;
  late final _PhaseZEditor fifthEditor;

  @override
  String get displayName => 'Phase Z Module';

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => [
        mainEditor,
        secondaryEditor,
        tertiaryEditor,
        fourthEditor,
        fifthEditor,
      ];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  List<StatusBarItem> get statusBarItems => const [];
}

class _PhaseZEditor extends ForgeTestTextEditor {
  _PhaseZEditor(
    super.module, {
    required Uri uri,
    required String title,
    required String content,
  })  : _uri = uri,
        _title = ValueNotifier(title),
        super(
          document: ForgeTestDocument(uri: uri, content: content),
        );

  final Uri _uri;
  final ValueNotifier<String> _title;

  @override
  ValueListenable<String> get title => _title;

  @override
  Uri get uri => _uri;

  @override
  IconData get icon => Icons.description;

  @override
  FileHandlingResult canHandle(Uri uri) {
    return uri == _uri ? FileHandlingResult.accept : FileHandlingResult.reject;
  }

  @override
  String? getContent() => document.text;

  @override
  Widget buildMain(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: Center(child: Text(title.value)),
    );
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

class _MutableOutlineProvider implements ForgeOutlineProvider {
  final Map<Uri, List<ForgeOutlineItem>> _itemsByUri =
      <Uri, List<ForgeOutlineItem>>{};
  final StreamController<void> _changeController =
      StreamController<void>.broadcast();

  @override
  bool canProvide(ForgeEditor editor) => true;

  @override
  Future<List<ForgeOutlineItem>> provideOutline(ForgeEditor editor) async {
    return _itemsByUri[editor.uri] ?? const <ForgeOutlineItem>[];
  }

  @override
  Stream<void> get onDidChange => _changeController.stream;

  void setItems(Uri uri, List<ForgeOutlineItem> items, {bool notify = true}) {
    _itemsByUri[uri] = items;
    if (notify) {
      _changeController.add(null);
    }
  }

  void dispose() {
    _changeController.close();
  }
}

class _SlowCancelableSearchManager implements ForgeSearchManager {
  bool wasCancelled = false;
  StreamController<ForgeSearchResult>? _controller;

  @override
  Future<List<ForgeSearchResult>> search(
    String query, {
    bool isRegExp = false,
    bool isCaseSensitive = false,
    bool isWordMatch = false,
    String? includePattern,
    String? excludePattern,
    int? maxResults,
  }) async {
    return const <ForgeSearchResult>[];
  }

  @override
  Stream<ForgeSearchResult> searchStream(
    String query, {
    bool isRegExp = false,
    bool isCaseSensitive = false,
    bool isWordMatch = false,
    String? includePattern,
    String? excludePattern,
  }) {
    _controller = StreamController<ForgeSearchResult>(
      onCancel: () {
        wasCancelled = true;
      },
    );
    return _controller!.stream;
  }

  Future<void> dispose() async {
    final controller = _controller;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
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

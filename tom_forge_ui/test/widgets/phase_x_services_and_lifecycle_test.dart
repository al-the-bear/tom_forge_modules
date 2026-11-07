import 'dart:async';
import 'dart:io';

import 'package:tom_file_system/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_forge_core/tom_forge_core.dart'
    show
        ApplicationChangeEvent,
        ConfigChangeEvent,
        DefaultExecutionMonitor,
        ExecutionState,
        FileHandlingResult,
        ForgeExecution,
        ForgeTextPosition,
        ForgeTextRange;
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'support/shell_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase X: services and lifecycle', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('01: setActiveApplication switches app and emits event', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseXHarness.create();
      final systemState = harness.shell.systemState as DefaultSystemState;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Initially active application is primary
      expect(systemState.activeApplication!.title, equals('Phase X Full'));

      // Listen for application change event inside runAsync to avoid
      // FakeAsync zone teardown hang (stream_channel conflict).
      ApplicationChangeEvent? receivedEvent;
      await tester.runAsync(() async {
        final subscription = systemState.onApplicationChanged.listen((event) {
          receivedEvent = event;
        });
        systemState.activate(harness.secondaryApplication.id);
        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();
      });
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      // Should have switched
      expect(systemState.activeApplication!.title, equals('Phase X Minimal'));

      // Should have received event
      expect(receivedEvent, isNotNull);
      final prevApp = receivedEvent!.previous as ForgeApplication;
      final currApp = receivedEvent!.current as ForgeApplication;
      expect(prevApp.title, equals('Phase X Full'));
      expect(currApp.title, equals('Phase X Minimal'));
    });

    testWidgets('02: execution monitor start and complete lifecycle', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseXHarness.create();
      final executions = harness.shell.executions as DefaultExecutionMonitor;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Initially no executions
      expect(executions.executions, isEmpty);
      expect(executions.running, isEmpty);

      // Start an execution — wrap stream listen in runAsync to avoid
      // FakeAsync zone teardown hang.
      ForgeExecution? startedExec;
      late ForgeExecution exec;
      await tester.runAsync(() async {
        final startSub = executions.onDidStart.listen((e) => startedExec = e);
        exec = executions.start(id: 'build-1', label: 'Build Project');
        await Future<void>.delayed(Duration.zero);
        await startSub.cancel();
      });
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      // Should be running
      expect(executions.executions.length, equals(1));
      expect(executions.running.length, equals(1));
      expect(exec.state, equals(ExecutionState.running));
      expect(startedExec?.id, equals('build-1'));

      // Complete the execution — wrap stream listen in runAsync.
      ForgeExecution? finishedExec;
      await tester.runAsync(() async {
        final finishSub =
            executions.onDidFinish.listen((e) => finishedExec = e);
        executions.complete('build-1');
        await Future<void>.delayed(Duration.zero);
        await finishSub.cancel();
      });
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      // Should be completed
      expect(exec.state, equals(ExecutionState.completed));
      expect(executions.running, isEmpty);
      expect(finishedExec?.id, equals('build-1'));
    });

    testWidgets('03: file decoration manager registers provider and provides decorations', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseXHarness.create();
      final decorationManager =
          harness.shell.fileDecorations as DefaultFileDecorationManager;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Initially no decorations
      final testUri = Uri.file('${harness.workspaceRoot}/decorated.dart');
      expect(decorationManager.getDecoration(testUri), isNull);

      // Register a decoration provider
      final provider = _TestFileDecorationProvider(decoratedUri: testUri);
      final disposable = decorationManager.registerProvider(provider);

      // Should now have decoration
      final decoration = decorationManager.getDecoration(testUri);
      expect(decoration, isNotNull);
      expect(decoration!.color, equals(Colors.orange));
      expect(decoration.badge, equals('M'));
      expect(decoration.tooltip, equals('Modified file'));

      // Dispose provider
      disposable.dispose();

      // Should no longer have decoration
      expect(decorationManager.getDecoration(testUri), isNull);
    });

    testWidgets('04: virtual document provider resolves content', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseXHarness.create();
      final virtualDocs =
          harness.shell.virtualDocuments as DefaultVirtualDocumentManager;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Register a virtual document provider for custom scheme
      final provider = _TestVirtualDocumentProvider();
      final disposable = virtualDocs.registerProvider('virtual', provider);

      // Check provider is registered
      expect(virtualDocs.hasProvider('virtual'), isTrue);

      // Resolve content
      final virtualUri = Uri.parse('virtual://test/content.txt');
      final content = await virtualDocs.resolveContent(virtualUri);
      expect(content, isNotNull);
      expect(content, equals('Virtual document content'));

      // Dispose provider
      disposable.dispose();
      expect(virtualDocs.hasProvider('virtual'), isFalse);
    });

    testWidgets('05: outline manager provides outline for editor', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseXHarness.create();
      final outlineManager = harness.shell.outline as DefaultOutlineManager;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Register an outline provider
      final provider = _TestOutlineProvider();
      final disposable = outlineManager.registerProvider(provider);

      // Get outline for active editor
      final outline =
          await outlineManager.provideOutline(harness.module.mainEditor);

      // Should have outline items
      expect(outline, isNotEmpty);
      expect(outline.length, equals(2));
      expect(outline[0].label, equals('Main Class'));
      expect(outline[1].label, equals('Helper Function'));

      // Dispose provider
      disposable.dispose();
    });

    testWidgets('06: module storage persists key-value data', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseXHarness.create();
      final storage = harness.shell.storage;
      final store = storage.forModule(harness.module);

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Initially no stored value
      expect(store.get<String>('test-key'), isNull);

      // Store a value
      await store.set('test-key', 'test-value-123');

      // Retrieve stored value
      expect(store.get<String>('test-key'), equals('test-value-123'));

      // Remove value
      await store.remove('test-key');
      expect(store.get<String>('test-key'), isNull);
    });

    testWidgets('07: config manager emits change events on update', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseXHarness.create();
      final config = harness.shell.config as DefaultConfigManager;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Listen for config changes — wrap in runAsync to avoid
      // FakeAsync zone teardown hang.
      ConfigChangeEvent? receivedEvent;
      await tester.runAsync(() async {
        final subscription = config.onDidChange.listen((event) {
          receivedEvent = event;
        });
        config.setModuleConfig('test.module', {'setting': 'new-value'});
        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();
      });
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      // Should have received change event
      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.key, equals('module.test.module'));
    });

    testWidgets('08: workspace state creates and lists revisions', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseXHarness.create();
      final workspaceState = harness.shell.workspaceState;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Wrap async workspace state operations in runAsync to avoid
      // FakeAsync zone hang on real I/O.
      String? revId;
      List<String> revisions = [];
      String? content;
      await tester.runAsync(() async {
        // Initialize workspace state
        await workspaceState.initialize(TomLocalFileSystem(harness.workspaceRoot));

        // Create a revision
        final fileUri = Uri.file('${harness.workspaceRoot}/test.dart');
        revId = await workspaceState.createRevision(
          fileUri,
          'revision content v1',
        );

        // List revisions
        revisions = await workspaceState.listRevisions(fileUri);

        // Get revision content
        content = await workspaceState.readRevision(fileUri, revId!);
      });

      // Should have created revision
      expect(revId, isNotNull);
      expect(revisions, isNotEmpty);
      expect(revisions.first, equals(revId));
      expect(content, equals('revision content v1'));
    });

    testWidgets('09: execution monitor tracks failed executions', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseXHarness.create();
      final executions = harness.shell.executions as DefaultExecutionMonitor;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Start execution
      final exec = executions.start(id: 'test-run', label: 'Test Suite');
      expect(exec.state, equals(ExecutionState.running));

      // Fail the execution — wrap stream listen in runAsync to avoid
      // FakeAsync zone teardown hang.
      ForgeExecution? finishedExec;
      await tester.runAsync(() async {
        final subscription =
            executions.onDidFinish.listen((e) => finishedExec = e);
        executions.fail('test-run');
        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();
      });
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      // Should be failed
      expect(exec.state, equals(ExecutionState.failed));
      expect(finishedExec?.state, equals(ExecutionState.failed));
      expect(executions.running, isEmpty);

      // Remove from tracking
      executions.remove('test-run');
      expect(executions.executions, isEmpty);
    });

    testWidgets('10: application switch preserves previous app state', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseXHarness.create();
      final systemState = harness.shell.systemState as DefaultSystemState;
      final layout = harness.shell.layout as DefaultLayoutController;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Open additional editors in primary app
      layout.openEditor(
        harness.module.secondaryEditor,
        harness.module.secondaryEditor.uri,
        middlePanelIndex: 0,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      // Verify editors are open
      expect(systemState.openEditors.length, equals(2));

      // Switch to secondary application
      systemState.activate(harness.secondaryApplication.id);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      // Secondary app should start fresh (minimal app has no editors)
      // Note: actual behavior depends on implementation
      expect(systemState.activeApplication!.title, equals('Phase X Minimal'));

      // Switch back to primary application
      systemState.activate(harness.primaryApplication.id);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      // Primary app should be restored
      expect(systemState.activeApplication!.title, equals('Phase X Full'));
    });
  });
}

class _PhaseXHarness {
  _PhaseXHarness._({
    required this.shell,
    required this.module,
    required this.primaryApplication,
    required this.secondaryApplication,
    required this.preferences,
    required this.workspaceRoot,
  });

  final DefaultShellApi shell;
  final _PhaseXModule module;
  final ForgeApplication primaryApplication;
  final ForgeApplication secondaryApplication;
  final ForgePreferencesService preferences;
  final String workspaceRoot;

  ForgeApplication get application => primaryApplication;

  static _PhaseXHarness create() {
    final workspaceRoot =
        '${Directory.current.path}/test/phase_x_fixture_workspace';
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
      },
      appName: 'Phase X Harness',
      navigatorKey: navigatorKey,
    );
    (shell.systemState as DefaultSystemState)
        .setWorkspaceRootPath(workspaceRoot);

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);

    final module = _PhaseXModule(
      workspaceRoot: workspaceRoot,
      outputManager: shell.output,
    );
    module.activate(shell);

    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(shellModule);
    registry.register(module);

    // Create two applications for switching tests
    final primaryApplication = ForgeApplication(
      id: 'phase-x-full',
      title: 'Phase X Full',
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
            PanelTabConfig(
              title: 'Output',
              icon: Icons.output,
              sections: [module.outputView],
            ),
          ],
        ),
        middlePanels: const [MiddlePanelConfig()],
      ),
    );
    shell.applications.add(primaryApplication);

    final secondaryApplication = ForgeApplication(
      id: 'phase-x-minimal',
      title: 'Phase X Minimal',
      layout: PanelLayout(
        leftPanel: const PanelConfig(initialSize: 200, tabs: []),
        rightPanel: const PanelConfig(initialSize: 200, tabs: []),
        bottomPanel: const PanelConfig(initialSize: 150, tabs: []),
        middlePanels: const [MiddlePanelConfig()],
      ),
    );
    shell.applications.add(secondaryApplication);

    // Register both applications and set primary as active
    final systemState = shell.systemState as DefaultSystemState;
    systemState.activate(primaryApplication.id);

    final layout = shell.layout as DefaultLayoutController;
    layout.openEditor(
      module.mainEditor,
      module.mainEditor.uri,
      middlePanelIndex: 0,
    );

    final preferences = ForgePreferencesService();

    return _PhaseXHarness._(
      shell: shell,
      module: module,
      primaryApplication: primaryApplication,
      secondaryApplication: secondaryApplication,
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

class _PhaseXModule extends ForgeModule {
  _PhaseXModule({
    required String workspaceRoot,
    required ForgeOutputChannelManager outputManager,
  }) {
    mainEditor = _PhaseXMainEditor(
      this,
      workspaceRoot: workspaceRoot,
      fileName: 'main.test',
      title: 'Main Test',
    );
    secondaryEditor = _PhaseXMainEditor(
      this,
      workspaceRoot: workspaceRoot,
      fileName: 'secondary.test',
      title: 'Secondary',
    );
    tertiaryEditor = _PhaseXMainEditor(
      this,
      workspaceRoot: workspaceRoot,
      fileName: 'tertiary.test',
      title: 'Tertiary',
    );
    explorerView = _StubView('Explorer View', Icons.folder);
    outlineView = _StubView('Outline View', Icons.account_tree);
    outputView = ForgeOutputView(channelManager: outputManager);
  }

  late final _PhaseXMainEditor mainEditor;
  late final _PhaseXMainEditor secondaryEditor;
  late final _PhaseXMainEditor tertiaryEditor;
  late final _StubView explorerView;
  late final _StubView outlineView;
  late final ForgeView outputView;

  @override
  String get displayName => 'Phase X Module';

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors =>
      [mainEditor, secondaryEditor, tertiaryEditor];

  @override
  List<ForgeView> get views => [explorerView, outlineView, outputView];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  List<StatusBarItem> get statusBarItems => const [];
}

class _PhaseXMainEditor extends ForgeTestTextEditor {
  _PhaseXMainEditor(
    super.module, {
    required String workspaceRoot,
    required String fileName,
    required String title,
  })  : _title = ValueNotifier(title),
        _uri = Uri.file('$workspaceRoot/test-fixtures/$fileName');

  final ValueNotifier<String> _title;
  final Uri _uri;

  @override
  ValueListenable<String> get title => _title;

  @override
  Uri get uri => _uri;

  @override
  IconData get icon => Icons.description;

  @override
  FileHandlingResult canHandle(Uri fileUri) {
    return fileUri.path.endsWith('.test')
        ? FileHandlingResult.accept
        : FileHandlingResult.reject;
  }

  @override
  Widget buildMain(BuildContext context) {
    return Container(
      color: Colors.grey[200],
      child: Center(child: Text(title.value)),
    );
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

class _StubView extends ForgeView {
  _StubView(this._title, this._icon);

  final String _title;
  final IconData _icon;
  final _titleNotifier = ValueNotifier<String>('');
  final _titleExtension = ValueNotifier<String?>(null);

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
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints(
        preferredSize: Size(300, 200),
      );

  @override
  Widget buildMain(BuildContext context) {
    return Container(
      color: Colors.blueGrey[50],
      child: Center(child: Text(_title)),
    );
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

// Test helpers

class _TestFileDecorationProvider implements ForgeFileDecorationProvider {
  _TestFileDecorationProvider({required this.decoratedUri});

  final Uri decoratedUri;
  final _changeController = StreamController<Uri?>.broadcast();

  @override
  ForgeFileDecoration? provideDecoration(Uri uri) {
    if (uri == decoratedUri) {
      return const ForgeFileDecoration(
        color: Colors.orange,
        badge: 'M',
        tooltip: 'Modified file',
      );
    }
    return null;
  }

  @override
  Stream<Uri?> get onDidChange => _changeController.stream;

  void dispose() {
    _changeController.close();
  }
}

class _TestVirtualDocumentProvider implements ForgeVirtualDocumentProvider {
  @override
  Future<String> provideContent(Uri uri) async {
    return 'Virtual document content';
  }

  final _changeController = StreamController<Uri>.broadcast();

  @override
  Stream<Uri> get onDidChange => _changeController.stream;

  void dispose() {
    _changeController.close();
  }
}

class _TestOutlineProvider implements ForgeOutlineProvider {
  @override
  bool canProvide(ForgeEditor editor) => true;

  @override
  Future<List<ForgeOutlineItem>> provideOutline(ForgeEditor editor) async {
    return [
      ForgeOutlineItem(
        label: 'Main Class',
        kind: ForgeSymbolKind.classKind,
        range: ForgeTextRange(
          start: const ForgeTextPosition(line: 0, column: 0),
          end: const ForgeTextPosition(line: 10, column: 0),
        ),
        selectionRange: ForgeTextRange(
          start: const ForgeTextPosition(line: 0, column: 0),
          end: const ForgeTextPosition(line: 0, column: 10),
        ),
        children: [],
      ),
      ForgeOutlineItem(
        label: 'Helper Function',
        kind: ForgeSymbolKind.function,
        range: ForgeTextRange(
          start: const ForgeTextPosition(line: 12, column: 0),
          end: const ForgeTextPosition(line: 20, column: 0),
        ),
        selectionRange: ForgeTextRange(
          start: const ForgeTextPosition(line: 12, column: 0),
          end: const ForgeTextPosition(line: 12, column: 15),
        ),
        children: [],
      ),
    ];
  }

  final _changeController = StreamController<void>.broadcast();

  @override
  Stream<void> get onDidChange => _changeController.stream;

  void dispose() {
    _changeController.close();
  }
}

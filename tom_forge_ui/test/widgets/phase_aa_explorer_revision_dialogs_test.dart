import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'support/shell_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase AA: explorer, revisions, and dialog overlays', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('01: explorer renders root directory entries', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseAAHarness.create();

      final rootEntries = await harness.fileSystem.list(
        Uri.file(harness.workspaceRoot),
      );
      final srcEntry = rootEntries.firstWhere(
        (entry) => entry.name == 'src',
      );
      expect(srcEntry.isDirectory, isTrue);

      await tester.pumpWidget(harness.buildExplorerHost());
      await tester.pumpAndSettle();

      expect(find.text('src'), findsOneWidget);
      expect(find.text('README.md'), findsOneWidget);
    });

    testWidgets('02: explorer double-click opens file in editor', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseAAHarness.create();
      final systemState = harness.shell.systemState as DefaultSystemState;

      await tester.pumpWidget(harness.buildExplorerHost());
      await tester.pumpAndSettle();

      systemState.setSelectedExplorerItems([
        Uri.file('${harness.workspaceRoot}/src/main.dart'),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('main.dart'));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.text('main.dart'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 200));

      final active = systemState.activeEditor;
      expect(active, isNotNull);
      expect(active!.uri.path, contains('/src/main.dart'));
    });

    testWidgets('03: explorer reveal expands parent directories from system state selection', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseAAHarness.create();
      final systemState = harness.shell.systemState as DefaultSystemState;

      await tester.pumpWidget(harness.buildExplorerHost());
      await tester.pumpAndSettle();

      expect(find.text('deep.txt'), findsNothing);

      systemState.setSelectedExplorerItems([
        Uri.file('${harness.workspaceRoot}/src/nested/deep.txt'),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('nested'), findsOneWidget);
      expect(find.text('deep.txt'), findsOneWidget);
    });

    testWidgets('04: explorer displays decoration badge from provider', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseAAHarness.create();
      final decorationManager =
          harness.shell.fileDecorations as DefaultFileDecorationManager;
      final targetUri = Uri.file('${harness.workspaceRoot}/README.md');
      final provider = _StaticDecorationProvider(
        targetUri: targetUri,
        decoration: const ForgeFileDecoration(
          badge: 'M',
          tooltip: 'Modified file',
          color: Colors.orange,
        ),
      );
      final disposable = decorationManager.registerProvider(provider);
      addTearDown(disposable.dispose);
      addTearDown(provider.dispose);

      await tester.pumpWidget(harness.buildExplorerHost());
      await tester.pumpAndSettle();

      expect(find.text('M'), findsOneWidget);
      expect(find.byTooltip('Modified file'), findsOneWidget);
    });

    testWidgets('05: explorer context menu New File creates and opens file', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseAAHarness.create();
      final systemState = harness.shell.systemState as DefaultSystemState;

      await tester.pumpWidget(harness.buildExplorerHost());
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          ValueKey<String>('forge-explorer-entry:${harness.workspaceRoot}/src'),
        ),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('New File...'));
      await tester.pump();

      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'filename.dart',
      );
      expect(field, findsOneWidget);
      await tester.enterText(field, 'created.dart');
      await tester.tap(find.widgetWithText(TextButton, 'Create'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      final createdUri = Uri.file('${harness.workspaceRoot}/src/created.dart');
      expect(await harness.fileSystem.exists(createdUri), isTrue);

      await tester.tap(
        find.byKey(
          ValueKey<String>('forge-explorer-entry:${harness.workspaceRoot}/src'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('created.dart'), findsOneWidget);
      expect(systemState.activeEditor?.uri.path, contains('/src/created.dart'));
    });

    testWidgets('06: explorer context menu Rename renames file on disk', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseAAHarness.create();

      await tester.pumpWidget(harness.buildExplorerHost());
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          ValueKey<String>('forge-explorer-entry:${harness.workspaceRoot}/README.md'),
        ),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rename...'));
      await tester.pump();

      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'New name',
      );
      expect(field, findsOneWidget);
      await tester.enterText(field, 'GUIDE.md');
      await tester.tap(find.widgetWithText(TextButton, 'Rename'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.text('README.md'), findsNothing);
      expect(find.text('GUIDE.md'), findsOneWidget);
      expect(await harness.fileSystem.exists(Uri.file('${harness.workspaceRoot}/README.md')), isFalse);
      expect(await harness.fileSystem.exists(Uri.file('${harness.workspaceRoot}/GUIDE.md')), isTrue);
    });

    testWidgets('07: revision view refreshes when save event arrives', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseAAHarness.create();
      final workspaceState = harness.shell.workspaceState;
      final fileUri = Uri.file('${harness.workspaceRoot}/src/main.dart');

      await tester.pumpWidget(harness.buildRevisionHost());
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await workspaceState.initialize(harness.workspaceRoot);
        harness.shell.layout.openFile(fileUri);
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();

      expect(find.text('No revisions'), findsOneWidget);

      await tester.runAsync(() async {
        await workspaceState.createRevision(fileUri, 'revision-v1');
        await harness.fileSystem.save(fileUri);
      });
      await tester.pumpAndSettle();

      expect(find.text('No revisions'), findsNothing);
      expect(find.byIcon(Icons.restore), findsAtLeastNWidgets(1));
    });

    testWidgets('08: tapping revision opens revision URI editor', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseAAHarness.create();
      final workspaceState = harness.shell.workspaceState;
      final systemState = harness.shell.systemState as DefaultSystemState;
      final fileUri = Uri.file('${harness.workspaceRoot}/src/main.dart');

      late String revisionId;

      await tester.pumpWidget(harness.buildRevisionHost());
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await workspaceState.initialize(harness.workspaceRoot);
        revisionId =
            (await workspaceState.createRevision(fileUri, 'snap-1'))!;
        harness.shell.layout.openFile(fileUri);
        await harness.fileSystem.save(fileUri);
      });
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.restore).first);
      await tester.pumpAndSettle();

      final active = systemState.activeEditor;
      expect(active, isNotNull);
      expect(active!.uri.queryParameters['revision'], equals(revisionId));
    });

    testWidgets('09: revision restore button replaces file content', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseAAHarness.create();
      final workspaceState = harness.shell.workspaceState;
      final fileUri = Uri.file('${harness.workspaceRoot}/src/main.dart');

      await tester.pumpWidget(harness.buildRevisionHost());
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await workspaceState.initialize(harness.workspaceRoot);
        await workspaceState.createRevision(fileUri, 'restorable-content');
        await harness.fileSystem.writeText(fileUri, 'new-content');
        harness.shell.layout.openFile(fileUri);
        await harness.fileSystem.save(fileUri);
      });
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Replace current file with this revision').first);
      await tester.pumpAndSettle();

      String? content;
      await tester.runAsync(() async {
        content = await harness.fileSystem.readText(fileUri);
      });

      expect(content, equals('restorable-content'));
    });

    testWidgets('10: quick-pick and input-box keyboard flows work end-to-end', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);

      final quickPickCompleter = Completer<String?>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgeQuickPickOverlay<String>(
              items: const [
                ForgeQuickPickItem<String>(label: 'Alpha', value: 'A'),
                ForgeQuickPickItem<String>(label: 'Beta', value: 'B'),
              ],
              placeholder: 'Pick one',
              completer: quickPickCompleter,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Pick one',
      );
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'beta');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(await quickPickCompleter.future, equals('B'));

      final inputCompleter = Completer<String?>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgeInputBoxOverlay(
              prompt: 'Enter value',
              placeholder: 'min 3 chars',
              validateInput: (value) {
                if (value.trim().length < 3) return 'Too short';
                return null;
              },
              completer: inputCompleter,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final inputField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'min 3 chars',
      );
      expect(inputField, findsOneWidget);

      await tester.enterText(inputField, 'ab');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(find.text('Too short'), findsOneWidget);
      expect(inputCompleter.isCompleted, isFalse);

      await tester.enterText(inputField, 'abcd');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(await inputCompleter.future, equals('abcd'));
    });
  });
}

class _PhaseAAHarness {
  _PhaseAAHarness._({
    required this.shell,
    required this.workspaceRoot,
    required this.fileSystem,
    required this.explorerView,
    required this.revisionView,
  });

  final DefaultShellApi shell;
  final String workspaceRoot;
  final ForgeMemoryFileSystem fileSystem;
  final ForgeFileExplorerView explorerView;
  final ForgeRevisionView revisionView;

  static _PhaseAAHarness create() {
    final workspaceRoot =
        '${Directory.current.path}/test/phase_aa_fixture_workspace';
    final workspaceDir = Directory(workspaceRoot);
    if (workspaceDir.existsSync()) {
      workspaceDir.deleteSync(recursive: true);
    }
    workspaceDir.createSync(recursive: true);

    final navigatorKey = GlobalKey<NavigatorState>();
    final fileSystem = ForgeMemoryFileSystem(
      seed: {
        '$workspaceRoot/README.md': '# Readme\n',
        '$workspaceRoot/src/main.dart': 'void main() { print("hi"); }\n',
        '$workspaceRoot/src/nested/deep.txt': 'deep content\n',
      },
    );
    final workspaceState = _InMemoryWorkspaceStateManager();
    final shell = DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: fileSystem,
      workspaceState: workspaceState,
      appName: 'Phase AA Harness',
      navigatorKey: navigatorKey,
    );

    final systemState = shell.systemState as DefaultSystemState;
    systemState.setWorkspaceRootPath(workspaceRoot);

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);

    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(shellModule);

    final explorerView = ForgeFileExplorerView(
      fileSystem: fileSystem,
      layoutController: shell.layout,
      rootUri: Uri.file(workspaceRoot),
      systemState: systemState,
      fileDecorationManager: shell.fileDecorations as DefaultFileDecorationManager,
    );

    final revisionView = ForgeRevisionView(
      workspaceState: shell.workspaceState,
      systemState: systemState,
      layoutController: shell.layout,
      shellApi: shell,
      onDidSave: fileSystem.onDidSave,
    );

    addTearDown(() async {
      shell.dispose();
      if (workspaceDir.existsSync()) {
        workspaceDir.deleteSync(recursive: true);
      }
    });

    return _PhaseAAHarness._(
      shell: shell,
      workspaceRoot: workspaceRoot,
      fileSystem: fileSystem,
      explorerView: explorerView,
      revisionView: revisionView,
    );
  }

  Widget buildExplorerHost() {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 2200,
          height: 1200,
          child: Builder(
            builder: (context) => explorerView.buildMain(context),
          ),
        ),
      ),
    );
  }

  Widget buildRevisionHost() {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 2200,
          height: 1200,
          child: Builder(
            builder: (context) => revisionView.buildMain(context),
          ),
        ),
      ),
    );
  }
}

class _InMemoryWorkspaceStateManager implements ForgeWorkspaceStateManager {
  bool _initialized = false;
  String _workspaceRoot = '';
  Map<String, dynamic>? _layoutState;
  List<String> _openEditors = const [];
  final Map<String, Map<String, dynamic>> _editorState = {};
  final Map<String, List<_RevisionSnapshot>> _revisions = {};
  final Map<String, List<Map<String, dynamic>>> _undoHistory = {};
  Map<String, dynamic>? _config;
  int _revisionCounter = 0;

  @override
  bool get isInitialized => _initialized;

  @override
  String get forgeDirectoryPath =>
      _workspaceRoot.isEmpty ? '' : '$_workspaceRoot/.forge';

  @override
  Future<bool> initialize(String workspaceRootPath) async {
    final isNew = !_initialized;
    _workspaceRoot = workspaceRootPath;
    _initialized = true;
    return isNew;
  }

  @override
  Future<String?> detectWorkspaceRoot(String startPath) async {
    if (_workspaceRoot.isNotEmpty && startPath.startsWith(_workspaceRoot)) {
      return _workspaceRoot;
    }
    return null;
  }

  @override
  Future<void> saveLayoutState(Map<String, dynamic> layoutData) async {
    _layoutState = Map<String, dynamic>.from(layoutData);
  }

  @override
  Future<Map<String, dynamic>?> loadLayoutState() async {
    if (_layoutState == null) return null;
    return Map<String, dynamic>.from(_layoutState!);
  }

  @override
  Future<void> saveOpenEditors(List<String> editorUris) async {
    _openEditors = List<String>.from(editorUris);
  }

  @override
  Future<List<String>> loadOpenEditors() async {
    return List<String>.from(_openEditors);
  }

  @override
  Future<void> saveEditorState(Uri editorUri, Map<String, dynamic> state) async {
    _editorState[editorUri.toString()] = Map<String, dynamic>.from(state);
  }

  @override
  Future<Map<String, dynamic>?> loadEditorState(Uri editorUri) async {
    final state = _editorState[editorUri.toString()];
    if (state == null) return null;
    return Map<String, dynamic>.from(state);
  }

  @override
  Future<String?> createRevision(Uri fileUri, String content) async {
    final key = _fileKey(fileUri);
    final list = _revisions.putIfAbsent(key, () => <_RevisionSnapshot>[]);
    if (list.isNotEmpty && list.last.content == content) {
      return null;
    }
    _revisionCounter += 1;
    final id = '${DateTime.now().millisecondsSinceEpoch}_$_revisionCounter';
    list.add(_RevisionSnapshot(id: id, content: content));
    return id;
  }

  @override
  Future<List<String>> listRevisions(Uri fileUri) async {
    final list = _revisions[_fileKey(fileUri)] ?? const <_RevisionSnapshot>[];
    return list.reversed.map((r) => r.id).toList(growable: false);
  }

  @override
  Future<String?> readRevision(Uri fileUri, String revisionId) async {
    final list = _revisions[_fileKey(fileUri)] ?? const <_RevisionSnapshot>[];
    for (final revision in list) {
      if (revision.id == revisionId) return revision.content;
    }
    return null;
  }

  @override
  Future<void> deleteRevision(Uri fileUri, String revisionId) async {
    final list = _revisions[_fileKey(fileUri)];
    list?.removeWhere((revision) => revision.id == revisionId);
  }

  @override
  Future<int> pruneRevisions(Uri fileUri, {int maxRevisions = 50}) async {
    final list = _revisions[_fileKey(fileUri)];
    if (list == null || list.length <= maxRevisions) return 0;
    final removed = list.length - maxRevisions;
    list.removeRange(0, removed);
    return removed;
  }

  @override
  Future<void> saveUndoHistory(
    Uri fileUri,
    List<Map<String, dynamic>> entries,
  ) async {
    _undoHistory[_fileKey(fileUri)] = entries
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }

  @override
  Future<List<Map<String, dynamic>>> loadUndoHistory(Uri fileUri) async {
    final entries = _undoHistory[_fileKey(fileUri)] ?? const [];
    return entries
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }

  @override
  Future<void> saveConfig(Map<String, dynamic> configData) async {
    _config = Map<String, dynamic>.from(configData);
  }

  @override
  Future<Map<String, dynamic>?> loadConfig() async {
    if (_config == null) return null;
    return Map<String, dynamic>.from(_config!);
  }

  @override
  Future<bool> isForgeInGitignore(String workspaceRootPath) async => false;

  @override
  Future<bool> suggestGitignore(String workspaceRootPath) async => false;

  @override
  void dispose() {}

  String _fileKey(Uri uri) {
    return uri.replace(queryParameters: const {}, fragment: '').toString();
  }
}

class _RevisionSnapshot {
  const _RevisionSnapshot({required this.id, required this.content});

  final String id;
  final String content;
}

class _StaticDecorationProvider implements ForgeFileDecorationProvider {
  _StaticDecorationProvider({required this.targetUri, required this.decoration});

  final Uri targetUri;
  final ForgeFileDecoration decoration;
  final StreamController<Uri?> _controller =
      StreamController<Uri?>.broadcast();

  @override
  ForgeFileDecoration? provideDecoration(Uri uri) {
    if (uri == targetUri) return decoration;
    return null;
  }

  @override
  Stream<Uri?> get onDidChange => _controller.stream;

  void dispose() {
    _controller.close();
  }
}

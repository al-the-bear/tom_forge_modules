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

    testWidgets('01: explorer expands and collapses a directory on click', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseAAHarness.create();

      await tester.pumpWidget(harness.buildExplorerHost());
      await tester.pumpAndSettle();

      expect(find.text('nested'), findsNothing);

      await tester.tap(find.text('src'));
      await tester.pumpAndSettle();

      expect(find.text('nested'), findsOneWidget);

      await tester.tap(find.text('src'));
      await tester.pumpAndSettle();

      expect(find.text('nested'), findsNothing);
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

      await tester.tap(find.text('src'));
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
        find.text('src'),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('New File...'));
      await tester.pumpAndSettle();

      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'filename.dart',
      );
      expect(field, findsOneWidget);
      await tester.enterText(field, 'created.dart');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      final createdPath = '${harness.workspaceRoot}/src/created.dart';
      expect(File(createdPath).existsSync(), isTrue);
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
        find.text('README.md'),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rename...'));
      await tester.pumpAndSettle();

      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'New name',
      );
      expect(field, findsOneWidget);
      await tester.enterText(field, 'GUIDE.md');
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      expect(find.text('README.md'), findsNothing);
      expect(find.text('GUIDE.md'), findsOneWidget);
      expect(File('${harness.workspaceRoot}/README.md').existsSync(), isFalse);
      expect(File('${harness.workspaceRoot}/GUIDE.md').existsSync(), isTrue);
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
        await harness.fileSystem.write(fileUri, 'new-content');
        harness.shell.layout.openFile(fileUri);
        await harness.fileSystem.save(fileUri);
      });
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Replace current file with this revision').first);
      await tester.pumpAndSettle();

      String? content;
      await tester.runAsync(() async {
        content = await harness.fileSystem.read(fileUri);
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
  final RealFileSystem fileSystem;
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

    final srcDir = Directory('$workspaceRoot/src');
    final nestedDir = Directory('$workspaceRoot/src/nested');
    srcDir.createSync(recursive: true);
    nestedDir.createSync(recursive: true);

    File('$workspaceRoot/README.md').writeAsStringSync('# Readme\n');
    File('$workspaceRoot/src/main.dart')
        .writeAsStringSync('void main() { print("hi"); }\n');
    File('$workspaceRoot/src/nested/deep.txt')
        .writeAsStringSync('deep content\n');

    final navigatorKey = GlobalKey<NavigatorState>();
    final fileSystem = RealFileSystem(rootDirectory: workspaceDir);
    final shell = DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: fileSystem,
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

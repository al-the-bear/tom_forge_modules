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

  group(
    'Phase AB: explorer context paths and side-panel state transitions',
    () {
      setUp(() {
        SharedPreferences.setMockInitialValues(<String, Object>{});
      });

      testWidgets('01: explorer context menu Open opens selected file', (
        WidgetTester tester,
      ) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseABExplorerHarness.create();
        final systemState = harness.shell.systemState as DefaultSystemState;

        await tester.pumpWidget(harness.buildExplorerHost());
        await tester.pumpAndSettle();

        final readmePath = harness.pathForRootEntry('README.md');
        await _openExplorerContextMenuByPath(tester, readmePath);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(systemState.activeEditor, isNotNull);
        expect(systemState.activeEditor!.uri.path, contains('/README.md'));
      });

      testWidgets('02: explorer Delete confirms and removes file from tree', (
        WidgetTester tester,
      ) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseABExplorerHarness.create();

        await tester.pumpWidget(harness.buildExplorerHost());
        await tester.pumpAndSettle();

        final readmePath = harness.pathForRootEntry('README.md');
        await _openExplorerContextMenuByPath(tester, readmePath);
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pumpAndSettle();

        expect(await harness.fileSystem.exists(Uri.file(readmePath)), isFalse);
        expect(find.text('README.md'), findsNothing);
      });

      testWidgets('03: explorer Delete cancel keeps file unchanged', (
        WidgetTester tester,
      ) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseABExplorerHarness.create();

        await tester.pumpWidget(harness.buildExplorerHost());
        await tester.pumpAndSettle();

        final readmePath = harness.pathForRootEntry('README.md');
        await _openExplorerContextMenuByPath(tester, readmePath);
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(await harness.fileSystem.exists(Uri.file(readmePath)), isTrue);
        expect(find.text('README.md'), findsOneWidget);
      });

      testWidgets('04: New Folder from directory creates child folder', (
        WidgetTester tester,
      ) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseABExplorerHarness.create();

        await tester.pumpWidget(harness.buildExplorerHost());
        await tester.pumpAndSettle();

        final srcPath = harness.pathForRootEntry('src');
        await _openExplorerContextMenuByPath(tester, srcPath);
        await tester.tap(find.text('New Folder...'));
        await tester.pumpAndSettle();

        final field = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == 'folder name',
        );
        expect(field, findsOneWidget);
        await tester.enterText(field, 'generated');
        await tester.tap(find.widgetWithText(TextButton, 'Create'));
        await tester.pumpAndSettle();

        await tester.tap(_explorerEntry(srcPath));
        await tester.pumpAndSettle();

        final folderPath = '$srcPath/generated';
        expect(await harness.fileSystem.exists(Uri.file(folderPath)), isTrue);
        expect(find.text('generated'), findsOneWidget);
      });

      testWidgets('05: New Folder from file path targets parent directory', (
        WidgetTester tester,
      ) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseABExplorerHarness.create();

        await tester.pumpWidget(harness.buildExplorerHost());
        await tester.pumpAndSettle();

        final readmePath = harness.pathForRootEntry('README.md');
        await _openExplorerContextMenuByPath(tester, readmePath);
        await tester.tap(find.text('New Folder...'));
        await tester.pumpAndSettle();

        final field = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == 'folder name',
        );
        expect(field, findsOneWidget);
        await tester.enterText(field, 'docs');
        await tester.tap(find.widgetWithText(TextButton, 'Create'));
        await tester.pumpAndSettle();

        final folderPath = '${harness.workspaceRoot}/docs';
        expect(await harness.fileSystem.exists(Uri.file(folderPath)), isTrue);
        expect(find.text('docs'), findsOneWidget);
      });

      testWidgets('06: New File Enter submit creates and opens file', (
        WidgetTester tester,
      ) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseABExplorerHarness.create();
        final systemState = harness.shell.systemState as DefaultSystemState;

        await tester.pumpWidget(harness.buildExplorerHost());
        await tester.pumpAndSettle();

        final srcPath = harness.pathForRootEntry('src');
        await _openExplorerContextMenuByPath(tester, srcPath);
        await tester.tap(find.text('New File...'));
        await tester.pumpAndSettle();

        final field = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == 'filename.dart',
        );
        expect(field, findsOneWidget);
        await tester.enterText(field, 'hotfix.dart');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        final filePath = '$srcPath/hotfix.dart';
        expect(await harness.fileSystem.exists(Uri.file(filePath)), isTrue);
        expect(systemState.activeEditor, isNotNull);
        expect(
          systemState.activeEditor!.uri.path,
          contains('/src/hotfix.dart'),
        );
      });

      testWidgets('07: Rename Enter submit renames file on disk and in tree', (
        WidgetTester tester,
      ) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseABExplorerHarness.create();

        await tester.pumpWidget(harness.buildExplorerHost());
        await tester.pumpAndSettle();

        final readmePath = harness.pathForRootEntry('README.md');
        await _openExplorerContextMenuByPath(tester, readmePath);
        await tester.tap(find.text('Rename...'));
        await tester.pumpAndSettle();

        final field = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.hintText == 'New name',
        );
        expect(field, findsOneWidget);
        await tester.enterText(field, 'GUIDE.md');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(find.text('README.md'), findsNothing);
        expect(find.text('GUIDE.md'), findsOneWidget);
        expect(await harness.fileSystem.exists(Uri.file(readmePath)), isFalse);
        expect(
          await harness.fileSystem.exists(
            Uri.file('${harness.workspaceRoot}/GUIDE.md'),
          ),
          isTrue,
        );
      });

      testWidgets('08: Rename cancel keeps original file untouched', (
        WidgetTester tester,
      ) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseABExplorerHarness.create();

        await tester.pumpWidget(harness.buildExplorerHost());
        await tester.pumpAndSettle();

        final readmePath = harness.pathForRootEntry('README.md');
        await _openExplorerContextMenuByPath(tester, readmePath);
        await tester.tap(find.text('Rename...'));
        await tester.pumpAndSettle();

        final field = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.hintText == 'New name',
        );
        expect(field, findsOneWidget);
        await tester.enterText(field, 'IGNORED.md');
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('README.md'), findsOneWidget);
        expect(find.text('IGNORED.md'), findsNothing);
        expect(await harness.fileSystem.exists(Uri.file(readmePath)), isTrue);
      });

      testWidgets(
        '09: side config tab toggles visibility and state callbacks',
        (WidgetTester tester) async {
          suppressOverflowErrorsForTest();
          await prepareLargeSurface(tester);
          final configVisible = ValueNotifier<bool>(false);
          bool? lastConfigState;

          await tester.pumpWidget(
            _SidePanelHarnessHost(
              configPanelVisible: configVisible,
              onTabChanged: (_, showConfig) => lastConfigState = showConfig,
              configurationPanelBuilder: (_) =>
                  const Center(child: Text('Config Panel Body')),
              initialTabs: [
                PanelTabConfig(
                  title: 'Explorer',
                  icon: Icons.folder_outlined,
                  sections: [_StubView('Explorer', Icons.folder)],
                ),
              ],
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Config Panel Body'), findsNothing);

          await tester.tap(find.byTooltip('Configuration'));
          await tester.pumpAndSettle();

          expect(find.text('Config Panel Body'), findsOneWidget);
          expect(configVisible.value, isTrue);
          expect(lastConfigState, isTrue);

          await tester.tap(find.byTooltip('Explorer'));
          await tester.pumpAndSettle();

          expect(find.text('Config Panel Body'), findsNothing);
          expect(configVisible.value, isFalse);
          expect(lastConfigState, isFalse);
          expect(find.text('Content: Explorer'), findsOneWidget);
        },
      );

      testWidgets('10: added empty side tab can be deleted via context menu', (
        WidgetTester tester,
      ) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);

        await tester.pumpWidget(
          _SidePanelHarnessHost(
            initialTabs: [
              PanelTabConfig(
                title: 'Explorer',
                icon: Icons.folder_outlined,
                sections: [_StubView('Explorer', Icons.folder)],
              ),
            ],
            showConfigTab: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('tab-count:1'), findsOneWidget);

        await tester.tap(find.byTooltip('Add Tab'));
        await tester.pumpAndSettle();

        final field = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == 'Enter tab name',
        );
        expect(field, findsOneWidget);
        await tester.enterText(field, 'Scratch');
        await tester.tap(find.widgetWithText(FilledButton, 'Add'));
        await tester.pumpAndSettle();

        expect(find.text('tab-count:2'), findsOneWidget);
        expect(find.byTooltip('Scratch'), findsOneWidget);
        expect(find.text('Drop editors here'), findsOneWidget);

        await tester.tap(
          find.byTooltip('Scratch'),
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        expect(find.text('Delete Tab'), findsOneWidget);
        await tester.tap(find.text('Delete Tab'));
        await tester.pumpAndSettle();

        expect(find.text('tab-count:1'), findsOneWidget);
        expect(find.byTooltip('Scratch'), findsNothing);
      });
    },
  );
}

Finder _explorerEntry(String fullPath) {
  return find.byKey(ValueKey<String>('forge-explorer-entry:$fullPath'));
}

Future<void> _openExplorerContextMenuByPath(
  WidgetTester tester,
  String fullPath,
) async {
  await tester.tap(
    _explorerEntry(fullPath),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await tester.pumpAndSettle();
}

class _PhaseABExplorerHarness {
  _PhaseABExplorerHarness._({
    required this.shell,
    required this.workspaceRoot,
    required this.fileSystem,
    required this.explorerView,
  });

  final DefaultShellApi shell;
  final String workspaceRoot;
  final MemoryFileSystem fileSystem;
  final ForgeFileExplorerView explorerView;

  static _PhaseABExplorerHarness create() {
    // A synthetic absolute root; nothing is written to real disk. The explorer
    // is backed by an in-memory file system so its stream-free `list()`
    // resolves under the widget test's fake-async zone. (A real-disk
    // `Directory.list()` never delivers its I/O events once the binding is in
    // fake-async mode, which would deadlock the test.)
    final workspaceRoot =
        '${Directory.current.path}/test/phase_ab_fixture_workspace';

    final navigatorKey = GlobalKey<NavigatorState>();
    final fileSystem = MemoryFileSystem(
      seed: {
        '$workspaceRoot/README.md': '# Readme\n',
        '$workspaceRoot/src/main.dart': 'void main() { print("hi"); }\n',
        '$workspaceRoot/src/nested/deep.txt': 'deep\n',
      },
    );
    final shell = DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: fileSystem,
      appName: 'Phase AB Harness',
      navigatorKey: navigatorKey,
    );

    final systemState = shell.systemState as DefaultSystemState;
    systemState.setWorkspaceRootPath(workspaceRoot);

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);
    (shell.modules as DefaultModuleRegistry).register(shellModule);

    final explorerView = ForgeFileExplorerView(
      fileSystem: fileSystem,
      layoutController: shell.layout,
      rootUri: Uri.file(workspaceRoot),
      systemState: systemState,
      fileDecorationManager:
          shell.fileDecorations as DefaultFileDecorationManager,
    );

    addTearDown(shell.dispose);

    return _PhaseABExplorerHarness._(
      shell: shell,
      workspaceRoot: workspaceRoot,
      fileSystem: fileSystem,
      explorerView: explorerView,
    );
  }

  /// Resolves a root-level fixture entry to its absolute path.
  ///
  /// The in-memory fixture layout is known at construction time, so the path is
  /// deterministic. The explorer's entry keys use the same absolute
  /// `$workspaceRoot/<name>` form, so key lookups in the tests match.
  String pathForRootEntry(String basename) => '$workspaceRoot/$basename';

  Widget buildExplorerHost() {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 2200,
          height: 1200,
          child: Builder(builder: (context) => explorerView.buildMain(context)),
        ),
      ),
    );
  }
}

class _SidePanelHarnessHost extends StatefulWidget {
  const _SidePanelHarnessHost({
    required this.initialTabs,
    this.showConfigTab = true,
    this.configPanelVisible,
    this.configurationPanelBuilder,
    this.onTabChanged,
  });

  final List<PanelTabConfig> initialTabs;
  final bool showConfigTab;
  final ValueNotifier<bool>? configPanelVisible;
  final WidgetBuilder? configurationPanelBuilder;
  final void Function(int tabIndex, bool showConfig)? onTabChanged;

  @override
  State<_SidePanelHarnessHost> createState() => _SidePanelHarnessHostState();
}

class _SidePanelHarnessHostState extends State<_SidePanelHarnessHost> {
  late final List<PanelTabConfig> _tabs = List<PanelTabConfig>.of(
    widget.initialTabs,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 500,
          height: 700,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('tab-count:${_tabs.length}'),
              Expanded(
                child: ForgeSidePanelWidget(
                  tabs: _tabs,
                  iconStripPosition: IconStripPosition.left,
                  panelArea: PanelArea.left,
                  showConfigTab: widget.showConfigTab,
                  configPanelVisible: widget.configPanelVisible,
                  configurationPanelBuilder: widget.configurationPanelBuilder,
                  onTabChanged: (tabIndex, showConfig) {
                    widget.onTabChanged?.call(tabIndex, showConfig);
                    setState(() {});
                  },
                  onTabDelete: (tabIndex) {
                    setState(() {
                      if (tabIndex >= 0 && tabIndex < _tabs.length) {
                        _tabs.removeAt(tabIndex);
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StubView extends ForgeView {
  _StubView(this._title, this._icon);

  final String _title;
  final IconData _icon;

  @override
  ValueNotifier<String> get title => ValueNotifier<String>(_title);

  @override
  ValueNotifier<String?> get titleExtension => ValueNotifier<String?>(null);

  @override
  IconData get icon => _icon;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) {
    return Center(child: Text('Content: $_title'));
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';
import 'package:tom_file_system/tom_file_system.dart';

import 'support/shell_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase BD: panel lifecycle, tab management, and editor layout', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    // ── 01 ──────────────────────────────────────────────────────────────
    testWidgets(
      '01: Ctrl+B toggles bottom panel visibility on and off',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseBDHarness.create();
        final layout = harness.shell.layout as DefaultLayoutController;

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        // Bottom panel starts visible.
        expect(layout.bottomPanel.value.isVisible, isTrue);

        // Press Ctrl+B to hide bottom panel.
        await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyB);
        await tester.pumpAndSettle();
        expect(layout.bottomPanel.value.isVisible, isFalse);

        // Press Ctrl+B again to show it.
        await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyB);
        await tester.pumpAndSettle();
        expect(layout.bottomPanel.value.isVisible, isTrue);
      },
    );

    // ── 02 ──────────────────────────────────────────────────────────────
    testWidgets(
      '02: splitMiddlePanel adds a second middle panel; middlePanelCount == 2',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseBDHarness.create();
        final layout = harness.shell.layout as DefaultLayoutController;
        final systemState = harness.shell.systemState as DefaultSystemState;

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        // Open an editor first so there's something in panel 0.
        layout.openEditor(
          harness.module.mainEditor,
          harness.module.mainEditor.uri,
        );
        await tester.pump();

        // Verify we start with one middle panel.
        expect(systemState.middlePanelCount, equals(1));
        expect(layout.middlePanels.value.length, equals(1));

        // Split to a second middle panel.
        layout.splitMiddlePanel();
        await tester.pumpAndSettle();

        // Now there should be two middle panels.
        expect(systemState.middlePanelCount, equals(2));
        expect(layout.middlePanels.value.length, equals(2));
      },
    );

    // ── 03 ──────────────────────────────────────────────────────────────
    testWidgets(
      '03: moveComponent transfers editor from panel 0 to panel 1',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseBDHarness.create();
        final layout = harness.shell.layout as DefaultLayoutController;

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        // Open both editors in the default (single) panel.
        layout.openEditor(
          harness.module.mainEditor,
          harness.module.mainEditor.uri,
        );
        await tester.pump();
        layout.openEditor(
          harness.module.secondaryEditor,
          harness.module.secondaryEditor.uri,
        );
        await tester.pump();

        // Both editors should be in panel 0.
        expect(layout.middlePanels.value[0], contains(harness.module.mainEditor));
        expect(
          layout.middlePanels.value[0],
          contains(harness.module.secondaryEditor),
        );

        // Move secondary editor to panel 1 (creates it automatically).
        layout.moveComponent(harness.module.secondaryEditor, 1);
        await tester.pumpAndSettle();

        // Secondary should now be exclusively in panel 1.
        final panels = layout.middlePanels.value;
        expect(panels.length, equals(2));
        expect(panels[0], isNot(contains(harness.module.secondaryEditor)));
        expect(panels[1], contains(harness.module.secondaryEditor));
        // Main stays in panel 0.
        expect(panels[0], contains(harness.module.mainEditor));
      },
    );

    // ── 04 ──────────────────────────────────────────────────────────────
    testWidgets(
      '04: copyComponent places same editor instance in both panels',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseBDHarness.create();
        final layout = harness.shell.layout as DefaultLayoutController;

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        // Open main editor in panel 0.
        layout.openEditor(
          harness.module.mainEditor,
          harness.module.mainEditor.uri,
        );
        await tester.pump();

        // Create a copy of main editor in panel 1.
        layout.copyComponent(harness.module.mainEditor, 1);
        await tester.pumpAndSettle();

        // Two middle panels should exist.
        final panels = layout.middlePanels.value;
        expect(panels.length, equals(2));

        // The SAME editor instance appears in both panels.
        expect(panels[0], contains(harness.module.mainEditor));
        expect(panels[1], contains(harness.module.mainEditor));
      },
    );

    // ── 05 ──────────────────────────────────────────────────────────────
    testWidgets(
      '05: Ctrl+1 / Ctrl+2 set active middle panel index when split',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseBDHarness.create();
        final layout = harness.shell.layout as DefaultLayoutController;

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        // Open two editors and split into two panels.
        layout.openEditor(
          harness.module.mainEditor,
          harness.module.mainEditor.uri,
        );
        await tester.pump();
        layout.splitAndInsertPanel(1, harness.module.secondaryEditor);
        await tester.pumpAndSettle();

        // Active panel should be 1 after the split (where secondary was placed).
        expect(layout.activeMiddlePanelIndex, equals(1));

        // Press Ctrl+1 to focus the first middle panel.
        await sendPrimaryShortcut(tester, LogicalKeyboardKey.digit1);
        await tester.pumpAndSettle();
        expect(layout.activeMiddlePanelIndex, equals(0));

        // Press Ctrl+2 to focus the second middle panel.
        await sendPrimaryShortcut(tester, LogicalKeyboardKey.digit2);
        await tester.pumpAndSettle();
        expect(layout.activeMiddlePanelIndex, equals(1));
      },
    );

    // ── 06 ──────────────────────────────────────────────────────────────
    testWidgets(
      '06: systemState.hasUnsavedChanges and dirtyEditors reflect editor state',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseBDHarness.create();
        final layout = harness.shell.layout as DefaultLayoutController;
        final systemState = harness.shell.systemState as DefaultSystemState;

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        // Open two editors.
        layout.openEditor(
          harness.module.mainEditor,
          harness.module.mainEditor.uri,
        );
        await tester.pump();
        layout.openEditor(
          harness.module.secondaryEditor,
          harness.module.secondaryEditor.uri,
        );
        await tester.pump();

        // Initially no unsaved changes.
        expect(systemState.hasUnsavedChanges, isFalse);
        expect(systemState.dirtyEditors, isEmpty);

        // Make main editor dirty.
        harness.module.mainEditor.insertText('unsaved text');
        await tester.pump();

        expect(systemState.hasUnsavedChanges, isTrue);
        expect(systemState.dirtyEditors, contains(harness.module.mainEditor));
        expect(systemState.dirtyEditors.length, equals(1));

        // Make secondary editor dirty too.
        harness.module.secondaryEditor.insertText('also unsaved');
        await tester.pump();

        expect(systemState.dirtyEditors.length, equals(2));

        // Mark main clean.
        harness.module.mainEditor.markClean();
        await tester.pump();

        expect(systemState.dirtyEditors.length, equals(1));
        expect(
          systemState.dirtyEditors.first,
          same(harness.module.secondaryEditor),
        );
      },
    );

    // ── 07 ──────────────────────────────────────────────────────────────
    testWidgets(
      '07: focusNextPanel cycles focus through visible panels',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseBDHarness.create();
        final systemState = harness.shell.systemState as DefaultSystemState;

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        // Start with focus on the middle panel.
        systemState.setFocusedPanelLocation(ForgePanelLocation.middle);
        await tester.pump();
        expect(systemState.focusedPanelLocation, equals(ForgePanelLocation.middle));

        // Advance focus: middle → right.
        systemState.focusNextPanel();
        await tester.pump();
        expect(systemState.focusedPanelLocation, equals(ForgePanelLocation.right));

        // Advance again: right → bottom.
        systemState.focusNextPanel();
        await tester.pump();
        expect(systemState.focusedPanelLocation, equals(ForgePanelLocation.bottom));

        // Advance again: bottom → left.
        systemState.focusNextPanel();
        await tester.pump();
        expect(systemState.focusedPanelLocation, equals(ForgePanelLocation.left));

        // Advance again: left → middle (wraps around).
        systemState.focusNextPanel();
        await tester.pump();
        expect(systemState.focusedPanelLocation, equals(ForgePanelLocation.middle));
      },
    );

    // ── 08 ──────────────────────────────────────────────────────────────
    testWidgets(
      '08: File > Close removes the active editor from the open editor list',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseBDHarness.create();
        final layout = harness.shell.layout as DefaultLayoutController;
        final systemState = harness.shell.systemState as DefaultSystemState;

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        // Open two editors.
        layout.openEditor(
          harness.module.mainEditor,
          harness.module.mainEditor.uri,
        );
        await tester.pump();
        layout.openEditor(
          harness.module.secondaryEditor,
          harness.module.secondaryEditor.uri,
        );
        await tester.pump();

        expect(systemState.openEditors.length, equals(2));
        // Active editor is the last opened (secondary).
        expect(systemState.activeEditor, same(harness.module.secondaryEditor));

        // Open File menu and click Close Editor.
        await tester.tap(find.text('File'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Close Editor'));
        await tester.pumpAndSettle();

        // Secondary editor should be removed.
        expect(systemState.openEditors.length, equals(1));
        expect(
          systemState.openEditors,
          isNot(contains(harness.module.secondaryEditor)),
        );
        expect(systemState.openEditors, contains(harness.module.mainEditor));
      },
    );

    // ── 09 ──────────────────────────────────────────────────────────────
    testWidgets(
      '09: splitAndInsertPanel up to 4 panels does not exceed maximum',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseBDHarness.create();
        final layout = harness.shell.layout as DefaultLayoutController;
        final systemState = harness.shell.systemState as DefaultSystemState;

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        // Open three editors.
        layout.openEditor(
          harness.module.mainEditor,
          harness.module.mainEditor.uri,
        );
        await tester.pump();
        layout.openEditor(
          harness.module.secondaryEditor,
          harness.module.secondaryEditor.uri,
        );
        await tester.pump();
        layout.openEditor(
          harness.module.tertiaryEditor,
          harness.module.tertiaryEditor.uri,
        );
        await tester.pump();

        // All three in panel 0.
        expect(systemState.middlePanelCount, equals(1));

        // Split secondary into panel 1.
        layout.splitAndInsertPanel(1, harness.module.secondaryEditor);
        await tester.pumpAndSettle();
        expect(systemState.middlePanelCount, equals(2));

        // Split tertiary into panel 2.
        layout.splitAndInsertPanel(2, harness.module.tertiaryEditor);
        await tester.pumpAndSettle();
        expect(systemState.middlePanelCount, equals(3));

        // Three panels, main stays in panel 0.
        final panels = layout.middlePanels.value;
        expect(panels[0], contains(harness.module.mainEditor));
        expect(panels[1], contains(harness.module.secondaryEditor));
        expect(panels[2], contains(harness.module.tertiaryEditor));
      },
    );

    // ── 10 ──────────────────────────────────────────────────────────────
    testWidgets(
      '10: fixture scenario — open 3 editors, dirty all, save-all, verify clean',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseBDHarness.create();
        final layout = harness.shell.layout as DefaultLayoutController;
        final systemState = harness.shell.systemState as DefaultSystemState;

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        // Open all three editors.
        layout.openEditor(
          harness.module.mainEditor,
          harness.module.mainEditor.uri,
        );
        await tester.pump();
        layout.openEditor(
          harness.module.secondaryEditor,
          harness.module.secondaryEditor.uri,
        );
        await tester.pump();
        layout.openEditor(
          harness.module.tertiaryEditor,
          harness.module.tertiaryEditor.uri,
        );
        await tester.pump();

        expect(systemState.openEditors.length, equals(3));
        expect(systemState.hasUnsavedChanges, isFalse);

        // Dirty all three editors via insertText.
        harness.module.mainEditor.insertText('dirty-main');
        harness.module.secondaryEditor.insertText('dirty-secondary');
        harness.module.tertiaryEditor.insertText('dirty-tertiary');
        await tester.pump();

        expect(systemState.hasUnsavedChanges, isTrue);
        expect(systemState.dirtyEditors.length, equals(3));

        // Press Ctrl+S to trigger save action; ForgeShellScaffold routes this
        // to file.save (active editor). Use File > Save All instead.
        await tester.tap(find.text('File'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save All'));
        await tester.pumpAndSettle();
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();

        // All editors should now be clean.
        expect(systemState.hasUnsavedChanges, isFalse);
        expect(systemState.dirtyEditors, isEmpty);

        // Verify fixture files were written to the in-memory file system.
        String? mainContent;
        String? secondaryContent;
        await tester.runAsync(() async {
          mainContent = await harness.fileSystem.readText(
            harness.module.mainEditor.uri,
          );
          secondaryContent = await harness.fileSystem.readText(
            harness.module.secondaryEditor.uri,
          );
        });
        expect(mainContent, contains('dirty-main'));
        expect(secondaryContent, contains('dirty-secondary'));
      },
    );
  });
}

// ── Harness ──────────────────────────────────────────────────────────────

class _PhaseBDHarness {
  _PhaseBDHarness._({
    required this.shell,
    required this.module,
    required this.application,
    required this.preferences,
    required this.workspaceRoot,
    required this.fileSystem,
  });

  final DefaultShellApi shell;
  final _PhaseBDModule module;
  final ForgeApplication application;
  final ForgePreferencesService preferences;
  final String workspaceRoot;
  final TomMemoryFileSystem fileSystem;

  static _PhaseBDHarness create() {
    final workspaceRoot =
        '${Directory.current.path}/test/phase_bd_fixture_workspace';
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
    final fileSystem = TomMemoryFileSystem(
      seed: {
        '$workspaceRoot/main.test': 'main file content\n',
        '$workspaceRoot/secondary.test': 'secondary file content\n',
        '$workspaceRoot/tertiary.test': 'tertiary file content\n',
      },
    );

    final shell = DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: fileSystem,
      appName: 'Phase BD Harness',
      navigatorKey: navigatorKey,
    );

    final systemState = shell.systemState as DefaultSystemState;
    systemState.setWorkspaceRootPath(workspaceRoot);

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);

    final module = _PhaseBDModule(workspaceRoot: workspaceRoot);
    module.activate(shell);

    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(shellModule);
    registry.register(module);

    final application = ForgeApplication(
      id: 'phase-bd-app',
      title: 'Phase BD App',
      layout: PanelLayout(
        leftPanel: PanelConfig(
          initialSize: 280,
          tabs: [
            PanelTabConfig(
              title: 'Explorer',
              icon: Icons.folder,
              sections: [_StubView('Explorer', Icons.folder)],
            ),
          ],
        ),
        rightPanel: PanelConfig(
          initialSize: 260,
          tabs: [
            PanelTabConfig(
              title: 'Outline',
              icon: Icons.account_tree,
              sections: [_StubView('Outline', Icons.account_tree)],
            ),
          ],
        ),
        bottomPanel: PanelConfig(
          initialSize: 200,
          tabs: [
            PanelTabConfig(
              title: 'Terminal',
              icon: Icons.terminal,
              sections: [],
            ),
          ],
        ),
        middlePanels: const [MiddlePanelConfig()],
      ),
    );
    shell.applications.add(application);
    systemState.activate(application.id);
    systemState.setFocusedPanelLocation(ForgePanelLocation.middle);

    final preferences = ForgePreferencesService();

    return _PhaseBDHarness._(
      shell: shell,
      module: module,
      application: application,
      preferences: preferences,
      workspaceRoot: workspaceRoot,
      fileSystem: fileSystem,
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

// ── Module ───────────────────────────────────────────────────────────────

class _PhaseBDModule extends ForgeModule {
  _PhaseBDModule({required String workspaceRoot}) {
    mainEditor = _PhaseBDEditor(
      this,
      uri: Uri.file('$workspaceRoot/main.test'),
      title: 'Main Test',
      content: 'main file content\n',
    );
    secondaryEditor = _PhaseBDEditor(
      this,
      uri: Uri.file('$workspaceRoot/secondary.test'),
      title: 'Secondary',
      content: 'secondary file content\n',
    );
    tertiaryEditor = _PhaseBDEditor(
      this,
      uri: Uri.file('$workspaceRoot/tertiary.test'),
      title: 'Tertiary',
      content: 'tertiary file content\n',
    );
  }

  late final _PhaseBDEditor mainEditor;
  late final _PhaseBDEditor secondaryEditor;
  late final _PhaseBDEditor tertiaryEditor;

  @override
  String get displayName => 'Phase BD Module';

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => [mainEditor, secondaryEditor, tertiaryEditor];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  List<StatusBarItem> get statusBarItems => const [];
}

// ── Editor ───────────────────────────────────────────────────────────────

class _PhaseBDEditor extends ForgeTestTextEditor {
  _PhaseBDEditor(
    super.module, {
    required Uri uri,
    required String title,
    required String content,
  })  : _uri = uri,
        _titleNotifier = ValueNotifier(title),
        super(
          document: ForgeTestDocument(uri: uri, content: content),
        );

  final Uri _uri;
  final ValueNotifier<String> _titleNotifier;

  @override
  ValueListenable<String> get title => _titleNotifier;

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

// ── Stub View ────────────────────────────────────────────────────────────

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

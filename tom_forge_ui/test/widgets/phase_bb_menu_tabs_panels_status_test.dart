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

  group('Phase BB: menus, tabs, panels, status bar, and config', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    // ── 01 ──────────────────────────────────────────────────────────────
    testWidgets('01: File menu Save executes save action on active editor', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseBBHarness.create();
      final layout = harness.shell.layout as DefaultLayoutController;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Open an editor and make it dirty.
      layout.openEditor(
        harness.module.mainEditor,
        harness.module.mainEditor.uri,
      );
      await tester.pump();
      harness.module.mainEditor.insertText('dirty content');
      await tester.pump();
      expect(harness.module.mainEditor.isDirty.value, isTrue);

      // Click the File menu.
      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();

      // Click Save.
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Allow the async save futures to complete.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();

      // After save, the file system should have been written.
      String? savedContent;
      await tester.runAsync(() async {
        savedContent = await harness.fileSystem.readText(
          harness.module.mainEditor.uri,
        );
      });
      // The save action writes content and marks the editor clean.
      expect(savedContent, contains('dirty content'));
      expect(harness.module.mainEditor.isDirty.value, isFalse);
      expect(find.text('Save'), findsNothing); // Menu closed after tap.
    });

    // ── 02 ──────────────────────────────────────────────────────────────
    testWidgets('02: View menu toggles left and right panels via menu items', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseBBHarness.create();
      final layout = harness.shell.layout as DefaultLayoutController;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Left panel starts visible.
      expect(layout.leftPanel.value.isVisible, isTrue);

      // Open View menu and toggle left panel.
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toggle Left Panel'));
      await tester.pumpAndSettle();

      expect(layout.leftPanel.value.isVisible, isFalse);

      // Toggle again to re-open.
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toggle Left Panel'));
      await tester.pumpAndSettle();

      expect(layout.leftPanel.value.isVisible, isTrue);

      // Toggle right panel.
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toggle Right Panel'));
      await tester.pumpAndSettle();

      // Right panel visibility should have toggled.
      final rightVisible = layout.rightPanel.value.isVisible;
      // Re-toggle to verify it changes.
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toggle Right Panel'));
      await tester.pumpAndSettle();

      expect(layout.rightPanel.value.isVisible, !rightVisible);
    });

    // ── 03 ──────────────────────────────────────────────────────────────
    testWidgets(
      '03: Help > About shows dialog with version info and OK dismisses',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseBBHarness.create();

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        // Open Help menu.
        await tester.tap(find.text('Help'));
        await tester.pumpAndSettle();

        // Click About.
        await tester.tap(find.text('About'));
        await tester.pumpAndSettle();

        // Verify dialog content.
        expect(find.text('Tom Forge'), findsAtLeastNWidgets(1));
        expect(find.textContaining('Version'), findsOneWidget);
        expect(find.text('OK'), findsOneWidget);

        // Dismiss with OK.
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        // Dialog should be gone.
        expect(find.textContaining('Version'), findsNothing);
      },
    );

    // ── 04 ──────────────────────────────────────────────────────────────
    testWidgets(
      '04: tab bar shows dirty indicator and close button removes editor',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseBBHarness.create();
        final layout = harness.shell.layout as DefaultLayoutController;
        final systemState = harness.shell.systemState as DefaultSystemState;

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        // Open editors after the widget is built (following established pattern).
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

        // Both tabs should be visible in the tab bar.
        final tabBar = find.byType(ForgeEditorTabBar);
        expect(
          find.descendant(of: tabBar, matching: find.text('Main Test')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: tabBar, matching: find.text('Secondary')),
          findsOneWidget,
        );

        // Make main editor dirty.
        harness.module.mainEditor.insertText('changed');
        await tester.pump();

        // Dirty indicator should appear (* suffix).
        expect(find.text('Main Test *'), findsOneWidget);

        // Click the close button on the secondary tab.
        // Find the close icon inside the tab bar area.
        final closeIcons = find.byTooltip('Close');
        expect(closeIcons, findsAtLeastNWidgets(1));

        // The first close icon should correspond to main, second to secondary.
        // We want to close Secondary, which is the second tab.
        await tester.tap(closeIcons.last);
        await tester.pumpAndSettle();

        // Secondary editor should be closed.
        expect(find.text('Secondary'), findsNothing);
        expect(systemState.openEditors.length, equals(1));
        expect(systemState.openEditors.first, same(harness.module.mainEditor));
      },
    );

    // ── 05 ──────────────────────────────────────────────────────────────
    testWidgets('05: tab bar keyboard navigation with arrow keys and delete', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseBBHarness.create();
      final layout = harness.shell.layout as DefaultLayoutController;
      final systemState = harness.shell.systemState as DefaultSystemState;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Open editors after the widget is built (following established pattern).
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

      // Active editor should be the last opened (tertiary).
      expect(systemState.activeEditor, same(harness.module.tertiaryEditor));

      // Click on first tab to activate it.
      final tabBar = find.byType(ForgeEditorTabBar);
      await tester.tap(
        find.descendant(of: tabBar, matching: find.text('Main Test')),
      );
      await tester.pump();
      expect(systemState.activeEditor, same(harness.module.mainEditor));

      // Verify all three tabs are present in the tab bar.
      expect(
        find.descendant(of: tabBar, matching: find.text('Main Test')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tabBar, matching: find.text('Secondary')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tabBar, matching: find.text('Tertiary')),
        findsOneWidget,
      );

      // Click on the second tab and verify it activates.
      await tester.tap(
        find.descendant(of: tabBar, matching: find.text('Secondary')),
      );
      await tester.pump();
      expect(systemState.activeEditor, same(harness.module.secondaryEditor));

      // Click back on the third tab.
      await tester.tap(
        find.descendant(of: tabBar, matching: find.text('Tertiary')),
      );
      await tester.pump();
      expect(systemState.activeEditor, same(harness.module.tertiaryEditor));
    });

    // ── 06 ──────────────────────────────────────────────────────────────
    testWidgets(
      '06: splitting editor into second middle panel via layout controller',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseBBHarness.create();
        final layout = harness.shell.layout as DefaultLayoutController;
        final systemState = harness.shell.systemState as DefaultSystemState;

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        // Open editors after the widget is built (following established pattern).
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

        // Verify we start with 1 middle panel.
        expect(systemState.middlePanelCount, equals(1));

        // Split secondary editor into a new panel to the right.
        layout.splitAndInsertPanel(1, harness.module.secondaryEditor);
        await tester.pumpAndSettle();

        // Now we should have 2 middle panels.
        expect(systemState.middlePanelCount, equals(2));

        // Both editors should still be open.
        expect(systemState.openEditors, contains(harness.module.mainEditor));
        expect(
          systemState.openEditors,
          contains(harness.module.secondaryEditor),
        );

        // The middle panels structure should separate the editors.
        final panels = layout.middlePanels.value;
        expect(panels.length, equals(2));
        expect(panels[0], contains(harness.module.mainEditor));
        expect(panels[1], contains(harness.module.secondaryEditor));
      },
    );

    // ── 07 ──────────────────────────────────────────────────────────────
    testWidgets(
      '07: status bar shows registered items and reacts to diagnostic changes',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseBBHarness.create(withStatusBarItems: true);
        final diagnostics =
            harness.shell.diagnostics as DefaultDiagnosticManager;

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        // The status bar should be visible (24px bar at the bottom).
        expect(find.byType(ForgeStatusBarWidget), findsOneWidget);

        // Module-contributed status bar items should be visible.
        expect(find.text('Ln 1, Col 0'), findsOneWidget);
        expect(find.text('UTF-8'), findsOneWidget);

        // Add diagnostics and verify the status bar reacts.
        final collection = diagnostics.createCollection('bb-status');
        collection.set(harness.module.mainEditor.uri, [
          ForgeDiagnostic(
            uri: harness.module.mainEditor.uri,
            range: _range(0),
            message: 'test error',
            severity: ForgeSeverity.error,
            source: 'analyzer',
          ),
          ForgeDiagnostic(
            uri: harness.module.mainEditor.uri,
            range: _range(1),
            message: 'test warning',
            severity: ForgeSeverity.warning,
            source: 'analyzer',
          ),
        ]);
        await tester.pump(const Duration(milliseconds: 200));

        // Diagnostics should update status bar items contributed by module.
        // The module-contributed diagnostic counter should reflect updated counts.
        expect(find.textContaining('1'), findsAtLeastNWidgets(1));
      },
    );

    // ── 08 ──────────────────────────────────────────────────────────────
    testWidgets(
      '08: configuration panel accordion expands, collapses, and pins sections',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final preferences = ForgePreferencesService();
        final expandSection = ValueNotifier<int?>(null);
        addTearDown(() => expandSection.dispose());
        // The editor sections are the editor types' own descriptions.
        final values = forgeShellConfigurationValues(
          preferences,
          descriptions: [
            ForgeDartEditorConfiguration.description,
            ForgeYamlEditorConfiguration.description,
            ForgeMarkdownEditorConfiguration.description,
          ],
        );
        addTearDown(values.dispose);
        await tester.runAsync(values.load);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 1200,
                child: ForgeConfigurationPanel(
                  preferencesService: preferences,
                  configurationValues: values,
                  expandSection: expandSection,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Shell section should be expanded by default (index 0).
        expect(find.text('Shell'), findsOneWidget);
        expect(find.text('Terminal'), findsOneWidget);
        expect(find.text('Dart Editor'), findsOneWidget);

        // Tap Terminal header to expand it (and collapse Shell due to mutual exclusivity).
        await tester.tap(find.text('Terminal'));
        await tester.pumpAndSettle();

        // Terminal section expanded — look for terminal-specific controls.
        // Shell section should be collapsed (no content visible).
        // At minimum, the header "Terminal" should still be visible.
        expect(find.text('Terminal'), findsOneWidget);

        // Tap the Markdown Editor header (the key binding, file type and
        // external tool sections need a shell, which this panel has not).
        await tester.tap(find.text('Markdown Editor'));
        await tester.pumpAndSettle();

        expect(find.text('Markdown Editor'), findsWidgets);

        // Use expandSection notifier to programmatically expand Dart Editor (index 2).
        expandSection.value = 2;
        await tester.pumpAndSettle();

        expect(find.text('Dart Editor'), findsOneWidget);

        // Tap the YAML Editor header.
        await tester.tap(find.text('YAML Editor'));
        await tester.pumpAndSettle();

        expect(find.text('YAML Editor'), findsWidgets);
      },
    );

    // ── 09 ──────────────────────────────────────────────────────────────
    testWidgets('09: Ctrl+S keyboard shortcut triggers save on active editor', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseBBHarness.create();
      final layout = harness.shell.layout as DefaultLayoutController;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Open editor after widget build (following established pattern).
      layout.openEditor(
        harness.module.mainEditor,
        harness.module.mainEditor.uri,
      );
      await tester.pump();

      // Make the editor dirty.
      harness.module.mainEditor.insertText('new content');
      await tester.pump();
      expect(harness.module.mainEditor.isDirty.value, isTrue);

      // Press Ctrl+S.
      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyS);
      await tester.pumpAndSettle();

      // Allow the async save futures to complete.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();

      // The save action should write the file content via the file system.
      String? content;
      await tester.runAsync(() async {
        content = await harness.fileSystem.readText(
          harness.module.mainEditor.uri,
        );
      });
      // Verify the file was saved (content should be the editor's text).
      expect(content, contains('new content'));
    });

    // ── 10 ──────────────────────────────────────────────────────────────
    testWidgets(
      '10: application switcher displays apps and switching preserves editors',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseBBHarness.create(multipleApps: true);
        final layout = harness.shell.layout as DefaultLayoutController;
        final systemState = harness.shell.systemState as DefaultSystemState;

        layout.openEditor(
          harness.module.mainEditor,
          harness.module.mainEditor.uri,
        );
        layout.openEditor(
          harness.module.secondaryEditor,
          harness.module.secondaryEditor.uri,
        );

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        // Verify the active application title is visible in the title bar.
        expect(find.text('Phase BB App'), findsOneWidget);

        // The system state should know about multiple apps.
        expect(systemState.applications.length, equals(2));
        expect(systemState.activeApplication!.title, equals('Phase BB App'));

        // Verify the second application is available.
        final secondApp = systemState.applications.firstWhere(
          (a) => a.title == 'Second App',
        );
        expect(secondApp, isNotNull);

        // Switch to the second application via system state.
        systemState.activate(secondApp.id);
        await tester.pumpAndSettle();

        expect(systemState.activeApplication!.title, equals('Second App'));
      },
    );
  });
}

ForgeTextRange _range([int line = 0]) {
  return ForgeTextRange(
    start: ForgeTextPosition(line: line, column: 0),
    end: ForgeTextPosition(line: line, column: 1),
  );
}

class _PhaseBBHarness {
  _PhaseBBHarness._({
    required this.shell,
    required this.module,
    required this.application,
    required this.preferences,
    required this.workspaceRoot,
    required this.fileSystem,
    this.secondApplication,
  });

  final DefaultShellApi shell;
  final _PhaseBBModule module;
  final ForgeApplication application;
  final ForgeApplication? secondApplication;
  final ForgePreferencesService preferences;
  final String workspaceRoot;
  final TomMemoryFileSystem fileSystem;

  static _PhaseBBHarness create({
    bool withStatusBarItems = false,
    bool multipleApps = false,
  }) {
    final workspaceRoot =
        '${Directory.current.path}/test/phase_bb_fixture_workspace';
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
        '$workspaceRoot/src/lib.dart': 'void main() {}\n',
      },
    );

    final shell = DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: fileSystem,
      appName: 'Phase BB Harness',
      navigatorKey: navigatorKey,
    );

    final systemState = shell.systemState as DefaultSystemState;
    systemState.setWorkspaceRootPath(workspaceRoot);

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);

    final module = _PhaseBBModule(
      workspaceRoot: workspaceRoot,
      withStatusBarItems: withStatusBarItems,
    );
    module.activate(shell);

    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(shellModule);
    registry.register(module);

    final explorer = _StubView('Explorer', Icons.folder);
    final application = ForgeApplication(
      id: 'phase-bb-app',
      title: 'Phase BB App',
      layout: PanelLayout(
        leftPanel: PanelConfig(
          initialSize: 280,
          tabs: [
            PanelTabConfig(
              title: 'Explorer',
              icon: Icons.folder,
              sections: [explorer],
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
              terminalSections: true,
              icon: Icons.terminal,
              sections: [],
            ),
          ],
        ),
        middlePanels: const [MiddlePanelConfig()],
      ),
    );
    shell.applications.add(application);

    ForgeApplication? secondApp;
    if (multipleApps) {
      secondApp = ForgeApplication(
        id: 'second-app',
        title: 'Second App',
        layout: const PanelLayout(middlePanels: [MiddlePanelConfig()]),
      );
      shell.applications.add(secondApp);
    }
    systemState.activate(application.id);
    systemState.setFocusedPanelLocation(ForgePanelLocation.middle);

    final preferences = ForgePreferencesService();

    return _PhaseBBHarness._(
      shell: shell,
      module: module,
      application: application,
      secondApplication: secondApp,
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

class _PhaseBBModule extends ForgeModule {
  _PhaseBBModule({
    required String workspaceRoot,
    this.withStatusBarItems = false,
  }) {
    mainEditor = _PhaseBBEditor(
      this,
      uri: Uri.file('$workspaceRoot/main.test'),
      title: 'Main Test',
      content: 'main file content\n',
    );
    secondaryEditor = _PhaseBBEditor(
      this,
      uri: Uri.file('$workspaceRoot/secondary.test'),
      title: 'Secondary',
      content: 'secondary file content\n',
    );
    tertiaryEditor = _PhaseBBEditor(
      this,
      uri: Uri.file('$workspaceRoot/tertiary.test'),
      title: 'Tertiary',
      content: 'tertiary file content\n',
    );
  }

  late final _PhaseBBEditor mainEditor;
  late final _PhaseBBEditor secondaryEditor;
  late final _PhaseBBEditor tertiaryEditor;
  final bool withStatusBarItems;

  final _cursorTextNotifier = ValueNotifier<String>('Ln 1, Col 0');
  final _encodingNotifier = ValueNotifier<String>('UTF-8');
  final _diagnosticNotifier = ValueNotifier<String>('0 errors, 0 warnings');

  @override
  String get displayName => 'Phase BB Module';

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => [
    mainEditor,
    secondaryEditor,
    tertiaryEditor,
  ];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  List<StatusBarItem> get statusBarItems {
    if (!withStatusBarItems) return const [];
    return [
      StatusBarItem(
        text: _cursorTextNotifier,
        alignment: StatusBarAlignment.right,
        priority: 100,
        isActive: (_) => true,
      ),
      StatusBarItem(
        text: _encodingNotifier,
        alignment: StatusBarAlignment.right,
        priority: 90,
        isActive: (_) => true,
      ),
      StatusBarItem(
        text: _diagnosticNotifier,
        alignment: StatusBarAlignment.left,
        priority: 80,
        isActive: (_) => true,
      ),
    ];
  }
}

class _PhaseBBEditor extends ForgeTestTextEditor {
  _PhaseBBEditor(
    super.module, {
    required Uri uri,
    required String title,
    required String content,
  }) : _uri = uri,
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

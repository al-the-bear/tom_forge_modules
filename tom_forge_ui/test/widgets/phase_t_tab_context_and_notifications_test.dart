import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_forge_core/tom_forge_core.dart'
    show FileHandlingResult, ForgePanelLocation;
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';

import 'support/shell_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase T: tab context menu and notifications', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('01: tab context menu Close closes the targeted editor', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseTHarness.create();
      final layout = harness.shell.layout as DefaultLayoutController;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Open two editors
      layout.openEditor(
        harness.module.secondaryEditor,
        harness.module.secondaryEditor.uri,
        middlePanelIndex: 0,
      );
      await tester.pumpAndSettle();

      final beforeCount = (harness.shell.systemState as DefaultSystemState)
          .openEditors
          .length;
      expect(beforeCount, equals(2));

      // Right-click on secondary tab
      final secondaryTab = find.text('Secondary');
      expect(secondaryTab, findsOneWidget);
      await tester.tap(secondaryTab, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      // Tap 'Close'
      expect(find.text('Close'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      final afterCount = (harness.shell.systemState as DefaultSystemState)
          .openEditors
          .length;
      expect(afterCount, equals(1));
      expect(find.text('Secondary'), findsNothing);
    });

    testWidgets('02: tab context menu Close Others closes all except target', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseTHarness.create();
      final layout = harness.shell.layout as DefaultLayoutController;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Open three editors
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

      expect(
        (harness.shell.systemState as DefaultSystemState).openEditors.length,
        equals(3),
      );

      // Right-click on secondary tab (middle one)
      final secondaryTab = find.text('Secondary');
      expect(secondaryTab, findsOneWidget);
      await tester.tap(secondaryTab, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      // Tap 'Close Others'
      await tester.tap(find.text('Close Others'));
      await tester.pumpAndSettle();

      // Only secondary remains
      expect(
        (harness.shell.systemState as DefaultSystemState).openEditors.length,
        equals(1),
      );
      expect(find.text('Secondary'), findsOneWidget);
      expect(find.text('Main Test'), findsNothing);
      expect(find.text('Tertiary'), findsNothing);
    });

    testWidgets('03: tab context menu Close to Right closes tabs after target', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseTHarness.create();
      final layout = harness.shell.layout as DefaultLayoutController;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Open three editors (main first, then secondary, then tertiary)
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

      // Right-click on secondary tab
      final secondaryTab = find.text('Secondary');
      await tester.tap(secondaryTab, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      // Tap 'Close to the Right'
      await tester.tap(find.text('Close to the Right'));
      await tester.pumpAndSettle();

      // Tertiary should be closed, main and secondary remain
      expect(
        (harness.shell.systemState as DefaultSystemState).openEditors.length,
        equals(2),
      );
      expect(find.text('Main Test'), findsOneWidget);
      expect(find.text('Secondary'), findsOneWidget);
      expect(find.text('Tertiary'), findsNothing);
    });

    testWidgets('04: tab context menu Close All closes all editors', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseTHarness.create();
      final layout = harness.shell.layout as DefaultLayoutController;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Open two editors
      layout.openEditor(
        harness.module.secondaryEditor,
        harness.module.secondaryEditor.uri,
        middlePanelIndex: 0,
      );
      await tester.pumpAndSettle();

      // Right-click on main tab
      final mainTab = find.text('Main Test');
      expect(mainTab, findsOneWidget);
      await tester.tap(mainTab, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      // Tap 'Close All'
      await tester.tap(find.text('Close All'));
      await tester.pumpAndSettle();

      expect(
        (harness.shell.systemState as DefaultSystemState).openEditors.length,
        equals(0),
      );
      expect(find.text('Main Test'), findsNothing);
      expect(find.text('Secondary'), findsNothing);
    });

    testWidgets('05: clicking tab activates that editor', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseTHarness.create();
      final layout = harness.shell.layout as DefaultLayoutController;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Open two editors
      layout.openEditor(
        harness.module.secondaryEditor,
        harness.module.secondaryEditor.uri,
        middlePanelIndex: 0,
      );
      await tester.pumpAndSettle();

      final systemState = harness.shell.systemState as DefaultSystemState;
      // Secondary should be active since it was just opened
      expect(
        systemState.activeEditor?.uri.path.endsWith('secondary.test'),
        isTrue,
      );

      // Click on main tab to activate it
      final mainTab = find.text('Main Test');
      await tester.tap(mainTab);
      await tester.pumpAndSettle();

      expect(
        systemState.activeEditor?.uri.path.endsWith('main.test'),
        isTrue,
      );

      // Click on secondary tab to activate it again
      final secondaryTab = find.text('Secondary');
      await tester.tap(secondaryTab);
      await tester.pumpAndSettle();

      expect(
        systemState.activeEditor?.uri.path.endsWith('secondary.test'),
        isTrue,
      );
    });

    testWidgets('06: notification toast appears on showInformation call', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseTHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Trigger notification
      harness.shell.notifications.showInformation(
        'This is a test notification message',
      );
      await tester.pumpAndSettle();

      // Verify toast appears
      expect(find.text('This is a test notification message'), findsOneWidget);

      // Drain auto-dismiss timer
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('07: notification toast shows warning icon for warnings', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseTHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Trigger warning notification
      harness.shell.notifications.showWarning('This is a warning message');
      await tester.pumpAndSettle();

      expect(find.text('This is a warning message'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);

      // Drain auto-dismiss timer
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('08: notification toast shows error icon for errors', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseTHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Trigger error notification
      harness.shell.notifications.showError('This is an error message');
      await tester.pumpAndSettle();

      expect(find.text('This is an error message'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsWidgets);

      // Drain auto-dismiss timer
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('09: notification dismiss button removes the toast', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseTHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Trigger notification
      harness.shell.notifications.showInformation('This can be dismissed');
      await tester.pumpAndSettle();

      expect(find.text('This can be dismissed'), findsOneWidget);

      // Find close button inside the notification Card - target by ancestor
      final closeButton = find.descendant(
        of: find.byType(Card),
        matching: find.byIcon(Icons.close),
      );
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(find.text('This can be dismissed'), findsNothing);

      // Drain auto-dismiss timer
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('10: revealInExplorer selects file in explorer panel', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseTHarness.create();
      final layout = harness.shell.layout as DefaultLayoutController;

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      // Call revealInExplorer
      final uri = Uri.file('${harness.workspaceRoot}/test-fixtures/main.test');
      layout.revealInExplorer(uri);
      await tester.pumpAndSettle();

      // Explorer panel should be visible (left panel)
      final leftPanelConfig = layout.getPanelConfig(ForgePanelLocation.left);
      expect(leftPanelConfig?.isVisible, isTrue);

      // The system state should register the revealed URI
      final systemState = harness.shell.systemState as DefaultSystemState;
      expect(systemState.selectedExplorerItems, contains(uri));
    });
  });
}

class _PhaseTHarness {
  _PhaseTHarness._({
    required this.shell,
    required this.module,
    required this.application,
    required this.preferences,
    required this.workspaceRoot,
  });

  final DefaultShellApi shell;
  final _PhaseTModule module;
  final ForgeApplication application;
  final ForgePreferencesService preferences;
  final String workspaceRoot;

  static _PhaseTHarness create() {
    final workspaceRoot =
        '${Directory.current.path}/test/phase_t_fixture_workspace';
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
      appName: 'Phase T Harness',
      navigatorKey: navigatorKey,
    );
    (shell.systemState as DefaultSystemState)
        .setWorkspaceRootPath(workspaceRoot);

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);

    final module = _PhaseTModule(workspaceRoot: workspaceRoot);
    module.activate(shell);

    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(shellModule);
    registry.register(module);

    final application = ForgeApplication(
      id: 'phase-t-harness',
      title: 'Phase T Harness',
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
              terminalSections: true,
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
    layout.openEditor(
      module.mainEditor,
      module.mainEditor.uri,
      middlePanelIndex: 0,
    );

    final preferences = ForgePreferencesService();

    return _PhaseTHarness._(
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
            notificationManager: shell.notifications as DefaultNotificationManager,
            preferencesService: preferences,
          ),
        ),
      ),
    );
  }
}

class _PhaseTModule extends ForgeModule {
  _PhaseTModule({required String workspaceRoot}) {
    mainEditor = _PhaseTMainEditor(
      this,
      workspaceRoot: workspaceRoot,
      fileName: 'main.test',
      title: 'Main Test',
    );
    secondaryEditor = _PhaseTMainEditor(
      this,
      workspaceRoot: workspaceRoot,
      fileName: 'secondary.test',
      title: 'Secondary',
    );
    tertiaryEditor = _PhaseTMainEditor(
      this,
      workspaceRoot: workspaceRoot,
      fileName: 'tertiary.test',
      title: 'Tertiary',
    );
    explorerView = _StubView('Explorer View', Icons.folder);
    outlineView = _StubView('Outline View', Icons.account_tree);
    problemsView = _StubView('Problems View', Icons.error_outline);
  }

  late final _PhaseTMainEditor mainEditor;
  late final _PhaseTMainEditor secondaryEditor;
  late final _PhaseTMainEditor tertiaryEditor;
  late final _StubView explorerView;
  late final _StubView outlineView;
  late final _StubView problemsView;

  @override
  String get displayName => 'Phase T Module';

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => [mainEditor, secondaryEditor, tertiaryEditor];

  @override
  List<ForgeView> get views => [explorerView, outlineView, problemsView];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
}

class _PhaseTMainEditor extends ForgeTestTextEditor {
  _PhaseTMainEditor(
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

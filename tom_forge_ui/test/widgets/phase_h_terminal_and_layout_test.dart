import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show ForgePanelLocation;
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';

import 'support/shell_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase H: terminal and layout interaction coverage', () {
    testWidgets('01: primary+] cycles focus across visible panels', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseHHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final state = harness.shell.systemState as DefaultSystemState;
      state.setFocusedPanelLocation(ForgePanelLocation.left);

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.bracketRight);
      expect(state.focusedPanelLocation, equals(ForgePanelLocation.middle));

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.bracketRight);
      expect(state.focusedPanelLocation, equals(ForgePanelLocation.right));

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.bracketRight);
      expect(state.focusedPanelLocation, equals(ForgePanelLocation.bottom));
    });

    testWidgets('02: primary+[ cycles focus in reverse order', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseHHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final state = harness.shell.systemState as DefaultSystemState;
      state.setFocusedPanelLocation(ForgePanelLocation.left);

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.bracketLeft);
      expect(state.focusedPanelLocation, equals(ForgePanelLocation.bottom));

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.bracketLeft);
      expect(state.focusedPanelLocation, equals(ForgePanelLocation.right));
    });

    testWidgets('03: focus cycle skips hidden right panel', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseHHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      layout.closePanel(ForgePanelLocation.right);
      await tester.pumpAndSettle();

      final state = harness.shell.systemState as DefaultSystemState;
      state.setFocusedPanelLocation(ForgePanelLocation.middle);

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.bracketRight);
      expect(state.focusedPanelLocation, equals(ForgePanelLocation.bottom));
    });

    testWidgets('04: reset panel sizes button restores defaults', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseHHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      layout.setPanelSize(ForgePanelLocation.left, 410);
      layout.setPanelSize(ForgePanelLocation.right, 460);
      layout.setPanelSize(ForgePanelLocation.bottom, 260);
      await tester.pumpAndSettle();

      expect(layout.leftPanel.value.size, equals(410));
      expect(layout.rightPanel.value.size, equals(460));
      expect(layout.bottomPanel.value.size, equals(260));

      final resetButton = find.byTooltip('Reset Panel Sizes');
      expect(resetButton, findsOneWidget);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      expect(layout.leftPanel.value.size, equals(280));
      expect(layout.rightPanel.value.size, equals(280));
      expect(layout.bottomPanel.value.size, equals(200));
    });

    testWidgets('05: creating terminal auto-opens hidden bottom panel', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseHHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      layout.closePanel(ForgePanelLocation.bottom);
      await tester.pumpAndSettle();
      expect(layout.bottomPanel.value.isVisible, isFalse);

      harness.shell.terminals.create(name: 'Auto Open Terminal');
      await tester.pumpAndSettle();

      expect(layout.bottomPanel.value.isVisible, isTrue);
    });

    testWidgets('06: fallback terminal sends command and renders output', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseHHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      harness.shell.terminals.create(name: 'Cmd Terminal');
      await tester.pumpAndSettle();

      final input = find.byType(TextField).first;
      expect(input, findsOneWidget);

      await tester.enterText(input, 'echo hello');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.textContaining('hello'), findsWidgets);
    });

    testWidgets('07: kill terminal action removes a terminal section', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseHHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      harness.shell.terminals.create(name: 'Terminal A');
      harness.shell.terminals.create(name: 'Terminal B');
      await tester.pumpAndSettle();

      final terminalTab = harness.application.panelLayout.bottomPanel.tabs
          .firstWhere((t) => t.title == 'Terminal');
      expect(terminalTab.sections.length, equals(2));

      final killButton = find.byTooltip('Kill Terminal').first;
      await tester.tap(killButton);
      await tester.pumpAndSettle();

      expect(terminalTab.sections.length, equals(1));

      // Drain notification auto-dismiss timers triggered by terminal open/close.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('08: closing active terminal promotes previous terminal', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseHHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final first = harness.shell.terminals.create(name: 'Terminal First');
      final second = harness.shell.terminals.create(name: 'Terminal Second');
      await tester.pumpAndSettle();

      expect(harness.shell.terminals.activeTerminal, equals(second));

      second.close();
      await tester.pumpAndSettle();

      expect(harness.shell.terminals.activeTerminal, equals(first));

      // Drain notification auto-dismiss timers triggered by terminal open/close.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('09: wildcard default YAML opens unknown extension as YAML', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseHHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await _openSettingsViaAction(harness, tester);
      await tester.tap(find.text('File Types').first);
      await tester.pumpAndSettle();

      await _selectDefaultFileTypeEditor(tester, 'YAML');
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      layout.openFile(Uri.parse('file:///workspace/test-fixtures/sample.cfg'));
      await tester.pumpAndSettle();

      expect(harness.shell.systemState.activeEditor, isA<ForgeYamlEditor>());
    });

    testWidgets('10: primary+3/4 keep panel index when only two panels', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      await prepareLargeSurface(tester);
      final harness = _PhaseHHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      // The harness application declares two middle groups, which the shell
      // opens when it first shows the application.
      expect(layout.middlePanels.value.length, equals(2));

      layout.setActiveMiddlePanelIndex(1);
      expect(layout.activeMiddlePanelIndex, equals(1));

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.digit3);
      await tester.pumpAndSettle();
      expect(layout.activeMiddlePanelIndex, equals(1));

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.digit4);
      await tester.pumpAndSettle();
      expect(layout.activeMiddlePanelIndex, equals(1));
    });
  });
}

Future<void> _openSettingsViaAction(
  _PhaseHHarness harness,
  WidgetTester tester,
) async {
  final opened = harness.shell.executeAction('forge.openSettings');
  expect(opened, isTrue);
  await tester.pumpAndSettle();
}

Future<void> _selectDefaultFileTypeEditor(
  WidgetTester tester,
  String next,
) async {
  final dropdown = find.byType(DropdownButtonFormField<String>).first;
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(next).last);
  await tester.pumpAndSettle();
}

class _PhaseHHarness {
  _PhaseHHarness._({
    required this.shell,
    required this.module,
    required this.application,
  });

  final DefaultShellApi shell;
  final _PhaseHModule module;
  final ForgeApplication application;

  static _PhaseHHarness create() {
    final navigatorKey = GlobalKey<NavigatorState>();
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {
        '/workspace/test-fixtures/sample.md': '# Phase H\n',
        '/workspace/test-fixtures/sample.cfg': 'a: b\n',
      },
      appName: 'Phase H Harness',
      navigatorKey: navigatorKey,
    );

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);

    final module = _PhaseHModule();
    module.activate(shell);

    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(shellModule);
    registry.register(module);

    final application = ForgeApplication(
      id: 'phase-h-harness',
      title: 'Phase H Harness',
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
        middlePanels: const [MiddlePanelConfig(), MiddlePanelConfig()],
      ),
    );
    shell.applications.add(application);

    final layout = shell.layout as DefaultLayoutController;
    layout.openEditor(module.editor, module.editor.uri, middlePanelIndex: 0);

    return _PhaseHHarness._(
      shell: shell,
      module: module,
      application: application,
    );
  }

  Widget buildShellApp() {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 2200,
          height: 1000,
          child: ForgeShellScaffold(
            shell: shell,
            layoutController: shell.layout as DefaultLayoutController,
            systemState: shell.systemState as DefaultSystemState,
            statusBarController: shell.statusBar,
            notificationManager:
                shell.notifications as DefaultNotificationManager,
          ),
        ),
      ),
    );
  }
}

class _PhaseHModule extends ForgeModule {
  late final ForgeTestTextEditor editor;
  late final _StubView explorerView;
  late final _StubView outlineView;
  late final _StubView problemsView;

  _PhaseHModule() {
    editor = ForgeTestTextEditor(
      this,
      document: ForgeTestDocument(
        uri: Uri.parse('file:///workspace/test-fixtures/sample.md'),
        content: '# Phase H\n',
      ),
    );
    explorerView = _StubView('Explorer View', Icons.folder);
    outlineView = _StubView('Outline View', Icons.account_tree);
    problemsView = _StubView('Problems View', Icons.error_outline);
  }

  @override
  String get displayName => 'Phase H Module';

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => [editor];

  @override
  List<ForgeView> get views => [explorerView, outlineView, problemsView];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
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

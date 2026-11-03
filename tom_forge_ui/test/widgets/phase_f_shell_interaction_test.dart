import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_forge_ui/src/widgets/forge_quick_open.dart';

import 'support/shell_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase F: Shell interaction coverage', () {
    testWidgets('01: primary+shift+P opens quick open, Escape closes it', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      final harness = _PhaseFHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyP, shift: true);
      await tester.pumpAndSettle();

      expect(find.byType(ForgeQuickOpen), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(ForgeQuickOpen), findsNothing);
    });

    testWidgets('02: File > Settings opens configuration panel', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      final harness = _PhaseFHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings...').last);
      await tester.pumpAndSettle();

      expect(find.text('Shell'), findsWidgets);
      expect(find.text('Terminal'), findsWidgets);
      expect(find.text('Dart Editor'), findsWidgets);
    });

    testWidgets('03: Terminal settings section shows default shell input', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      final harness = _PhaseFHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final opened = harness.shell.executeAction('forge.openSettings');
      expect(opened, isTrue);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Terminal').first);
      await tester.pumpAndSettle();

      expect(find.text('Default Shell'), findsOneWidget);
      expect(find.text('/bin/bash'), findsOneWidget);
    });

    testWidgets('04: Dart Editor settings section exposes core controls', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      final harness = _PhaseFHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final opened = harness.shell.executeAction('forge.openSettings');
      expect(opened, isTrue);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dart Editor').first);
      await tester.pumpAndSettle();

      expect(find.text('Font Family'), findsOneWidget);
      expect(find.text('Max undo'), findsOneWidget);
    });

    testWidgets('05: primary+L toggles left panel visibility', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      final harness = _PhaseFHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      expect(layout.leftPanel.value.isVisible, isTrue);

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyL);
      await tester.pumpAndSettle();
      expect(layout.leftPanel.value.isVisible, isFalse);

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyL);
      await tester.pumpAndSettle();
      expect(layout.leftPanel.value.isVisible, isTrue);
    });

    testWidgets('06: primary+R toggles right panel visibility', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      final harness = _PhaseFHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      expect(layout.rightPanel.value.isVisible, isTrue);

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyR);
      await tester.pumpAndSettle();
      expect(layout.rightPanel.value.isVisible, isFalse);

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyR);
      await tester.pumpAndSettle();
      expect(layout.rightPanel.value.isVisible, isTrue);
    });

    testWidgets('07: primary+B toggles bottom panel visibility', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      final harness = _PhaseFHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;
      expect(layout.bottomPanel.value.isVisible, isTrue);

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyB);
      await tester.pumpAndSettle();
      expect(layout.bottomPanel.value.isVisible, isFalse);

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyB);
      await tester.pumpAndSettle();
      expect(layout.bottomPanel.value.isVisible, isTrue);
    });

    testWidgets('08: primary+2 focuses middle panel 2', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      final harness = _PhaseFHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      final layout = harness.shell.layout as DefaultLayoutController;

      layout.setActiveMiddlePanelIndex(0);
      expect(layout.activeMiddlePanelIndex, equals(0));

      await sendPrimaryShortcut(tester, LogicalKeyboardKey.digit2);
      await tester.pumpAndSettle();

      expect(layout.activeMiddlePanelIndex, equals(1));
    });

    testWidgets('09: Tools menu executes module-contributed tool action', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      final harness = _PhaseFHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tools'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Run Fixture Tool').last);
      await tester.pumpAndSettle();

      expect(harness.module.executedActionIds, contains('tool.runFixture'));
    });

    testWidgets('10: terminal creation updates terminal tab sections', (
      WidgetTester tester,
    ) async {
      suppressOverflowErrorsForTest();
      final harness = _PhaseFHarness.create();

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      harness.shell.terminals.create(name: 'Spec Terminal');
      await tester.pumpAndSettle();

      final terminalTab = harness.application.panelLayout.bottomPanel.tabs
          .firstWhere((t) => t.title == 'Terminal');
      expect(terminalTab.sections.length, equals(1));
      expect(terminalTab.sections.single.title.value, equals('Spec Terminal'));

      final rendered = find.byWidgetPredicate((widget) {
        if (widget is! Text) return false;
        final text = widget.data;
        return text != null && text.toLowerCase().contains('spec terminal');
      });
      expect(rendered, findsWidgets);
    });
  });
}

class _PhaseFHarness {
  _PhaseFHarness._({
    required this.shell,
    required this.module,
    required this.application,
  });

  final DefaultShellApi shell;
  final _PhaseFModule module;
  final ForgeApplication application;

  static _PhaseFHarness create() {
    final navigatorKey = GlobalKey<NavigatorState>();
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {
        '/workspace/test-fixtures/notes.test': 'alpha foo\nbeta foo\ngamma',
      },
      appName: 'Phase F Harness',
      navigatorKey: navigatorKey,
    );

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);

    final module = _PhaseFModule();
    module.activate(shell);

    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(shellModule);
    registry.register(module);

    final application = ForgeApplication(
      title: 'Phase F Harness',
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

    final layout = shell.layout as DefaultLayoutController;
    layout.openEditor(module.editor, module.editor.uri, middlePanelIndex: 0);
    layout.splitMiddlePanel();

    return _PhaseFHarness._(
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
            application: application,
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

class _PhaseFModule extends ForgeModule {
  final List<String> executedActionIds = <String>[];

  late final ForgeTestTextEditor editor;
  late final _StubView explorerView;
  late final _StubView outlineView;
  late final _StubView problemsView;

  _PhaseFModule() {
    editor = ForgeTestTextEditor(
      this,
      document: ForgeTestDocument(
        uri: Uri.parse('file:///workspace/test-fixtures/notes.test'),
        content: 'alpha foo\nbeta foo\ngamma',
      ),
    );
    explorerView = _StubView('Explorer View', Icons.folder);
    outlineView = _StubView('Outline View', Icons.account_tree);
    problemsView = _StubView('Problems View', Icons.error_outline);
  }

  @override
  String get displayName => 'Phase F Module';

  @override
  void activate(ForgeShellApi shell) {
    for (final action in actions) {
      shell.actionRegistry.registerAction(action);
    }
  }

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => [editor];

  @override
  List<ForgeView> get views => [explorerView, outlineView, problemsView];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  List<ForgeAction> get actions => <ForgeAction>[
    ForgeAction(
      id: 'tool.runFixture',
      label: 'Run Fixture Tool',
      menu: ForgeMenuLocation.tools,
      execute: (_) async {
        executedActionIds.add('tool.runFixture');
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    ),
  ];
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

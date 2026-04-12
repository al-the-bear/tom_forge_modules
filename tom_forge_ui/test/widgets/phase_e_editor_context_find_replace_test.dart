import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'support/shell_test_utils.dart';

void main() {
  testWidgets('editor area context menu shows base and editor actions', (
    WidgetTester tester,
  ) async {
    suppressOverflowErrorsForTest();
    final harness = _Step5Harness.create();

    await tester.pumpWidget(harness.buildShellApp());
    await tester.pumpAndSettle();

    final target = find.byKey(
      const ValueKey<String>('editor-area-context-target-0'),
    );
    expect(target, findsOneWidget);

    final center = tester.getCenter(target);
    await tester.tapAt(
      center,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    expect(find.text('Cut'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Paste'), findsOneWidget);
    expect(find.text('Format Document'), findsOneWidget);
    expect(find.text('Find'), findsOneWidget);
    expect(find.text('Replace'), findsOneWidget);
    expect(find.text('Custom Editor Action'), findsOneWidget);

    await tester.tap(find.text('Custom Editor Action'));
    await tester.pumpAndSettle();

    expect(
      harness.module.executedActionIds,
      contains('editor.customContextAction'),
    );
  });

  testWidgets('find/replace bar replaces all matches in active text editor', (
    WidgetTester tester,
  ) async {
    suppressOverflowErrorsForTest();
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final harness = _Step5Harness.create();

    await tester.pumpWidget(harness.buildShellApp());
    await tester.pumpAndSettle();

    final opened = harness.shell.executeAction('editor.find');
    expect(opened, isTrue);
    await tester.pumpAndSettle();

    final queryField = find.byKey(const Key('find-bar-query-field'));
    expect(queryField, findsOneWidget);

    await tester.enterText(queryField, 'foo');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('find-match-counter')), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);

    final openedReplace = harness.shell.executeAction('edit.replace');
    expect(openedReplace, isTrue);
    await tester.pumpAndSettle();

    final replaceField = find.byKey(const Key('find-bar-replace-field'));
    expect(replaceField, findsOneWidget);

    await tester.enterText(replaceField, 'qux');
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('find-replace-all-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('find-replace-all-button')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));

    expect(
      harness.module.editor.document.text,
      'qux alpha\nbeta qux\nqux gamma',
    );
    expect(harness.module.editor.document.text.contains('foo'), isFalse);
  });
}

class _Step5Harness {
  _Step5Harness._({
    required this.shell,
    required this.module,
    required this.application,
  });

  final DefaultShellApi shell;
  final _Step5Module module;
  final ForgeApplication application;

  static _Step5Harness create() {
    final navigatorKey = GlobalKey<NavigatorState>();
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'Step 5 Harness',
      navigatorKey: navigatorKey,
    );

    final module = _Step5Module();
    module.activate(shell);
    (shell.modules as DefaultModuleRegistry).register(module);

    final application = ForgeApplication(
      title: 'Step 5 Harness',
      layout: const ApplicationLayout(
        leftPanel: PanelConfig(initialSize: 250, tabs: []),
        rightPanel: PanelConfig(initialSize: 220, tabs: []),
        bottomPanel: PanelConfig(initialSize: 180, tabs: []),
        middlePanels: [MiddlePanelConfig()],
      ),
    );

    final layout = shell.layout as DefaultLayoutController;
    layout.openEditor(module.editor, module.editor.uri);

    return _Step5Harness._(
      shell: shell,
      module: module,
      application: application,
    );
  }

  Widget buildShellApp() {
    return MaterialApp(
      home: ForgeShellScaffold(
        shell: shell,
        application: application,
        layoutController: shell.layout as DefaultLayoutController,
        systemState: shell.systemState as DefaultSystemState,
        statusBarController: shell.statusBar,
        notificationManager: shell.notifications as DefaultNotificationManager,
      ),
    );
  }
}

class _Step5Module extends ForgeModule {
  _Step5Module() {
    editor = ForgeTestTextEditor(
      this,
      document: ForgeTestDocument(
        uri: Uri.parse('file:///workspace/step5.test'),
        content: 'foo alpha\nbeta foo\nfoo gamma',
      ),
    );
  }

  @override
  String get displayName => 'Step 5 Module';

  final List<String> executedActionIds = <String>[];

  late final ForgeTestTextEditor editor;

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
  List<ForgeView> get views => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  List<ForgeAction> get actions => <ForgeAction>[
    ForgeAction(
      id: 'edit.formatDocument',
      label: 'Format Document',
      menu: ForgeMenuLocation.edit,
      execute: (_) async {
        executedActionIds.add('edit.formatDocument');
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    ),
    ForgeAction(
      id: 'editor.customContextAction',
      label: 'Custom Editor Action',
      menu: ForgeMenuLocation.contextMenu,
      showInContextMenu: true,
      execute: (_) async {
        executedActionIds.add('editor.customContextAction');
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    ),
  ];
}

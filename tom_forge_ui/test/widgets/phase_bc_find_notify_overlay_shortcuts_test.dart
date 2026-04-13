import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_forge_ui/src/widgets/forge_notification_popup.dart';

import 'support/shell_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase BC: find bar, notifications, overlays, keyboard shortcuts', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    // ── 01 ──────────────────────────────────────────────────────────────
    testWidgets(
      '01: Ctrl+F opens find bar with query field focused',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseBCHarness.create();
        final layout = harness.shell.layout as DefaultLayoutController;

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        // Open a text editor so the find bar has a target.
        layout.openEditor(
          harness.module.mainEditor,
          harness.module.mainEditor.uri,
        );
        await tester.pump();

        // Find bar should NOT be visible yet.
        expect(find.byKey(const Key('find-bar-query-field')), findsNothing);

        // Press Ctrl+F to open find bar.
        await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyF);
        await tester.pumpAndSettle();

        // Find bar query field should now be visible.
        expect(
          find.byKey(const Key('find-bar-query-field')),
          findsOneWidget,
        );

        // Match counter should show 0/0 initially.
        expect(find.byKey(const Key('find-match-counter')), findsOneWidget);
        final counterWidget = tester.widget<Text>(
          find.byKey(const Key('find-match-counter')),
        );
        expect(counterWidget.data, '0/0');
      },
    );

    // ── 02 ──────────────────────────────────────────────────────────────
    testWidgets(
      '02: find bar match counter updates and prev/next navigate matches',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseBCHarness.create();
        final layout = harness.shell.layout as DefaultLayoutController;

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        layout.openEditor(
          harness.module.mainEditor,
          harness.module.mainEditor.uri,
        );
        await tester.pump();

        // Open find bar.
        await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyF);
        await tester.pumpAndSettle();

        // Type a query that appears multiple times in the document.
        await tester.enterText(
          find.byKey(const Key('find-bar-query-field')),
          'hello',
        );
        await tester.pumpAndSettle();

        // Check match counter shows matches.
        final counter = tester.widget<Text>(
          find.byKey(const Key('find-match-counter')),
        );
        expect(counter.data, contains('/'));
        // Content has 'hello world\nhello again\nhello final' → 3 matches.
        expect(counter.data, '1/3');

        // Click next match button.
        await tester.tap(find.byKey(const Key('find-next-button')));
        await tester.pumpAndSettle();

        final counter2 = tester.widget<Text>(
          find.byKey(const Key('find-match-counter')),
        );
        expect(counter2.data, '2/3');

        // Click prev match button.
        await tester.tap(find.byKey(const Key('find-prev-button')));
        await tester.pumpAndSettle();

        final counter3 = tester.widget<Text>(
          find.byKey(const Key('find-match-counter')),
        );
        expect(counter3.data, '1/3');
      },
    );

    // ── 03 ──────────────────────────────────────────────────────────────
    testWidgets(
      '03: find bar Replace button replaces only the current match',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseBCHarness.create();
        final layout = harness.shell.layout as DefaultLayoutController;

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        layout.openEditor(
          harness.module.mainEditor,
          harness.module.mainEditor.uri,
        );
        await tester.pump();

        // Open find bar.
        await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyF);
        await tester.pumpAndSettle();

        // Enter find query.
        await tester.enterText(
          find.byKey(const Key('find-bar-query-field')),
          'hello',
        );
        await tester.pumpAndSettle();

        // Expand replace fields.
        await tester.tap(find.byKey(const Key('find-toggle-replace-button')));
        await tester.pumpAndSettle();

        // Enter replacement text.
        await tester.enterText(
          find.byKey(const Key('find-bar-replace-field')),
          'REPLACED',
        );
        await tester.pumpAndSettle();

        // Click Replace (single match).
        await tester.tap(find.byKey(const Key('find-replace-button')));
        await tester.pumpAndSettle();

        // After replacing one match, the editor's document should have 2
        // remaining 'hello' strings.
        final text = harness.module.mainEditor.document.text;
        expect('hello'.allMatches(text).length, equals(2));
        expect(text, contains('REPLACED'));
        // Editor should be dirty from the replacement.
        expect(harness.module.mainEditor.isDirty.value, isTrue);
      },
    );

    // ── 04 ──────────────────────────────────────────────────────────────
    testWidgets(
      '04: find bar close button dismisses bar',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseBCHarness.create();
        final layout = harness.shell.layout as DefaultLayoutController;

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        layout.openEditor(
          harness.module.mainEditor,
          harness.module.mainEditor.uri,
        );
        await tester.pump();

        // Open find bar.
        await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyF);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('find-bar-query-field')),
          findsOneWidget,
        );

        // Click close button.
        await tester.tap(find.byKey(const Key('find-close-button')));
        await tester.pumpAndSettle();

        // Find bar should be gone.
        expect(find.byKey(const Key('find-bar-query-field')), findsNothing);
        expect(find.byKey(const Key('find-close-button')), findsNothing);
      },
    );

    // ── 05 ──────────────────────────────────────────────────────────────
    testWidgets(
      '05: notification overlay shows toast cards for info/warning/error',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseBCHarness.create();
        final notifMgr =
            harness.shell.notifications as DefaultNotificationManager;

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        // Show three notifications of different severities.
        notifMgr.showInformation('Info notification');
        notifMgr.showWarning('Warning notification');
        notifMgr.showError('Error notification');
        await tester.pump();

        // All three toast messages should be visible.
        expect(find.text('Info notification'), findsOneWidget);
        expect(find.text('Warning notification'), findsOneWidget);
        expect(find.text('Error notification'), findsOneWidget);

        // Severity icons should be present.
        expect(find.byIcon(Icons.info_outline), findsAtLeastNWidgets(1));
        expect(
          find.byIcon(Icons.warning_amber_outlined),
          findsAtLeastNWidgets(1),
        );
        expect(find.byIcon(Icons.error_outline), findsAtLeastNWidgets(1));

        // Dismiss one notification via the close button.
        // Find close icons inside the notification overlay.
        final closeButtons = find.descendant(
          of: find.byType(ForgeNotificationOverlay),
          matching: find.byIcon(Icons.close),
        );
        expect(closeButtons, findsAtLeastNWidgets(1));
        await tester.tap(closeButtons.first);
        await tester.pump();

        // One less notification should be visible.
        final remaining = notifMgr.notifications.value;
        expect(remaining.length, equals(2));
      },
    );

    // ── 06 ──────────────────────────────────────────────────────────────
    testWidgets(
      '06: notification popup shows history and clear-all removes items',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseBCHarness.create();
        final notifMgr =
            harness.shell.notifications as DefaultNotificationManager;

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        // Fire some notifications so history is populated.
        notifMgr.showInformation('History item 1');
        notifMgr.showWarning('History item 2');
        await tester.pump();

        // Open the notification popup via the manager's popupVisible.
        notifMgr.popupVisible.value = true;
        await tester.pumpAndSettle();

        // The popup should be visible with the "Notifications" header.
        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('History item 1'), findsAtLeastNWidgets(1));
        expect(find.text('History item 2'), findsAtLeastNWidgets(1));

        // Clear all history via the delete_sweep button.
        final clearButton = find.byIcon(Icons.delete_sweep);
        expect(clearButton, findsOneWidget);
        await tester.tap(clearButton);
        await tester.pumpAndSettle();

        // History should be empty.
        expect(notifMgr.history.value, isEmpty);
        expect(find.text('No notifications'), findsOneWidget);

        // Close the popup.
        // Find the close icon in the popup header.
        final popupCloseIcons = find.descendant(
          of: find.byType(ForgeNotificationPopup),
          matching: find.byIcon(Icons.close),
        );
        expect(popupCloseIcons, findsAtLeastNWidgets(1));
        await tester.tap(popupCloseIcons.first);
        await tester.pumpAndSettle();

        // Popup should be hidden.
        expect(notifMgr.popupVisible.value, isFalse);
      },
    );

    // ── 07 ──────────────────────────────────────────────────────────────
    testWidgets(
      '07: quick pick overlay arrow keys navigate and Enter selects',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseBCHarness.create();
        final dialogMgr =
            harness.shell.dialogs as DefaultDialogManager;

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        // Request a quick pick from the dialog manager.
        final result = dialogMgr.showQuickPick<String>([
          const ForgeQuickPickItem(label: 'Alpha', value: 'a'),
          const ForgeQuickPickItem(label: 'Beta', value: 'b'),
          const ForgeQuickPickItem(label: 'Gamma', value: 'c'),
        ], placeholder: 'Pick one');
        await tester.pumpAndSettle();

        // The overlay should be visible.
        expect(find.text('Alpha'), findsOneWidget);
        expect(find.text('Beta'), findsOneWidget);
        expect(find.text('Gamma'), findsOneWidget);

        // Press ArrowDown twice to highlight 'Gamma' (starts at 0 → 1 → 2).
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();

        // Press Enter to select.
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        // The result should be 'c' (Gamma).
        String? selected;
        await tester.runAsync(() async {
          selected = await result;
        });
        expect(selected, equals('c'));

        // Overlay should be dismissed.
        expect(find.text('Alpha'), findsNothing);
      },
    );

    // ── 08 ──────────────────────────────────────────────────────────────
    testWidgets(
      '08: input box Enter submits value and Escape cancels with null',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseBCHarness.create();
        final dialogMgr =
            harness.shell.dialogs as DefaultDialogManager;

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        // -- Test Enter submission --
        final submitResult = dialogMgr.showInputBox(
          prompt: 'Enter file name',
          placeholder: 'file.dart',
        );
        await tester.pumpAndSettle();

        // The input box should be visible with the prompt.
        expect(find.text('Enter file name'), findsOneWidget);

        // Type a value.
        final textField = find.byType(TextField);
        expect(textField, findsAtLeastNWidgets(1));
        await tester.enterText(textField.first, 'my_file.dart');
        await tester.pumpAndSettle();

        // Press Enter to submit.
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        String? submitted;
        await tester.runAsync(() async {
          submitted = await submitResult;
        });
        expect(submitted, equals('my_file.dart'));

        // -- Test Escape cancellation --
        final cancelResult = dialogMgr.showInputBox(
          prompt: 'This will be cancelled',
        );
        await tester.pumpAndSettle();

        expect(find.text('This will be cancelled'), findsOneWidget);

        // Press Escape to cancel.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        String? cancelled;
        await tester.runAsync(() async {
          cancelled = await cancelResult;
        });
        expect(cancelled, isNull);

        // Overlay should be gone.
        expect(find.text('This will be cancelled'), findsNothing);
      },
    );

    // ── 09 ──────────────────────────────────────────────────────────────
    testWidgets(
      '09: Edit menu Undo and Redo dispatch edit.undo and edit.redo actions',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseBCHarness.create();
        final layout = harness.shell.layout as DefaultLayoutController;

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        layout.openEditor(
          harness.module.mainEditor,
          harness.module.mainEditor.uri,
        );
        await tester.pump();

        // Track which actions were executed.
        final executedActions = <String>[];
        harness.module.mainEditor.onActionExecuted = (id) {
          executedActions.add(id);
        };

        // Open Edit menu.
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();

        // Click Undo.
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();

        // Open Edit menu again.
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();

        // Click Redo.
        await tester.tap(find.text('Redo'));
        await tester.pumpAndSettle();

        // Verify actions were dispatched.
        expect(executedActions, contains('edit.undo'));
        expect(executedActions, contains('edit.redo'));
      },
    );

    // ── 10 ──────────────────────────────────────────────────────────────
    testWidgets(
      '10: Ctrl+L and Ctrl+R toggle left and right panels via keyboard',
      (WidgetTester tester) async {
        suppressOverflowErrorsForTest();
        await prepareLargeSurface(tester);
        final harness = _PhaseBCHarness.create();
        final layout = harness.shell.layout as DefaultLayoutController;

        await tester.pumpWidget(harness.buildShellApp());
        await tester.pumpAndSettle();

        // Left panel starts visible.
        expect(layout.leftPanel.value.isVisible, isTrue);

        // Press Ctrl+L to toggle left panel off.
        await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyL);
        await tester.pumpAndSettle();
        expect(layout.leftPanel.value.isVisible, isFalse);

        // Press Ctrl+L again to toggle left panel back on.
        await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyL);
        await tester.pumpAndSettle();
        expect(layout.leftPanel.value.isVisible, isTrue);

        // Get initial right panel state.
        final rightBefore = layout.rightPanel.value.isVisible;

        // Press Ctrl+R to toggle right panel.
        await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyR);
        await tester.pumpAndSettle();
        expect(layout.rightPanel.value.isVisible, !rightBefore);

        // Press Ctrl+R again to restore.
        await sendPrimaryShortcut(tester, LogicalKeyboardKey.keyR);
        await tester.pumpAndSettle();
        expect(layout.rightPanel.value.isVisible, rightBefore);
      },
    );
  });
}

// ── Harness ──────────────────────────────────────────────────────────────

class _PhaseBCHarness {
  _PhaseBCHarness._({
    required this.shell,
    required this.module,
    required this.application,
    required this.preferences,
    required this.workspaceRoot,
    required this.fileSystem,
  });

  final DefaultShellApi shell;
  final _PhaseBCModule module;
  final ForgeApplication application;
  final ForgePreferencesService preferences;
  final String workspaceRoot;
  final MemoryFileSystem fileSystem;

  static _PhaseBCHarness create() {
    final workspaceRoot =
        '${Directory.current.path}/test/phase_bc_fixture_workspace';
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
    final fileSystem = MemoryFileSystem(
      seed: {
        '$workspaceRoot/main.test': 'hello world\nhello again\nhello final\n',
        '$workspaceRoot/secondary.test': 'secondary file content\n',
      },
    );

    final shell = DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: fileSystem,
      appName: 'Phase BC Harness',
      navigatorKey: navigatorKey,
    );

    final systemState = shell.systemState as DefaultSystemState;
    systemState.setWorkspaceRootPath(workspaceRoot);

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);

    final module = _PhaseBCModule(workspaceRoot: workspaceRoot);
    module.activate(shell);

    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(shellModule);
    registry.register(module);

    final explorer = _StubView('Explorer', Icons.folder);
    final application = ForgeApplication(
      title: 'Phase BC App',
      layout: ApplicationLayout(
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
              icon: Icons.terminal,
              sections: [],
            ),
          ],
        ),
        middlePanels: const [MiddlePanelConfig()],
      ),
    );

    systemState.setApplications([application]);
    systemState.setActiveApplication(application);
    systemState.setFocusedPanelLocation(ForgePanelLocation.middle);

    final preferences = ForgePreferencesService();

    return _PhaseBCHarness._(
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
            application: application,
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

// ── Module ──────────────────────────────────────────────────────────────

class _PhaseBCModule extends ForgeModule {
  _PhaseBCModule({required String workspaceRoot}) {
    mainEditor = _PhaseBCEditor(
      this,
      uri: Uri.file('$workspaceRoot/main.test'),
      title: 'Main Test',
      content: 'hello world\nhello again\nhello final\n',
    );
    secondaryEditor = _PhaseBCEditor(
      this,
      uri: Uri.file('$workspaceRoot/secondary.test'),
      title: 'Secondary',
      content: 'secondary file content\n',
    );
  }

  late final _PhaseBCEditor mainEditor;
  late final _PhaseBCEditor secondaryEditor;

  @override
  String get displayName => 'Phase BC Module';

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => [mainEditor, secondaryEditor];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  List<StatusBarItem> get statusBarItems => const [];

  @override
  List<ForgeApplication> get applications => const [];
}

// ── Editor ──────────────────────────────────────────────────────────────

class _PhaseBCEditor extends ForgeTestTextEditor {
  _PhaseBCEditor(
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

  /// Callback for tracking action executions in tests.
  void Function(String actionId)? onActionExecuted;

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
  bool executeAction(String actionId) {
    onActionExecuted?.call(actionId);
    return super.executeAction(actionId);
  }

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

// ── Stub View ───────────────────────────────────────────────────────────

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

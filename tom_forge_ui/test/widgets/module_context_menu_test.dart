/// woneqrb13 — the shell draws module context-menu contributions.
///
/// A fake module contributes entries for the shell's own explorer rows and
/// for a kind of target its editor reports. Right-clicking a row or a unit
/// of the editor draws the contributions keyed by the target's kind: enabled
/// or disabled per the contribution's predicate, the reason as a tooltip
/// while disabled, the target's own items after them, and a chosen entry runs
/// the module's action with the target.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'support/shell_test_utils.dart';

const _workspace = '/workspace';
const _notes = '$_workspace/notes.txt';

void main() {
  testWidgets(
      'WONEQRB13-F1: a right-click on an editor unit draws the contribution '
      'for its kind, labelled for the target, and runs the action with it',
      (tester) async {
    suppressOverflowErrorsForTest();
    final harness = _Harness.create();
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('fake-unit-a'))),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    final entry = find.byKey(const Key('forge-context-menu:fake.act'));
    expect(entry, findsOneWidget);
    expect(find.text('Act on a'), findsOneWidget);
    expect(
      tester.widget<PopupMenuItem<ForgeContextMenuEntry>>(entry).enabled,
      isTrue,
    );
    // A target menu is the target's, not the generic editor menu.
    expect(find.text('Cut'), findsNothing);
    expect(find.text('Edit Action Bar...'), findsNothing);
    // The explorer-kind contribution is not drawn at an editor unit.
    expect(find.byKey(const Key('forge-context-menu:fake.file')), findsNothing);

    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(harness.module.actedAt, hasLength(1));
    expect(harness.module.actedAt.single.kind, 'fake.unit');
    expect(harness.module.actedAt.single.data, 'a');
  });

  testWidgets(
      'WONEQRB13-F2: a disabled entry carries its reason as a tooltip, and '
      'the target\'s own items follow the contributions', (tester) async {
    suppressOverflowErrorsForTest();
    final harness = _Harness.create();
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('fake-unit-b'))),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    final entry = find.byKey(const Key('forge-context-menu:fake.act'));
    expect(entry, findsOneWidget);
    expect(
      tester.widget<PopupMenuItem<ForgeContextMenuEntry>>(entry).enabled,
      isFalse,
    );
    expect(find.byTooltip('B is locked'), findsOneWidget);

    final own = find.byKey(const Key('forge-context-menu:fake.local'));
    expect(own, findsOneWidget);
    // Contributions first, then the target's own items.
    expect(tester.getTopLeft(own).dy, greaterThan(tester.getTopLeft(entry).dy));
    await tester.tap(own);
    await tester.pumpAndSettle();
    expect(harness.module.localRuns, 1);
    expect(harness.module.actedAt, isEmpty);
  });

  testWidgets(
      'WONEQRB13-F3: the shell\'s explorer appends the file-row contributions '
      'to its own entries and runs the action with the file', (tester) async {
    suppressOverflowErrorsForTest();
    final harness = _Harness.create();
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    final row = find.byKey(const ValueKey<String>('forge-explorer-entry:$_notes'));
    expect(row, findsOneWidget);
    await tester.tap(row, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Rename...'), findsOneWidget);
    final entry = find.byKey(const Key('forge-context-menu:fake.file'));
    expect(entry, findsOneWidget);
    expect(find.text('Tag file'), findsOneWidget);
    expect(find.byKey(const Key('forge-context-menu:fake.dir')), findsNothing);

    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(harness.module.actedAt, hasLength(1));
    expect(harness.module.actedAt.single.kind,
        ForgeContextTarget.explorerFileKind);
    expect(harness.module.actedAt.single.data, Uri.file(_notes));
  });

  testWidgets(
      'WONEQRB13-F4: a surface reports a target through shell.contextMenus.show '
      'and the scaffold draws it; nothing applicable draws nothing',
      (tester) async {
    suppressOverflowErrorsForTest();
    final harness = _Harness.create();
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    final nothing = await harness.shell.contextMenus.show(
      const ForgeContextTarget(kind: 'nobody.contributes.here'),
      const Offset(300, 300),
    );
    expect(nothing, isFalse);
    expect(find.byType(PopupMenuItem<ForgeContextMenuEntry>), findsNothing);

    final shown = harness.shell.contextMenus.show(
      const ForgeContextTarget(kind: 'fake.unit', data: 'a'),
      const Offset(300, 300),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forge-context-menu:fake.act')), findsOneWidget);
    await tester.tap(find.byKey(const Key('forge-context-menu:fake.act')));
    await tester.pumpAndSettle();
    expect(await shown, isTrue);
    expect(harness.module.actedAt.single.data, 'a');
  });

  test(
      'WONEQRB13-F5: resolution — an own item a drawn contribution stands for '
      'is skipped, an unknown action id is skipped, an inapplicable entry is '
      'absent rather than disabled', () {
    final harness = _Harness.create();
    final entries = harness.shell.contextMenus.entriesFor(
      ForgeContextTarget(
        kind: 'fake.unit',
        data: 'a',
        items: [
          ForgeContextMenuItem(id: 'fake.act', label: 'Dup', run: () async {}),
          ForgeContextMenuItem(id: 'fake.local', label: 'L', run: () async {}),
        ],
      ),
    );
    expect(entries.map((e) => e.id), ['fake.act', 'fake.local']);
    expect(entries.first.label, 'Act on a');
    expect(entries.first.enabled, isTrue);
    expect(entries.first.unavailableReason, isNull);

    final locked = harness.shell.contextMenus.entriesFor(
      const ForgeContextTarget(kind: 'fake.unit', data: 'b'),
    );
    expect(locked.single.enabled, isFalse);
    expect(locked.single.unavailableReason, 'B is locked');

    // 'fake.ghost' names no registered action; 'fake.never' never applies.
    final none = harness.shell.contextMenus.entriesFor(
      const ForgeContextTarget(kind: 'fake.unit', data: 'z'),
    );
    expect(none.map((e) => e.id), ['fake.act']);
  });
}

class _Harness {
  _Harness._(this.shell, this.module, this.application);

  final DefaultShellApi shell;
  final _FakeModule module;
  final ForgeApplication application;

  static _Harness create() {
    final navigatorKey = GlobalKey<NavigatorState>();
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {_notes: 'notes\n'},
      appName: 'woneqrb13',
      navigatorKey: navigatorKey,
    );
    (shell.systemState as DefaultSystemState).setWorkspaceRootPath(_workspace);
    final module = _FakeModule(shell);
    module.activate(shell);
    (shell.modules as DefaultModuleRegistry).register(module);
    final application = ForgeApplication(
      title: 'woneqrb13',
      layout: ApplicationLayout(
        leftPanel: PanelConfig(
          initialSize: 260,
          tabs: [
            PanelTabConfig(
              title: 'Explorer',
              icon: Icons.folder,
              sections: [module.explorer],
            ),
          ],
        ),
        rightPanel: const PanelConfig(initialSize: 200, tabs: []),
        bottomPanel: const PanelConfig(initialSize: 160, tabs: []),
        middlePanels: const [MiddlePanelConfig()],
      ),
    );
    (shell.layout as DefaultLayoutController)
        .openEditor(module.editor, module.editor.uri);
    return _Harness._(shell, module, application);
  }

  Widget app() => MaterialApp(
        home: ForgeShellScaffold(
          shell: shell,
          application: application,
          layoutController: shell.layout as DefaultLayoutController,
          systemState: shell.systemState as DefaultSystemState,
          statusBarController: shell.statusBar,
          notificationManager:
              shell.notifications as DefaultNotificationManager,
        ),
      );
}

class _FakeModule extends ForgeModule {
  _FakeModule(ForgeShellApi shell)
      : explorer = ForgeFileExplorerView(
          fileSystem: shell.fileSystem,
          layoutController: shell.layout,
          rootUri: Uri.file(_workspace),
          systemState: shell.systemState as DefaultSystemState,
          contextMenus: shell.contextMenus,
        );

  final ForgeFileExplorerView explorer;
  late final _FakeEditor editor = _FakeEditor(this);

  /// Every target the actions were run with.
  final List<ForgeContextTarget> actedAt = [];
  int localRuns = 0;

  @override
  String get displayName => 'Fake';

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => [editor];

  @override
  List<ForgeView> get views => [explorer];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  ForgeAction _recording(String id, String label) => ForgeAction(
        id: id,
        label: label,
        execute: (parameters) async {
          final target = parameters[ForgeContextTarget.parameterKey];
          if (target is ForgeContextTarget) actedAt.add(target);
          return null;
        },
        isEnabled: () => true,
        isVisible: () => true,
      );

  @override
  List<ForgeAction> get actions => [
        _recording('fake.act', 'Act'),
        _recording('fake.file', 'Tag file'),
        _recording('fake.dir', 'Tag folder'),
        _recording('fake.never', 'Never'),
      ];

  @override
  List<ForgeContextMenuContribution> get contextMenus => [
        ForgeContextMenuContribution(
          targetKind: 'fake.unit',
          actionId: 'fake.act',
          label: (t) => 'Act on ${t.data}',
          unavailableReason: (t) => t.data == 'b' ? 'B is locked' : null,
        ),
        // Applies nowhere: absent from every menu, never disabled.
        ForgeContextMenuContribution(
          targetKind: 'fake.unit',
          actionId: 'fake.never',
          isApplicable: (_) => false,
        ),
        // Names no action: skipped.
        const ForgeContextMenuContribution(
          targetKind: 'fake.unit',
          actionId: 'fake.ghost',
        ),
        const ForgeContextMenuContribution(
          targetKind: ForgeContextTarget.explorerFileKind,
          actionId: 'fake.file',
        ),
        const ForgeContextMenuContribution(
          targetKind: ForgeContextTarget.explorerDirectoryKind,
          actionId: 'fake.dir',
        ),
      ];
}

/// An editor with two units; the one under the pointer is the target.
class _FakeEditor extends ForgeEditor implements ForgeContextTargetProvider {
  _FakeEditor(this.module);

  final _FakeModule module;
  final _a = GlobalKey();
  final _b = GlobalKey();
  final _dirty = ValueNotifier<bool>(false);

  @override
  ValueListenable<String> get title => ValueNotifier('Fake');

  @override
  ValueListenable<String?> get titleExtension => ValueNotifier(null);

  @override
  IconData get icon => Icons.widgets;

  @override
  Uri get uri => Uri.parse('file:///workspace/fake.unit');

  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.reject;

  @override
  ValueListenable<bool> get isDirty => _dirty;

  @override
  void markClean() => _dirty.value = false;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) => Row(
        children: [
          Expanded(
            child: Container(
              key: _a,
              color: Colors.blue.shade100,
              child: const Center(child: Text('unit a', key: Key('fake-unit-a'))),
            ),
          ),
          Expanded(
            child: Container(
              key: _b,
              color: Colors.green.shade100,
              child: const Center(child: Text('unit b', key: Key('fake-unit-b'))),
            ),
          ),
        ],
      );

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);

  bool _hit(GlobalKey key, Offset global) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return false;
    return (Offset.zero & box.size).contains(box.globalToLocal(global));
  }

  @override
  ForgeContextTarget? contextTargetAt(Offset globalPosition) {
    if (_hit(_a, globalPosition)) {
      return const ForgeContextTarget(kind: 'fake.unit', data: 'a');
    }
    if (_hit(_b, globalPosition)) {
      return ForgeContextTarget(
        kind: 'fake.unit',
        data: 'b',
        items: [
          ForgeContextMenuItem(
            id: 'fake.local',
            label: 'Only b can do this',
            run: () async => module.localRuns++,
          ),
        ],
      );
    }
    return null;
  }
}

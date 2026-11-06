/// Every panel application's layout survives a restart (qim_none-3).
///
/// At exit the shell writes `.forge/state/apps/<hash of id>.json` for every
/// open panel application shown in the session — the one on show and the
/// ones kept while another was shown — and at the next start each one comes
/// back with its middle groups, the files open in them, the active group and
/// its side panel's tab, on its first show instead of its declared layout. An
/// application never saved still gets its declared layout.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_test_support/roots.dart';

const _files = {
  '/workspace/alpha.txt': 'alpha',
  '/workspace/beta-one.txt': 'beta one',
  '/workspace/beta-two.txt': 'beta two',
};

Uri _uri(String name) => Uri.parse('file:///workspace/$name');

void main() {
  setUp(() {
    // The scaffold loads its preferences before it restores the layout.
    SharedPreferences.setMockInitialValues({});
    final oldOnError = FlutterError.onError;
    // The full scaffold overflows the default surface; irrelevant here.
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      oldOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = oldOnError);
  });

  testWidgets(
    'QIMN3-1: two panel applications with different middle groups, open files '
    'and side-panel tabs both come back after a restart over a real .forge '
    'directory; one never saved gets its declared layout',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final workspace = tomWorkspaceZtmp().createTempSync(
        'tom_forge_261106_qim_none-3_',
      );
      addTearDown(() => workspace.deleteSync(recursive: true));

      // ── First session: alpha and beta laid out differently. ──
      var session = await tester.runAsync(() => _Session.start(workspace));
      session!;
      final alpha = session.shell.applications.open(
        'quest',
        title: 'alpha',
        payload: const {'quest': 'alpha'},
      );
      final beta = session.shell.applications.open(
        'quest',
        title: 'beta',
        payload: const {'quest': 'beta'},
      );
      await tester.pumpWidget(session.app());
      await _settle(tester);

      // beta (on show): two groups, a file in each, the second group active,
      // the Notes tab.
      // Each first opens its declared editor, which the user closes here: the
      // layouts are made of files, which reopen by URI.
      final layout = session.layout;
      layout.closeAllEditors();
      layout.openFile(_uri('beta-one.txt'));
      await _settle(tester);
      layout.splitMiddlePanel();
      layout.openFile(_uri('beta-two.txt'), middlePanelIndex: 1);
      await _settle(tester);
      layout.setActiveMiddlePanelIndex(1);
      await tester.tap(find.byTooltip('Notes').first);
      await _settle(tester);
      expect(find.text('NOTES of beta'), findsOneWidget);
      expect(_groups(layout), [
        [_uri('beta-one.txt')],
        [_uri('beta-two.txt')],
      ]);

      // alpha: one group with one file, the Process tab; it is on show at
      // exit, so beta's layout is the one kept in memory.
      session.shell.applications.activate(alpha.id);
      await _settle(tester);
      layout.closeAllEditors();
      layout.openFile(_uri('alpha.txt'));
      await _settle(tester);
      expect(_groups(layout), [
        [_uri('alpha.txt')],
      ]);
      await _written(tester, session.shell);

      await tester.pumpWidget(const SizedBox());
      await _io(tester, until: () => _savedApplications(workspace).length == 2);
      expect(
        _savedApplications(workspace),
        hasLength(2),
        reason: 'both panel applications shown in the session are written',
      );

      // ── Second session: both come back as they were. ──
      session = await tester.runAsync(() => _Session.start(workspace));
      session!;
      // An application never saved: opened before the scaffold, so it is in
      // the registry when the saved layouts are read, and there is no file.
      final gamma = session.shell.applications.open(
        'quest',
        title: 'gamma',
        payload: const {'quest': 'gamma'},
        activate: false,
      );
      expect(
        session.shell.applications.all.map((a) => a.id),
        containsAll([alpha.id, beta.id, gamma.id]),
      );
      expect(session.shell.applications.active!.id, alpha.id);
      await tester.pumpWidget(session.app());
      await _io(tester);
      await _settle(tester);

      final restored = session.layout;
      expect(_groups(restored), [
        [_uri('alpha.txt')],
      ], reason: 'alpha, on show at start, has its saved group');
      expect(find.text('PROCESS of alpha'), findsOneWidget);

      session.shell.applications.activate(beta.id);
      await _settle(tester);
      expect(
        _groups(restored),
        [
          [_uri('beta-one.txt')],
          [_uri('beta-two.txt')],
        ],
        reason: 'beta, kept in memory at exit, has both its groups',
      );
      expect(restored.activeMiddlePanelIndex, 1);
      expect(
        find.text('NOTES of beta'),
        findsOneWidget,
        reason: 'and the side-panel tab it left',
      );

      session.shell.applications.activate(gamma.id);
      await _settle(tester);
      expect(_groups(restored), [
        [_uri('gamma/declared.txt')],
      ], reason: 'never saved: its declared layout');
      expect(find.text('PROCESS of gamma'), findsOneWidget);

      await _written(tester, session.shell);
      await tester.pumpWidget(const SizedBox());
      await _io(tester);
    },
  );
}

/// The ids whose state files `.forge/state/apps/` holds.
List<String> _savedApplications(Directory workspace) {
  final apps = Directory('${workspace.path}/.forge/state/apps');
  if (!apps.existsSync()) return const [];
  return [
    for (final file in apps.listSync().whereType<File>())
      if (file.readAsStringSync().contains('"layout"')) file.path,
  ];
}

/// Lets real file I/O started inside the test's fake-async zone finish:
/// its continuations are scheduled in that zone, so real time passes and the
/// zone is pumped by turns — until [until] holds, or a few rounds without one.
Future<void> _io(WidgetTester tester, {bool Function()? until}) async {
  for (var i = 0; i < (until == null ? 40 : 100); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (until != null && until()) return;
  }
}

/// Waits until the open applications as they are now are on disk.
Future<void> _written(WidgetTester tester, DefaultShellApi shell) async {
  var done = false;
  unawaited(shell.applicationsWritten().then((_) => done = true));
  await _io(tester, until: () => done);
  expect(done, isTrue, reason: 'the open applications were written');
}

/// Lets file opens, which read through the file system, finish.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

/// The URIs open in each middle group.
List<List<Uri>> _groups(DefaultLayoutController layout) => [
  for (final group in layout.middlePanels.value) [for (final e in group) e.uri],
];

/// One run of the app over [workspace]'s `.forge`: a fresh shell, its saved
/// applications restored through the quest factory.
class _Session {
  _Session._(this.shell);

  final DefaultShellApi shell;

  DefaultLayoutController get layout => shell.layout as DefaultLayoutController;

  static Future<_Session> start(Directory workspace) async {
    final state = DefaultWorkspaceStateManager();
    await state.initialize(workspace.path);
    final shell = DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: TomMemoryFileSystem(seed: _files),
      appName: 'qim_none-3',
      navigatorKey: GlobalKey<NavigatorState>(),
      workspaceState: state,
    );
    final shellModule = TomForgeShellModule();
    (shell.modules as DefaultModuleRegistry).register(shellModule);
    shellModule.activate(shell);
    shell.setFileTypeDefault('.txt', 'plaintext');
    shell.applications.registerFactory(_QuestFactory());
    await shell.restoreApplications();
    return _Session._(shell);
  }

  Widget app() => MaterialApp(
    home: ForgeShellScaffold(
      shell: shell,
      layoutController: layout,
      systemState: shell.systemState as DefaultSystemState,
      statusBarController: shell.statusBar,
      notificationManager: shell.notifications as DefaultNotificationManager,
    ),
  );
}

/// Quest applications: a Process and a Notes tab on the left, one declared
/// middle group holding `<quest>/declared.txt`.
class _QuestFactory implements ForgeApplicationFactory {
  @override
  String get kind => 'quest';

  @override
  ForgeApplication create(ForgeApplicationContext context, String title) {
    final quest = context.payload['quest']! as String;
    return ForgeApplication(
      id: context.id,
      title: title,
      kind: kind,
      payload: context.payload,
      layout: PanelLayout(
        leftPanel: PanelConfig(
          tabs: [
            PanelTabConfig(
              title: 'Process',
              icon: Icons.account_tree,
              sections: [_LabelView('PROCESS of $quest')],
            ),
            PanelTabConfig(
              title: 'Notes',
              icon: Icons.notes,
              sections: [_LabelView('NOTES of $quest')],
            ),
          ],
        ),
        middlePanels: [
          MiddlePanelConfig(
            tabs: [MiddleTabConfig(editor: _StubEditor('$quest/declared.txt'))],
          ),
        ],
      ),
    );
  }
}

class _LabelView extends ForgeView {
  _LabelView(this.label);

  final String label;

  @override
  ValueListenable<String> get title => ValueNotifier(label);

  @override
  ValueListenable<String?> get titleExtension => ValueNotifier(null);

  @override
  IconData get icon => Icons.flag;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) => Text(label);

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

class _StubEditor extends ForgeEditor {
  _StubEditor(this._name);

  final String _name;
  final _dirty = ValueNotifier(false);

  @override
  ValueNotifier<String> get title => ValueNotifier(_name);

  @override
  ValueNotifier<String?> get titleExtension => ValueNotifier(null);

  @override
  IconData get icon => Icons.description;

  @override
  Uri get uri => Uri.parse('file:///workspace/$_name');

  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.reject;

  @override
  ValueListenable<bool> get isDirty => _dirty;

  @override
  void markClean() => _dirty.value = false;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) => Text('Editor: $_name');

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

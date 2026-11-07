/// The quest application frame before the quest runtime (qim_none-4).
///
/// The quests are the directories under the workspace's `_ai/quests/`; the
/// Open Quest picker — the same module action in every application — opens
/// one application of kind `quest` per quest, or activates the one already
/// open; its frame holds @TOM and @TOM WS on the left, an editor group in the
/// middle, @CHAT and @WS at the bottom, each saying the runtime is not
/// connected yet; and the quest applications come back after a restart, with
/// their layouts, through the registered factory.
library;

import 'dart:async';
import 'dart:io';

import 'package:tom_file_system/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_forge_quests/tom_forge_quests.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_test_support/roots.dart';

const _workspace = '/ws';

const _files = {
  '$_workspace/_ai/quests/alpha/overview.alpha.md': '# alpha',
  '$_workspace/_ai/quests/beta/overview.beta.md': '# beta',
  '$_workspace/_ai/quests/quests_overview.md': '# not a quest',
  '$_workspace/_ai/quests/.hidden/x.md': 'hidden',
};

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

  group('the quests', () {
    test('QIMN4-1: the quests are the folders under _ai/quests/, sorted; files '
        'and hidden folders are not, and a workspace without the folder has '
        'none', () async {
      final fs = TomMemoryFileSystem(seed: _files);
      expect(await listForgeQuests(fs, _workspace), ['alpha', 'beta']);
      expect(await listForgeQuests(fs, '$_workspace/'), ['alpha', 'beta']);
      expect(await listForgeQuests(fs, '/elsewhere'), isEmpty);
    });
  });

  group('the application', () {
    test('QIMN4-2: the frame holds @TOM and @TOM WS on the left, one editor '
        'group, @CHAT and @WS at the bottom; a payload without a quest is '
        'refused', () {
      final registry = DefaultSystemState()
        ..registerFactory(ForgeQuestApplicationFactory());
      final app = registry.open(
        questApplicationKind,
        title: 'alpha',
        payload: const {questPayloadKey: 'alpha'},
      );
      expect(questOf(app), 'alpha');
      expect(app.kind, questApplicationKind);
      expect(app.isRestorable, isTrue);
      final layout = app.panelLayout;
      expect(layout.leftPanel.tabs.map((t) => t.title), ['@TOM', '@TOM WS']);
      expect(layout.bottomPanel.tabs.map((t) => t.title), ['@CHAT', '@WS']);
      expect(layout.middlePanels, hasLength(1));
      expect(
        layout.leftPanel.tabs.first.sections.single,
        isA<ForgeQuestPlaceholderView>(),
      );
      expect(
        () => registry.open(questApplicationKind, title: 'x'),
        throwsArgumentError,
      );
    });

    test(
      'QIMN4-3: the lifecycle reports what the runtime sets: background '
      'work, the busy badge, and a close or quit vetoed while busy',
      () async {
        final registry = DefaultSystemState()
          ..registerFactory(ForgeQuestApplicationFactory());
        final app = registry.open(
          questApplicationKind,
          title: 'alpha',
          payload: const {questPayloadKey: 'alpha'},
        );
        final lifecycle = app.lifecycle as ForgeQuestApplicationLifecycle;
        expect(lifecycle.hasBackgroundWork.value, isFalse);
        expect(await lifecycle.closing(app), isNull, reason: 'no runtime yet');
        expect(await registry.quit(), isTrue);

        lifecycle.backgroundWork.value = true;
        lifecycle.busyLabel.value = 'Queue sending 3 prompts';
        expect(lifecycle.hasBackgroundWork.value, isTrue);
        expect(lifecycle.busy.value, 'Queue sending 3 prompts');
        expect(
          await lifecycle.closing(app),
          'The quest runtime of alpha is still busy: Queue sending 3 prompts.',
        );
        expect(await registry.quit(), isFalse, reason: 'no one to ask');
      },
    );
  });

  testWidgets(
    'QIMN4-4: two quest applications open from the picker — in the tom_forge '
    'application and in a quest application — switch, one per quest, and come '
    'back after a restart over a real .forge directory with their layouts',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final forgeDir = tomWorkspaceZtmp().createTempSync(
        'tom_forge_261106_qim_none-4_',
      );
      addTearDown(() => forgeDir.deleteSync(recursive: true));

      // ── First session. ──
      var session = await tester.runAsync(() => _Session.start(forgeDir));
      session!;
      await tester.pumpWidget(session.app());
      await _settle(tester);
      expect(session.shell.applications.active!.id, _forgeId);

      // The picker in the tom_forge application: every quest, none open.
      await _pick(tester, session, 'alpha', offered: ['alpha', 'beta']);
      final alpha = session.shell.applications.active!;
      expect(questOf(alpha), 'alpha');
      expect(find.text('@TOM — Quest views of alpha'), findsOneWidget);
      expect(find.text('@CHAT — Chat of alpha'), findsOneWidget);
      expect(
        find.text('The quest runtime is not connected yet.'),
        findsNWidgets(2),
      );

      // The picker in a quest application: alpha is marked open.
      await _pick(
        tester,
        session,
        'beta',
        offered: ['alpha', 'beta'],
        markedOpen: 1,
      );
      expect(find.text('open'), findsNothing, reason: 'the picker closed');
      final beta = session.shell.applications.active!;
      expect(questOf(beta), 'beta');
      expect(find.text('@TOM — Quest views of beta'), findsOneWidget);
      // beta's layout differs from alpha's: the @TOM WS tab.
      await tester.tap(find.byTooltip('@TOM WS').first);
      await _settle(tester);
      expect(find.text('@TOM WS — Workspace views of beta'), findsOneWidget);

      // At most one application per quest: picking alpha switches to it.
      await _pick(tester, session, 'alpha');
      expect(session.shell.applications.active, same(alpha));
      expect(session.shell.applications.all.map((a) => a.title), [
        'Tom Forge',
        'alpha',
        'beta',
      ]);
      expect(find.text('@TOM — Quest views of alpha'), findsOneWidget);

      await _written(tester, session.shell);
      await tester.pumpWidget(const SizedBox());
      // Every panel application shown in the session: Tom Forge and both
      // quest applications.
      await _io(tester, until: () => _savedLayouts(forgeDir) == 3);
      expect(_savedLayouts(forgeDir), 3, reason: 'the three layouts written');

      // ── Second session: the quest applications come back. ──
      session = await tester.runAsync(() => _Session.start(forgeDir));
      session!;
      final restored = session.shell.applications.all;
      expect(restored.map((a) => (a.id, a.title, questOf(a))), [
        (_forgeId, 'Tom Forge', null),
        (alpha.id, 'alpha', 'alpha'),
        (beta.id, 'beta', 'beta'),
      ]);
      expect(session.shell.applications.active!.id, alpha.id);
      await tester.pumpWidget(session.app());
      await _io(tester);
      await _settle(tester);
      expect(find.text('@TOM — Quest views of alpha'), findsOneWidget);

      session.shell.applications.activate(beta.id);
      await _settle(tester);
      expect(
        find.text('@TOM WS — Workspace views of beta'),
        findsOneWidget,
        reason: 'beta comes back on the tab it left',
      );

      await _written(tester, session.shell);
      await tester.pumpWidget(const SizedBox());
      await _io(tester);
    },
  );
}

const _forgeId = 'tom-forge';

/// Runs the Open Quest action in the application on show and picks [quest];
/// with [offered], checks the picker lists those quests and marks
/// [markedOpen] of them open.
Future<void> _pick(
  WidgetTester tester,
  _Session session,
  String quest, {
  List<String>? offered,
  int markedOpen = 0,
}) async {
  session.shell.executeAction(forgeOpenQuestActionId);
  await _io(tester);
  await _settle(tester);
  if (offered != null) {
    for (final id in offered) {
      expect(find.text(id), findsWidgets, reason: 'the picker offers $id');
    }
    expect(find.text('open'), findsNWidgets(markedOpen));
    expect(find.text('quests_overview.md'), findsNothing);
    expect(find.text('.hidden'), findsNothing);
  }
  await tester.tap(find.text(quest).last);
  await _settle(tester);
}

/// The application layouts `.forge/state/apps/` holds.
int _savedLayouts(Directory forgeDir) {
  final apps = Directory('${forgeDir.path}/.forge/state/apps');
  if (!apps.existsSync()) return 0;
  return apps
      .listSync()
      .whereType<File>()
      .where((f) => f.readAsStringSync().contains('"layout"'))
      .length;
}

/// Lets real file I/O started inside the test's fake-async zone finish: its
/// continuations are scheduled in that zone, so real time passes and the zone
/// is pumped by turns — until [until] holds, or a few rounds without one.
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

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

/// One run of a Forge host over [forgeDir]'s `.forge`: a tom_forge
/// application, the quests module, and the applications open at the last
/// exit restored.
class _Session {
  _Session._(this.shell);

  final DefaultShellApi shell;

  static Future<_Session> start(Directory forgeDir) async {
    final state = DefaultWorkspaceStateManager();
    await state.initialize(TomLocalFileSystem(forgeDir.path));
    final shell = DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: TomMemoryFileSystem(seed: _files),
      appName: 'qim_none-4',
      navigatorKey: GlobalKey<NavigatorState>(),
      workspaceState: state,
    );
    (shell.systemState as DefaultSystemState).setWorkspaceRootPath(_workspace);
    final quests = ForgeQuestsModule();
    quests.activate(shell);
    (shell.modules as DefaultModuleRegistry).register(quests);
    shell.applications.add(
      ForgeApplication(
        id: _forgeId,
        title: 'Tom Forge',
        layout: const PanelLayout(middlePanels: [MiddlePanelConfig()]),
      ),
    );
    await shell.restoreApplications();
    return _Session._(shell);
  }

  Widget app() => MaterialApp(
    home: ForgeShellScaffold(
      shell: shell,
      layoutController: shell.layout as DefaultLayoutController,
      systemState: shell.systemState as DefaultSystemState,
      statusBarController: shell.statusBar,
      notificationManager: shell.notifications as DefaultNotificationManager,
    ),
  );
}

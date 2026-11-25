/// The quest view as a kit view (forgemods4), over a fixture quest folder.
///
/// The catalogue: the Logs panel's tabs in their order plus Todos, each file
/// relative to the quest folder, the extension's single-file shape, Current
/// Prompt in the trail bucket, the sessions, the quest folders under a root.
/// The view on a bare kit (a DefaultKitApi, no shell), contributed by its
/// module with its placement hint: every tab shows its file's newest content,
/// the session selector switches the trail and the history pair, a missing
/// file is said, Todos lists the quest's todos, a file and a todo open
/// through the kit, a change through the file system refreshes the tab; on
/// disk, a change made outside the application is seen by the poll and a
/// large file shows its newest 256 KiB from the end it grows at.
@Timeout(Duration(seconds: 120))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tom_file_system/io.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_quests/tom_forge_quests.dart';
import 'package:tom_test_support/roots.dart';

const _ws = '/w';
const _quest = '$_ws/_ai/quests/demo';

/// The fixture: a quest folder and its trail bucket, laid out as a workspace
/// lays them out — `_ai/quests/<q>/` and `_ai/trail/anthropic/<q>/`.
/// `questions.demo.md` is missing on purpose.
Map<String, String> _fixture(String quest) => {
  '$quest/overview.demo.md': '# Demo overview\n',
  '$quest/progress.demo.md': '## 2026-10-12\n\n- progress line\n',
  '$quest/quest-notes.demo.md': 'the user notes\n',
  '$quest/quest_refresh.demo.md': '# Refresh\n',
  '$quest/quest_documentation_update.demo.md': '# Doc update\n',
  '$quest/deferred.demo.md': '- deferred step\n',
  '$quest/decisions.demo.md': '## decided\n',
  '$quest/live-trail.default.md':
      '<!-- tom-ai live-trail -->\n\n## PROMPT 20261012_140000\n\n'
      '> User: default run\n',
  '$quest/live-trail.chat.md':
      '<!-- tom-ai live-trail -->\n\n## PROMPT 20261012_140100\n\n'
      '> User: chat run\n',
  '$quest/live-trail.review.md':
      '<!-- tom-ai live-trail -->\n\n## PROMPT 20261012_140200\n\n'
      '> User: review run\n',
  '$quest/live-trail.md':
      '<!-- tom-ai live-trail -->\n\n## PROMPT 20261012_140300\n\n'
      '> User: extension run\n',
  '$quest/history/demo.chat.prompts.md': 'chat prompts\n',
  '$quest/history/demo.anthropic.prompts.md': 'extension prompts\n',
  '$quest/history/demo.anthropic.answers.md': 'extension answers\n',
  '$quest/todos.demo.todo.yaml': '''
quest: demo
todos:
  - id: qv1_ajlu-first
    title: Read the quest view
    description: A todo the aggregate lists.
    status: not-started
''',
  '${p.normalize(p.join(quest, '..', '..'))}/trail/anthropic/demo/'
          'current_prompt.chat.literal.md':
      'the literal prompt\n',
};

/// An editor host that is no layout: it records what it is asked to open.
class _Host implements ForgeEditorHost {
  final opened = <Uri>[];

  @override
  Future<void> showEditor(
    ForgeEditor editor, {
    bool focus = true,
    Object? placement,
  }) async {}

  @override
  Future<bool> closeEditor(ForgeEditor editor) async => true;

  @override
  void bringToFront(ForgeEditor editor) {}

  @override
  Future<ForgeEditor?> openEditorFor(Uri uri, {Object? placement}) async {
    opened.add(uri);
    return null;
  }
}

/// A kit state that knows the workspace folder.
class _State extends DefaultKitState implements ForgeWorkspaceRoot {
  @override
  String get workspaceRootPath => _ws;
}

/// A kit API that opens files at a position, as the panel shell's does.
class _NavigatingApi extends DefaultKitApi implements ForgeFileNavigator {
  _NavigatingApi({
    required super.editorHost,
    required super.fileSystem,
    super.state,
  });

  final positions = <(Uri, int?)>[];

  @override
  void openFileAt(Uri uri, {int? line, int? column}) =>
      positions.add((uri, line));
}

/// Lets the file system's futures and the view's rebuilds run.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

/// Runs real time (a disk file system's futures) between frames.
Future<void> _real(WidgetTester tester, [Future<void> Function()? work]) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump();
    await tester.runAsync(() async {
      if (i == 0) await work?.call();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
  }
  await tester.pump();
}

Future<void> _mount(WidgetTester tester, ForgeView view) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Builder(builder: view.buildMain)),
    ),
  );
}

String _shown(WidgetTester tester) {
  final source = find.byKey(const Key('forge-quest-source'));
  if (source.evaluate().isEmpty) return '';
  return tester.widget<SelectableText>(source).textSpan!.toPlainText();
}

Future<void> _tab(
  WidgetTester tester,
  ForgeQuestLogTab t, {
  bool real = false,
}) async {
  final strip = find.byKey(Key('forge-quest-tab-${t.name}'));
  await tester.ensureVisible(strip);
  await tester.pump();
  await tester.tap(strip);
  real ? await _real(tester) : await _settle(tester);
}

Future<void> _choose(WidgetTester tester, Key dropdown, String label) async {
  await tester.tap(find.byKey(dropdown));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.text(label).last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await _settle(tester);
}

void main() {
  group('the catalogue', () {
    test('FMODS4-C1: the Logs panel tabs in their order, plus Todos, each at '
        'the end its file grows at', () {
      expect(
        [for (final t in ForgeQuestLogTab.values) t.label],
        [
          'MD Trail',
          'Trail',
          'Prompts',
          'Answers',
          'Progress',
          'Overview',
          'Notes',
          'Refresh',
          'DocUpdate',
          'Deferred',
          'Questions',
          'Decisions',
          'Current Prompt',
          'Todos',
        ],
      );
      expect(
        [
          for (final t in ForgeQuestLogTab.values)
            if (t.newestAtEnd) t.name,
        ],
        ['mdTrail', 'trail', 'deferred', 'questions', 'decisions'],
      );
      expect(
        [
          for (final t in ForgeQuestLogTab.values)
            if (t.isSessionScoped) t.name,
        ],
        ['mdTrail', 'trail', 'prompts', 'answers'],
      );
      expect(forgeQuestLogMaxBytes, 256 * 1024);
    });

    test('FMODS4-C2: every file is relative to the quest folder; the '
        'extension session reads its single-file shape; Current Prompt reads '
        'the bucket', () {
      const q = '/w/quests/demo';
      String f(
        ForgeQuestLogTab t, {
        String session = 'default',
        ForgeCurrentPromptVariant? variant,
      }) => forgeQuestLogFile(
        q,
        t,
        session: session,
        variant: variant ?? forgeCurrentPromptVariants.first,
      )!.path;
      expect(f(ForgeQuestLogTab.mdTrail), '$q/live-trail.default.md');
      expect(
        f(ForgeQuestLogTab.trail, session: 'chat'),
        '$q/live-trail.chat.md',
      );
      expect(
        f(ForgeQuestLogTab.trail, session: forgeQuestExtensionSession),
        '$q/live-trail.md',
      );
      expect(
        f(ForgeQuestLogTab.prompts, session: 'chat'),
        '$q/history/demo.chat.prompts.md',
      );
      expect(
        f(ForgeQuestLogTab.answers, session: forgeQuestExtensionSession),
        '$q/history/demo.anthropic.answers.md',
      );
      expect(f(ForgeQuestLogTab.progress), '$q/progress.demo.md');
      expect(f(ForgeQuestLogTab.notes), '$q/quest-notes.demo.md');
      expect(f(ForgeQuestLogTab.refresh), '$q/quest_refresh.demo.md');
      expect(
        f(ForgeQuestLogTab.docUpdate),
        '$q/quest_documentation_update.demo.md',
      );
      expect(f(ForgeQuestLogTab.questions), '$q/questions.demo.md');
      expect(
        f(
          ForgeQuestLogTab.currentPrompt,
          variant: const ForgeCurrentPromptVariant(
            ForgeCurrentPromptSource.queue,
            ForgeCurrentPromptPart.system,
          ),
        ),
        '/w/trail/anthropic/demo/current_prompt.queue.system.md',
      );
      expect(forgeQuestLogFile(q, ForgeQuestLogTab.todos), isNull);
      expect(
        [for (final v in forgeCurrentPromptVariants) v.label],
        [
          'Chat Literal Prompt',
          'Chat User Prompt',
          'Chat System Prompt',
          'Queue Literal Prompt',
          'Queue User Prompt',
          'Queue System Prompt',
        ],
      );
    });

    test('FMODS4-C3: the sessions: chat and default always, others that have '
        'files, then the extension\'s', () {
      expect(
        forgeQuestSessions(
          'demo',
          folder: ['live-trail.review.md', 'live-trail.md', 'x.md'],
          history: [
            'demo.planning.answers.md',
            'demo.anthropic.prompts.md',
            'other.zzz.prompts.md',
            'demo.chat.prompts.md',
          ],
        ),
        ['chat', 'default', 'planning', 'review', '(extension)'],
      );
      expect(forgeQuestSessions('demo', folder: [], history: []), [
        'chat',
        'default',
      ]);
    });

    test('FMODS4-C4: a quest session\'s trail and history pair are where the '
        'view reads them, and the selector lists the session', () async {
      const garden = '/r/quests/garden';
      final fs = TomMemoryFileSystem(
        seed: {
          '$garden/overview.garden.md': '# garden\n',
          '$garden/live-trail.research.md': '> User: Plan it.\n',
          '$garden/history/garden.research.prompts.md': '=== PROMPT r1\n',
          '$garden/history/garden.research.answers.md': 'A plan.\n',
        },
      );
      Future<List<String>> names(String dir) async => [
        for (final e in await fs.list(Uri.directory(dir))) e.name,
      ];
      expect(
        forgeQuestSessions(
          'garden',
          folder: await names(garden),
          history: await names('$garden/history'),
        ),
        contains('research'),
      );
      for (final (tab, text) in [
        (ForgeQuestLogTab.mdTrail, '> User: Plan it.'),
        (ForgeQuestLogTab.prompts, '=== PROMPT r1'),
        (ForgeQuestLogTab.answers, 'A plan.'),
      ]) {
        final file = forgeQuestLogFile(garden, tab, session: 'research')!;
        expect(await fs.readText(file.uri), contains(text), reason: tab.name);
      }
    });

    test('FMODS4-C5: quest folders are found under a root, not inside a '
        'quest, a hidden folder, history or node_modules, nor past the '
        'depth', () async {
      Map<String, String> quest(String path) => {
        '/r/$path/overview.${p.basename(path)}.md': '#\n',
      };
      final fs = TomMemoryFileSystem(
        seed: {
          ...quest('notes/quests/garden'),
          ...quest('notes/quests/kitchen'),
          ...quest('notes/quests/garden/sub'),
          ...quest('.hidden/quests/secret'),
          ...quest('node_modules/pkg'),
          ...quest('a/b/c/d/e/deep'),
        },
      );
      expect(await forgeQuestFoldersUnder(fs, ['/r', '/missing']), [
        '/r/notes/quests/garden',
        '/r/notes/quests/kitchen',
      ]);
      expect(await forgeIsQuestShaped(fs, '/r/notes/quests/garden'), isTrue);
      expect(await forgeIsQuestShaped(fs, '/r/notes'), isFalse);
    });

    test('FMODS4-C6: the folder file system sees one folder of the '
        'application\'s: paths relative to it, nothing outside', () async {
      final fs = TomMemoryFileSystem(seed: _fixture(_quest));
      final tree = ForgeFolderFileSystem(fs, _quest);
      expect(tree.root, Uri.directory(_quest));
      expect(tree.pathOf(Uri.file('$_quest/history/x.md')), 'history/x.md');
      expect(tree.pathOf(Uri.file('/w/_ai/trail/x.md')), isNull);
      final names = [for (final e in await tree.list(tree.root)) e.path]
        ..sort();
      expect(names, contains('history'));
      expect(names, contains('todos.demo.todo.yaml'));
      expect(
        await tree.readText(tree.uriOf('history/demo.chat.prompts.md')),
        'chat prompts\n',
      );
      final changes = <String>[];
      final sub = tree.watch()!.listen((c) => changes.add(c.path));
      await fs.writeText(Uri.file('$_quest/new.md'), 'x');
      await fs.writeText(Uri.file('/w/_ai/elsewhere.md'), 'y');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(changes, ['new.md']);
    });
  });

  group('the view on a bare kit', () {
    late TomMemoryFileSystem fs;
    late _Host host;
    late _NavigatingApi api;
    late ForgeQuestView view;

    Future<void> open(WidgetTester tester) async {
      fs = TomMemoryFileSystem(seed: _fixture(_quest));
      host = _Host();
      api = _NavigatingApi(editorHost: host, fileSystem: fs, state: _State());
      final module = ForgeQuestViewModule(
        quest: 'demo',
        pollInterval: Duration.zero,
      );
      api.registerModule(module);
      final contributed = forgeContributedViews(api.modules).single;
      expect(contributed.hint, same(forgeQuestViewPlacement));
      expect(contributed.hint!.role, ForgeViewRole.messages);
      view =
          forgeContributedViewById(api.modules, forgeQuestViewId)!
              as ForgeQuestView;
      expect(view, same(module.view));
      expect(view.quest, _quest);
      expect(view.title.value, 'Quest: demo');
      await _mount(tester, view);
      await _settle(tester);
    }

    testWidgets('FMODS4-V1: the trail per session, the extension\'s shape, '
        'prompts and answers; the selector switches', (tester) async {
      await open(tester);
      // MD Trail, rendered, session default.
      expect(
        find.textContaining('default run', findRichText: true),
        findsWidgets,
      );

      await _tab(tester, ForgeQuestLogTab.trail);
      expect(_shown(tester), contains('> User: default run'));
      await tester.tap(find.byKey(const Key('forge-quest-session')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      for (final s in ['chat', 'default', 'review', '(extension)']) {
        expect(find.text(s), findsWidgets, reason: s);
      }
      await tester.tap(find.text('chat').last);
      await tester.pump(const Duration(milliseconds: 500));
      await _settle(tester);
      expect(_shown(tester), contains('> User: chat run'));
      await _choose(tester, const Key('forge-quest-session'), '(extension)');
      expect(_shown(tester), contains('> User: extension run'));

      await _tab(tester, ForgeQuestLogTab.prompts);
      expect(_shown(tester), 'extension prompts\n');
      await _tab(tester, ForgeQuestLogTab.answers);
      expect(_shown(tester), 'extension answers\n');
      await _choose(tester, const Key('forge-quest-session'), 'chat');
      expect(
        find.text('demo.chat.answers.md does not exist yet.'),
        findsOneWidget,
      );
      await _tab(tester, ForgeQuestLogTab.prompts);
      expect(_shown(tester), 'chat prompts\n');
      // A tab without sessions has no selector.
      await _tab(tester, ForgeQuestLogTab.overview);
      expect(find.byKey(const Key('forge-quest-session')), findsNothing);
    });

    testWidgets('FMODS4-V2: every quest document in its tab; a missing one '
        'said; Current Prompt by variant; Todos; a file and a todo open '
        'through the kit', (tester) async {
      await open(tester);
      final expected = {
        ForgeQuestLogTab.progress: '- progress line',
        ForgeQuestLogTab.overview: '# Demo overview',
        ForgeQuestLogTab.notes: 'the user notes',
        ForgeQuestLogTab.refresh: '# Refresh',
        ForgeQuestLogTab.docUpdate: '# Doc update',
        ForgeQuestLogTab.deferred: '- deferred step',
        ForgeQuestLogTab.decisions: '## decided',
      };
      for (final e in expected.entries) {
        await _tab(tester, e.key);
        expect(_shown(tester), contains(e.value), reason: e.key.name);
      }
      await _tab(tester, ForgeQuestLogTab.questions);
      expect(
        find.text('questions.demo.md does not exist yet.'),
        findsOneWidget,
      );
      // A missing file cannot be opened; every tab stays.
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('forge-quest-open-file')))
            .onPressed,
        isNull,
      );
      expect(find.byKey(const Key('forge-quest-tab-todos')), findsOneWidget);

      await _tab(tester, ForgeQuestLogTab.currentPrompt);
      expect(_shown(tester), 'the literal prompt\n');
      await _choose(
        tester,
        const Key('forge-quest-variant'),
        'Queue System Prompt',
      );
      expect(
        find.text('current_prompt.queue.system.md does not exist yet.'),
        findsOneWidget,
      );

      await _tab(tester, ForgeQuestLogTab.todos);
      await _settle(tester);
      expect(find.textContaining('Read the quest view'), findsWidgets);
      await tester.tap(
        find.byKey(const Key('tom-todo-aggregate-row-qv1_ajlu-first')),
      );
      await _settle(tester);
      expect(api.positions.single, (
        Uri.file('$_quest/todos.demo.todo.yaml'),
        // `  - id: qv1_ajlu-first`, the file's third line (0-based 2).
        2,
      ));

      await _tab(tester, ForgeQuestLogTab.progress);
      await tester.tap(find.byKey(const Key('forge-quest-open-file')));
      await _settle(tester);
      expect(api.positions.last, (Uri.file('$_quest/progress.demo.md'), null));
      // Opened through the application's navigator, not its editor host.
      expect(host.opened, isEmpty);
    });

    testWidgets('FMODS4-V3: a change made through the file system refreshes '
        'the tab; a file that appears is shown', (tester) async {
      await open(tester);
      await _tab(tester, ForgeQuestLogTab.deferred);
      expect(_shown(tester), '- deferred step\n');
      await fs.writeText(
        Uri.file('$_quest/deferred.demo.md'),
        '- deferred step\n- the newest step\n',
      );
      await _settle(tester);
      expect(_shown(tester), endsWith('- the newest step\n'));

      await _tab(tester, ForgeQuestLogTab.questions);
      expect(find.byKey(const Key('forge-quest-missing')), findsOneWidget);
      await fs.writeText(Uri.file('$_quest/questions.demo.md'), '## Q-1\n');
      await _settle(tester);
      expect(_shown(tester), '## Q-1\n');

      // A new session's trail joins the selector.
      await fs.writeText(Uri.file('$_quest/live-trail.zeta.md'), 'z\n');
      await _tab(tester, ForgeQuestLogTab.trail);
      await _choose(tester, const Key('forge-quest-session'), 'zeta');
      expect(_shown(tester), 'z\n');
    });

    testWidgets('FMODS4-V4: no trail bucket — Current Prompt says so and stays '
        'in its place', (tester) async {
      await open(tester);
      await fs.delete(Uri.directory('/w/_ai/trail'));
      await _tab(tester, ForgeQuestLogTab.currentPrompt);
      expect(
        find.textContaining('This quest has no trail bucket yet'),
        findsOneWidget,
      );
    });
  });

  group('the view on disk', () {
    late Directory base;
    setUp(() {
      base = tomWorkspaceZtmp().createTempSync('forgemods4_quest_view_');
      for (final e in _fixture(p.join(base.path, '_ai/quests/demo')).entries) {
        File(e.key)
          ..createSync(recursive: true)
          ..writeAsStringSync(e.value);
      }
    });
    tearDown(() {
      if (base.existsSync()) base.deleteSync(recursive: true);
    });

    testWidgets('FMODS4-D1: a change outside the application is seen by the '
        'poll; a large file shows its newest 256 KiB from its growing end; '
        'Open file goes to the kit\'s openFile', (tester) async {
      final quest = p.join(base.path, '_ai', 'quests', 'demo');
      final host = _Host();
      final api = DefaultKitApi(
        editorHost: host,
        fileSystem: TomLocalFileSystem(base.path),
      );
      final view = ForgeQuestView.forApi(
        api,
        quest: quest,
        pollInterval: const Duration(milliseconds: 100),
      );
      await _mount(tester, view);
      await _real(tester);
      await _tab(tester, ForgeQuestLogTab.deferred, real: true);
      expect(_shown(tester), '- deferred step\n');

      final big = StringBuffer();
      for (var i = 0; big.length < 300 * 1024; i++) {
        big.writeln('- deferred step number $i, with some padding to grow');
      }
      big.writeln('- the newest step');
      await _real(
        tester,
        () => File(
          p.join(quest, 'deferred.demo.md'),
        ).writeAsString(big.toString()),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await _real(tester);
      final text = _shown(tester);
      expect(text, endsWith('- the newest step\n'));
      expect(text, startsWith('- deferred step number '));
      expect(text, isNot(contains('number 0,')));
      expect(
        tester.widget<Text>(find.byKey(const Key('forge-quest-file'))).data,
        startsWith('deferred.demo.md — the newest 256 KiB of '),
      );

      await tester.tap(find.byKey(const Key('forge-quest-open-file')));
      await _real(tester);
      expect(host.opened, [Uri.file(p.join(quest, 'deferred.demo.md'))]);
      // Unmount, so the view's poll stops with it.
      await tester.pumpWidget(const SizedBox());
    });
  });
}

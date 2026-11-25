/// Which file each tab of the quest view shows.
///
/// The catalogue is the VS Code extension's Logs panel's — the same tabs in
/// the same order, with the same end each file's newest content is at — plus
/// Todos. Every name is relative to the quest folder; the one path that
/// reaches outside it is the trail bucket, `../../trail/anthropic/<q>/`, a
/// pattern rather than a named folder.
///
/// Pure, so the mapping is pinned down by tests without a file system — but
/// for [forgeQuestFoldersUnder], which walks one.
library;

import 'package:path/path.dart' as p;
import 'package:tom_file_system/tom_file_system.dart';

/// How a tab presents its file.
enum ForgeQuestLogPresentation {
  /// Through the Markdown renderer.
  rendered,

  /// As highlighted Markdown source.
  source,

  /// The todo aggregate over the quest folder, not a file.
  todos,
}

/// One tab of the quest view.
enum ForgeQuestLogTab {
  mdTrail('MD Trail', ForgeQuestLogPresentation.rendered, newestAtEnd: true),
  trail('Trail', ForgeQuestLogPresentation.source, newestAtEnd: true),
  prompts('Prompts', ForgeQuestLogPresentation.source),
  answers('Answers', ForgeQuestLogPresentation.source),
  progress('Progress', ForgeQuestLogPresentation.source),
  overview('Overview', ForgeQuestLogPresentation.source),
  notes('Notes', ForgeQuestLogPresentation.source),
  refresh('Refresh', ForgeQuestLogPresentation.source),
  docUpdate('DocUpdate', ForgeQuestLogPresentation.source),
  deferred('Deferred', ForgeQuestLogPresentation.source, newestAtEnd: true),
  questions('Questions', ForgeQuestLogPresentation.source, newestAtEnd: true),
  decisions('Decisions', ForgeQuestLogPresentation.source, newestAtEnd: true),
  currentPrompt('Current Prompt', ForgeQuestLogPresentation.source),
  todos('Todos', ForgeQuestLogPresentation.todos);

  /// The label in the tab strip.
  final String label;

  final ForgeQuestLogPresentation presentation;

  /// Whether the file grows at its end — the trail and the three journals —
  /// rather than being rewritten or prepended to. A tab reads its slice from
  /// that end and opens scrolled to it.
  final bool newestAtEnd;

  const ForgeQuestLogTab(
    this.label,
    this.presentation, {
    this.newestAtEnd = false,
  });

  /// Whether the session selector applies.
  bool get isSessionScoped =>
      this == mdTrail || this == trail || this == prompts || this == answers;
}

/// How much of a file a tab reads: its newest 256 KiB.
const int forgeQuestLogMaxBytes = 256 * 1024;

/// The session the extension's single-file shape is offered as.
const String forgeQuestExtensionSession = '(extension)';

/// The sessions every quest view offers, whether or not they have files yet.
const List<String> forgeQuestBuiltInSessions = ['chat', 'default'];

/// Which running prompt a Current Prompt file belongs to — the extension's
/// `PromptSource`.
enum ForgeCurrentPromptSource { chat, queue }

/// Which of a prompt's three texts.
enum ForgeCurrentPromptPart { literal, user, system }

/// One Current Prompt choice: a source crossed with a part.
class ForgeCurrentPromptVariant {
  final ForgeCurrentPromptSource source;
  final ForgeCurrentPromptPart part;

  const ForgeCurrentPromptVariant(this.source, this.part);

  /// "Chat Literal Prompt", as the extension labels it.
  String get label {
    String cap(String s) => '${s[0].toUpperCase()}${s.substring(1)}';
    return '${cap(source.name)} ${cap(part.name)} Prompt';
  }

  /// The file in the trail bucket.
  String get fileName => 'current_prompt.${source.name}.${part.name}.md';

  @override
  bool operator ==(Object other) =>
      other is ForgeCurrentPromptVariant &&
      other.source == source &&
      other.part == part;

  @override
  int get hashCode => Object.hash(source, part);
}

/// The six choices, in the extension's order.
final List<ForgeCurrentPromptVariant> forgeCurrentPromptVariants = [
  for (final source in ForgeCurrentPromptSource.values)
    for (final part in ForgeCurrentPromptPart.values)
      ForgeCurrentPromptVariant(source, part),
];

/// Where a tab's file is: a folder (absolute) and a name in it.
class ForgeQuestLogFile {
  final String directory;
  final String name;

  const ForgeQuestLogFile(this.directory, this.name);

  /// The file's absolute path.
  String get path => p.join(directory, name);

  /// The file's absolute URI.
  Uri get uri => Uri.file(path);

  @override
  bool operator ==(Object other) =>
      other is ForgeQuestLogFile &&
      other.directory == directory &&
      other.name == name;

  @override
  int get hashCode => Object.hash(directory, name);

  @override
  String toString() => path;
}

/// The quest's trail bucket: `../../trail/anthropic/<q>/` from the quest
/// folder [quest] (absolute).
String forgeQuestTrailBucket(String quest) => p.normalize(
  p.join(quest, '..', '..', 'trail', 'anthropic', p.basename(quest)),
);

/// The file [tab] shows for the quest folder [quest] (absolute), in [session]
/// for a session-scoped tab and [variant] for Current Prompt; null for Todos,
/// which shows no one file.
ForgeQuestLogFile? forgeQuestLogFile(
  String quest,
  ForgeQuestLogTab tab, {
  String session = 'default',
  ForgeCurrentPromptVariant variant = const ForgeCurrentPromptVariant(
    ForgeCurrentPromptSource.chat,
    ForgeCurrentPromptPart.literal,
  ),
}) {
  final q = p.basename(quest);
  final history = p.join(quest, 'history');
  final extension = session == forgeQuestExtensionSession;
  // The extension's summary pair is its Anthropic subsystem's.
  final historySession = extension ? 'anthropic' : session;
  return switch (tab) {
    ForgeQuestLogTab.mdTrail || ForgeQuestLogTab.trail => ForgeQuestLogFile(
      quest,
      extension ? 'live-trail.md' : 'live-trail.$session.md',
    ),
    ForgeQuestLogTab.prompts => ForgeQuestLogFile(
      history,
      '$q.$historySession.prompts.md',
    ),
    ForgeQuestLogTab.answers => ForgeQuestLogFile(
      history,
      '$q.$historySession.answers.md',
    ),
    ForgeQuestLogTab.progress => ForgeQuestLogFile(quest, 'progress.$q.md'),
    ForgeQuestLogTab.overview => ForgeQuestLogFile(quest, 'overview.$q.md'),
    ForgeQuestLogTab.notes => ForgeQuestLogFile(quest, 'quest-notes.$q.md'),
    ForgeQuestLogTab.refresh => ForgeQuestLogFile(quest, 'quest_refresh.$q.md'),
    ForgeQuestLogTab.docUpdate => ForgeQuestLogFile(
      quest,
      'quest_documentation_update.$q.md',
    ),
    ForgeQuestLogTab.deferred => ForgeQuestLogFile(quest, 'deferred.$q.md'),
    ForgeQuestLogTab.questions => ForgeQuestLogFile(quest, 'questions.$q.md'),
    ForgeQuestLogTab.decisions => ForgeQuestLogFile(quest, 'decisions.$q.md'),
    ForgeQuestLogTab.currentPrompt => ForgeQuestLogFile(
      forgeQuestTrailBucket(quest),
      variant.fileName,
    ),
    ForgeQuestLogTab.todos => null,
  };
}

final RegExp _liveTrail = RegExp(r'^live-trail\.([A-Za-z0-9_.-]+)\.md$');

/// The sessions the selector lists for the quest [questName], given the names
/// in the quest folder ([folder]) and in its `history/` subfolder
/// ([history]): `chat`, `default`, every other session that has a file, then
/// the extension's when its files exist.
List<String> forgeQuestSessions(
  String questName, {
  required Iterable<String> folder,
  required Iterable<String> history,
}) {
  final found = <String>{};
  var extension = false;
  for (final name in folder) {
    if (name == 'live-trail.md') {
      extension = true;
      continue;
    }
    final match = _liveTrail.firstMatch(name);
    if (match != null) found.add(match.group(1)!);
  }
  final prefix = '$questName.';
  for (final name in history) {
    if (!name.startsWith(prefix)) continue;
    for (final suffix in const ['.prompts.md', '.answers.md']) {
      if (!name.endsWith(suffix)) continue;
      final session = name.substring(
        prefix.length,
        name.length - suffix.length,
      );
      if (session.isEmpty || session.contains('/')) continue;
      if (session == 'anthropic') {
        extension = true;
      } else {
        found.add(session);
      }
    }
  }
  return [
    ...forgeQuestBuiltInSessions,
    ...(found.difference(forgeQuestBuiltInSessions.toSet()).toList()..sort()),
    if (extension) forgeQuestExtensionSession,
  ];
}

/// Folders a walk for quest folders never enters: package and build output,
/// and a quest's own history and trail.
const Set<String> _notQuestHomes = {
  'node_modules',
  'build',
  'history',
  'trail',
};

/// The quest folders (a folder holding `overview.<folder>.md`) under each of
/// [roots] (absolute paths), as absolute paths, read through [fileSystem]. A
/// bounded walk: at most [maxDepth] folders deep and [maxFolders] folders in
/// all, never into a hidden folder or one of `node_modules`, `build`,
/// `history`, `trail`, and not below a quest folder once found.
Future<List<String>> forgeQuestFoldersUnder(
  TomFileSystem fileSystem,
  Iterable<String> roots, {
  int maxDepth = 4,
  int maxFolders = 5000,
}) async {
  final found = <String>{};
  var seen = 0;
  for (final root in roots) {
    final rootPath = p.normalize(root);
    if (!await fileSystem.exists(Uri.directory(rootPath))) continue;
    final queue = <(String, int)>[(rootPath, 0)];
    while (queue.isNotEmpty && seen < maxFolders) {
      final (dir, depth) = queue.removeAt(0);
      seen++;
      if (dir != rootPath && await forgeIsQuestShaped(fileSystem, dir)) {
        found.add(dir);
        continue;
      }
      if (depth >= maxDepth) continue;
      final List<TomFileEntry> entries;
      try {
        entries = await fileSystem.list(Uri.directory(dir));
      } on Object {
        continue;
      }
      for (final entry in entries) {
        if (!entry.isDirectory || entry.kind == TomFileEntryKind.link) {
          continue;
        }
        if (entry.name.startsWith('.') || _notQuestHomes.contains(entry.name)) {
          continue;
        }
        queue.add((p.join(dir, entry.name), depth + 1));
      }
    }
  }
  return found.toList()..sort();
}

/// Whether the folder [folder] (absolute) is quest-shaped: it holds
/// `overview.<its name>.md`.
Future<bool> forgeIsQuestShaped(TomFileSystem fileSystem, String folder) =>
    fileSystem.exists(
      Uri.file(p.join(folder, 'overview.${p.basename(folder)}.md')),
    );

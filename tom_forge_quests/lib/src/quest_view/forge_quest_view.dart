/// The quest view: a quest folder's AI files in one view, modeled on the VS
/// Code extension's Logs panel, as a kit component.
///
/// Every read goes through the application's file system: the quest folder
/// for its files and its `history/` pair, and the trail bucket for Current
/// Prompt — the one path that reaches outside the folder. A tab reads only
/// the newest 256 KiB ([forgeQuestLogMaxBytes]), from the end its file grows
/// at, and the view looks again every [ForgeQuestViewController.pollInterval],
/// whenever the file system reports a change in the quest folder or the
/// bucket, and (with `watch`) whenever its watch does — re-reading a file only
/// when its size or its modification time moved.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:tom_file_editors/tom_file_editors.dart'
    show TomMarkdownRendered, tomMarkdownHighlight;
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_todo_ui/tom_todo_ui.dart' show TomTodoAggregateView;

import '../quests_trail.dart';
import 'forge_quest_files.dart';
import 'forge_quest_todo_source.dart';

/// The quest view's state: the tab, the session, the Current Prompt variant,
/// and the file shown.
class ForgeQuestViewController extends ChangeNotifier {
  ForgeQuestViewController({
    required this.fileSystem,
    required String quest,
    this.pollInterval = const Duration(seconds: 2),
    this.watch = false,
  }) : quest = p.normalize(quest);

  /// Where every file is read: the application's file system, addressed
  /// with absolute URIs.
  final TomFileSystem fileSystem;

  /// The quest folder, absolute.
  final String quest;

  /// How often the view looks for a changed file; [Duration.zero] never.
  final Duration pollInterval;

  /// Whether the view also watches the quest folder and the trail bucket
  /// through [TomFileSystem.watch] (a native watch of the file system's
  /// root, on some platforms); the changes made through [fileSystem] are
  /// seen either way ([TomFileSystem.onDidChange]).
  final bool watch;

  Timer? _timer;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _disposed = false;

  ForgeQuestLogTab _tab = ForgeQuestLogTab.mdTrail;
  String _session = 'default';
  ForgeCurrentPromptVariant _variant = forgeCurrentPromptVariants.first;
  List<String> _sessions = forgeQuestBuiltInSessions;
  bool _bucketExists = false;

  String? _text;
  bool _loaded = false;
  int? _size;
  String? _shownKey;

  /// The quest's name — the folder's.
  String get name => p.basename(quest);

  /// The quest's trail bucket, absolute.
  String get bucket => forgeQuestTrailBucket(quest);

  ForgeQuestLogTab get tab => _tab;
  String get session => _session;
  ForgeCurrentPromptVariant get variant => _variant;

  /// The sessions the selector offers.
  List<String> get sessions => _sessions;

  /// Whether the quest's trail bucket exists.
  bool get bucketExists => _bucketExists;

  /// The file the tab shows, or null for Todos.
  ForgeQuestLogFile? get file =>
      forgeQuestLogFile(quest, _tab, session: _session, variant: _variant);

  /// The text shown: the file's newest 256 KiB, or null when it does not
  /// exist (or has not been read yet — see [loaded]).
  String? get text => _text;

  /// Whether the current file has been read at least once.
  bool get loaded => _loaded;

  /// Whether the file is larger than what is shown.
  bool get truncated => (_size ?? 0) > forgeQuestLogMaxBytes;

  /// The file's size in bytes, when it exists.
  int? get size => _size;

  /// Starts reading and looking for changes.
  void start() {
    unawaited(refresh());
    if (pollInterval > Duration.zero) {
      _timer ??= Timer.periodic(pollInterval, (_) => unawaited(refresh()));
    }
    if (_subscriptions.isNotEmpty) return;
    _subscriptions.add(
      fileSystem.onDidChange
          .where((event) => _concerns(event.uri))
          .listen((_) => unawaited(refresh())),
    );
    if (watch) {
      for (final folder in [quest, bucket]) {
        final changes = ForgeFolderFileSystem(fileSystem, folder).watch();
        if (changes != null) {
          _subscriptions.add(changes.listen((_) => unawaited(refresh())));
        }
      }
    }
    questsTrailEvent('quest view: started over $quest');
  }

  /// Whether a change at [uri] can concern what the view shows.
  bool _concerns(Uri uri) {
    final path = p.normalize(uri.toFilePath());
    return path == quest ||
        p.isWithin(quest, path) ||
        path == bucket ||
        p.isWithin(bucket, path);
  }

  void selectTab(ForgeQuestLogTab tab) {
    if (_tab == tab) return;
    _tab = tab;
    questsTrailEvent('quest view: tab ${tab.name}');
    _reset();
  }

  void selectSession(String session) {
    if (_session == session) return;
    _session = session;
    questsTrailEvent('quest view: session $session');
    if (_tab.isSessionScoped) _reset();
    notifyListeners();
  }

  void selectVariant(ForgeCurrentPromptVariant variant) {
    if (_variant == variant) return;
    _variant = variant;
    if (_tab == ForgeQuestLogTab.currentPrompt) _reset();
    notifyListeners();
  }

  void _reset() {
    _text = null;
    _loaded = false;
    _size = null;
    _shownKey = null;
    notifyListeners();
    unawaited(refresh());
  }

  /// Looks at the sessions, the bucket and the current file, and re-reads the
  /// file when it changed.
  Future<void> refresh() async {
    if (_disposed) return;
    final sessions = forgeQuestSessions(
      name,
      folder: await _names(quest),
      history: await _names(p.join(quest, 'history')),
    );
    final bucketExists = await _stat(Uri.directory(bucket)) != null;
    if (_disposed) return;
    var changed = false;
    if (!listEquals(sessions, _sessions)) {
      _sessions = sessions;
      changed = true;
    }
    if (bucketExists != _bucketExists) {
      _bucketExists = bucketExists;
      changed = true;
    }
    final file = this.file;
    if (file != null) {
      final entry = await _stat(file.uri);
      final key = entry == null
          ? 'missing:$file'
          : '$file:${entry.size}:${entry.modified.microsecondsSinceEpoch}';
      if (key != _shownKey || !_loaded) {
        String? text;
        if (entry != null) {
          try {
            text = await fileSystem.readSlice(
              file.uri,
              maxBytes: forgeQuestLogMaxBytes,
              fromEnd: _tab.newestAtEnd,
            );
          } on Object {
            text = null;
          }
        }
        // The selection may have moved while the file was read.
        if (_disposed || file != this.file) return;
        _text = text;
        _size = text == null ? null : entry?.size;
        _loaded = true;
        _shownKey = key;
        changed = true;
        questsTrailEvent(
          'quest view: read ${file.name} '
          '(${text == null ? 'missing' : '${entry!.size} bytes'})',
        );
      }
    }
    if (changed && !_disposed) notifyListeners();
  }

  Future<TomFileEntry?> _stat(Uri uri) async {
    try {
      return await fileSystem.stat(uri);
    } on Object {
      return null;
    }
  }

  Future<List<String>> _names(String directory) async {
    try {
      final entries = await fileSystem.list(Uri.directory(directory));
      return [for (final e in entries) e.name];
    } on Object {
      return const [];
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}

/// The quest view over the quest folder [quest]: the Logs panel's tabs — MD
/// Trail, Trail, Prompts, Answers, Progress, Overview, Notes, Refresh,
/// DocUpdate, Deferred, Questions, Decisions, Current Prompt — and Todos,
/// with the session selector, each tab showing the newest part of its file
/// and saying when the file is missing, *Open file* opening it through
/// [openFile].
///
/// A kit component: any application on the kit shows it
/// ([ForgeQuestView.forApi]); `ForgeQuestViewModule` contributes it.
class ForgeQuestView extends ForgeView {
  ForgeQuestView({
    required this.fileSystem,
    required this.openFile,
    required String quest,
    this.pollInterval = const Duration(seconds: 2),
    this.watch = false,
  }) : quest = p.normalize(quest),
       _title = ValueNotifier('Quest: ${p.basename(quest)}');

  /// The view over [api] showing the quest folder [quest] (absolute): its
  /// file system, opening files through the application's
  /// [ForgeFileNavigator] ([forgeOpenFileAtOf]).
  factory ForgeQuestView.forApi(
    ForgeKitApi api, {
    required String quest,
    Duration pollInterval = const Duration(seconds: 2),
    bool watch = false,
  }) => ForgeQuestView(
    fileSystem: api.fileSystem,
    openFile: forgeOpenFileAtOf(api),
    quest: quest,
    pollInterval: pollInterval,
    watch: watch,
  );

  /// Where the quest's files are read.
  final TomFileSystem fileSystem;

  /// Opens the file shown (*Open file*) and a todo picked in Todos.
  final ForgeOpenFileAt openFile;

  /// The quest folder, absolute.
  final String quest;

  /// How often the view looks for a changed file ([ForgeQuestViewController]).
  final Duration pollInterval;

  /// Whether the view watches the quest folder and the trail bucket
  /// ([ForgeQuestViewController.watch]).
  final bool watch;

  final ValueNotifier<String> _title;
  final _titleExtension = ValueNotifier<String?>(null);

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => Icons.flag_outlined;

  @override
  ForgeComponentSizeHints get sizeHints =>
      const ForgeComponentSizeHints(preferredSize: Size(640, 420));

  @override
  Widget buildMain(BuildContext context) =>
      ForgeQuestViewBody(key: ValueKey('forge-quest-view-$quest'), view: this);

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

/// The quest view's content: a [ForgeQuestViewController] of its own over
/// [view]'s quest.
class ForgeQuestViewBody extends StatefulWidget {
  const ForgeQuestViewBody({super.key, required this.view});

  final ForgeQuestView view;

  @override
  State<ForgeQuestViewBody> createState() => _QuestViewState();
}

class _QuestViewState extends State<ForgeQuestViewBody> {
  late final ForgeQuestViewController _controller;
  late final ForgeQuestTodoSource _todos;
  final ScrollController _scroll = ScrollController();
  String? _scrolledFor;

  ForgeQuestView get _view => widget.view;

  @override
  void initState() {
    super.initState();
    _controller = ForgeQuestViewController(
      fileSystem: _view.fileSystem,
      quest: _view.quest,
      pollInterval: _view.pollInterval,
      watch: _view.watch,
    )..start();
    _todos = ForgeQuestTodoSource(
      fileSystem: _view.fileSystem,
      quest: _view.quest,
      openFile: _view.openFile,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Opens the shown file in the application's editor.
  void _openFile(ForgeQuestLogFile file) {
    questsTrailEvent('quest view: open file ${file.path}');
    _view.openFile(file.uri);
  }

  /// Scrolls to the end the file's newest content is at, once per file shown.
  void _scrollToNewest() {
    final key = '${_controller.file}:${_controller.size}';
    if (_scrolledFor == key) return;
    _scrolledFor = key;
    final atEnd = _controller.tab.newestAtEnd;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final position = _scroll.position;
      _scroll.jumpTo(atEnd ? position.maxScrollExtent : 0);
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => Column(
      key: const Key('forge-quest-view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TabStrip(controller: _controller),
        _Toolbar(controller: _controller, onOpen: _openFile),
        const Divider(height: 1),
        Expanded(child: _body(context)),
      ],
    ),
  );

  /// An image a quest document names, read through the file system.
  Future<Uint8List?> _image(ForgeQuestLogFile file, String src) async {
    final path = p.isAbsolute(src)
        ? src
        : p.normalize(p.join(file.directory, src));
    final uri = Uri.file(path);
    final fs = _view.fileSystem;
    if (await fs.stat(uri) == null) return null;
    return (await fs.read(uri)).bytes;
  }

  Widget _body(BuildContext context) {
    final c = _controller;
    final theme = Theme.of(context);
    if (c.tab == ForgeQuestLogTab.todos) {
      return TomTodoAggregateView(
        key: ValueKey('forge-quest-todos-${c.quest}'),
        source: _todos,
      );
    }
    if (!c.loaded) return const Center(child: CircularProgressIndicator());
    final file = c.file!;
    final text = c.text;
    if (text == null) {
      final bucketMissing =
          c.tab == ForgeQuestLogTab.currentPrompt && !c.bucketExists;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            bucketMissing
                ? 'This quest has no trail bucket yet: '
                      '${p.dirname(file.path)} does not exist. The VS Code '
                      'extension writes the current prompt there.'
                : '${file.name} does not exist yet.',
            key: const Key('forge-quest-missing'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }
    _scrollToNewest();
    if (c.tab.presentation == ForgeQuestLogPresentation.rendered) {
      return TomMarkdownRendered(
        key: ValueKey('forge-quest-rendered-$file'),
        markdown: text,
        images: (src) => _image(file, src),
        controller: _scroll,
      );
    }
    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      height: 1.4,
    );
    return SingleChildScrollView(
      key: ValueKey('forge-quest-source-$file'),
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SelectableText.rich(
        TextSpan(
          style: mono,
          children: tomMarkdownHighlight(text, theme.colorScheme),
        ),
        key: const Key('forge-quest-source'),
      ),
    );
  }
}

/// The tab strip, in the Logs panel's order.
class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.controller});

  final ForgeQuestViewController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainer,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final tab in ForgeQuestLogTab.values)
              InkWell(
                key: Key('forge-quest-tab-${tab.name}'),
                onTap: () => controller.selectTab(tab),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: 2,
                        color: controller.tab == tab
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Text(
                    tab.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: controller.tab == tab
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The toolbar: the quest, the session or variant selector the tab uses,
/// what is shown of the file, and *Open file*.
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller, required this.onOpen});

  final ForgeQuestViewController controller;
  final ValueChanged<ForgeQuestLogFile> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = controller;
    final file = c.file;
    final style = theme.textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        children: [
          Icon(Icons.flag_outlined, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(c.name, style: theme.textTheme.labelLarge),
          const SizedBox(width: 12),
          if (c.tab.isSessionScoped) ...[
            Text('Session', style: style),
            const SizedBox(width: 6),
            DropdownButton<String>(
              key: const Key('forge-quest-session'),
              value: c.session,
              isDense: true,
              style: theme.textTheme.bodyMedium,
              items: [
                for (final s in c.sessions)
                  DropdownMenuItem(value: s, child: Text(s)),
              ],
              onChanged: (s) {
                if (s != null) c.selectSession(s);
              },
            ),
          ],
          if (c.tab == ForgeQuestLogTab.currentPrompt)
            DropdownButton<ForgeCurrentPromptVariant>(
              key: const Key('forge-quest-variant'),
              value: c.variant,
              isDense: true,
              style: theme.textTheme.bodyMedium,
              items: [
                for (final v in forgeCurrentPromptVariants)
                  DropdownMenuItem(value: v, child: Text(v.label)),
              ],
              onChanged: (v) {
                if (v != null) c.selectVariant(v);
              },
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              file == null
                  ? 'Every todo file in this quest folder.'
                  : c.truncated
                  ? '${file.name} — the newest '
                        '${forgeQuestLogMaxBytes ~/ 1024} KiB of '
                        '${(c.size! / 1024).ceil()} KiB'
                  : file.name,
              key: const Key('forge-quest-file'),
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (file != null)
            TextButton.icon(
              key: const Key('forge-quest-open-file'),
              onPressed: c.text == null ? null : () => onOpen(file),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open file'),
            ),
        ],
      ),
    );
  }
}

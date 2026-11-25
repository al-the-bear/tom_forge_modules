/// The quest view's Todos tab over the kit: the todo aggregate of
/// `tom_todo_ui` reads the quest folder through the application's file
/// system, and a todo picked there opens through the kit.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_todo_ui/tom_todo_ui.dart';

import '../quests_trail.dart';

/// [base] seen from one of its folders: a [TomFileSystem] whose [root] is
/// [folder], so a walk from its root (the todo aggregate's) stays in the
/// folder and its entries' paths are relative to it. Every call goes to
/// [base] with absolute URIs; [dispose] leaves [base] open.
class ForgeFolderFileSystem implements TomFileSystem {
  ForgeFolderFileSystem(this.base, String folder)
    : root = Uri.directory(folder);

  final TomFileSystem base;

  @override
  final Uri root;

  Uri _absolute(Uri uri) => uri.hasScheme ? uri : root.resolveUri(uri);

  bool _within(Uri uri) => pathOf(uri) != null;

  TomFileEntry _rebased(TomFileEntry e) => TomFileEntry(
    name: e.name,
    path: pathOf(e.uri) ?? e.name,
    uri: e.uri,
    kind: e.kind,
    size: e.size,
    modified: e.modified,
    linksToDirectory: e.linksToDirectory,
    linkLeavesRoot: e.linkLeavesRoot,
    readable: e.readable,
  );

  @override
  Uri uriOf(String path) =>
      path.isEmpty ? root : root.resolveUri(Uri(path: path));

  @override
  String? pathOf(Uri uri) {
    final path = Uri.decodeComponent(_absolute(uri).path);
    final rootPath = Uri.decodeComponent(root.path);
    if ('$path/' == rootPath || path == rootPath) return '';
    if (!path.startsWith(rootPath)) return null;
    final rest = path.substring(rootPath.length);
    return rest.endsWith('/') ? rest.substring(0, rest.length - 1) : rest;
  }

  @override
  Future<List<TomFileEntry>> list(Uri directory) async => [
    for (final e in await base.list(_absolute(directory))) _rebased(e),
  ];

  @override
  Future<TomFileEntry?> stat(Uri uri) async {
    final e = await base.stat(_absolute(uri));
    return e == null ? null : _rebased(e);
  }

  @override
  Future<TomFileContent> read(Uri uri) => base.read(_absolute(uri));

  @override
  Future<String> readText(Uri uri) => base.readText(_absolute(uri));

  @override
  Future<String?> readSlice(
    Uri uri, {
    required int maxBytes,
    required bool fromEnd,
  }) => base.readSlice(_absolute(uri), maxBytes: maxBytes, fromEnd: fromEnd);

  @override
  Future<TomFileRevision> write(
    Uri uri,
    Uint8List bytes, {
    TomFileRevision? expected,
  }) => base.write(_absolute(uri), bytes, expected: expected);

  @override
  Future<TomFileRevision> writeText(
    Uri uri,
    String text, {
    TomFileRevision? expected,
  }) => base.writeText(_absolute(uri), text, expected: expected);

  @override
  Future<void> create(Uri uri, {bool directory = false}) =>
      base.create(_absolute(uri), directory: directory);

  @override
  Future<void> rename(Uri from, Uri to) =>
      base.rename(_absolute(from), _absolute(to));

  @override
  Future<bool> trash(Uri uri) => base.trash(_absolute(uri));

  @override
  Future<void> delete(Uri uri) => base.delete(_absolute(uri));

  @override
  Future<bool> exists(Uri uri) => base.exists(_absolute(uri));

  /// [base]'s watch, asked only for the folders on the way to [folder] and
  /// those inside it, and only its changes inside [folder].
  @override
  Stream<TomFileChange>? watch({bool Function(String path)? descend}) {
    final rootPath = Uri.decodeComponent(root.path);
    final stream = base.watch(
      descend: (path) {
        final absolute = Uri.decodeComponent(base.uriOf(path).path);
        final dir = absolute.endsWith('/') ? absolute : '$absolute/';
        if (rootPath.startsWith(dir)) return true;
        final inner = pathOf(base.uriOf(path));
        return inner != null && (descend?.call(inner) ?? true);
      },
    );
    return stream
        ?.where((change) => _within(change.uri))
        .map((change) => TomFileChange(pathOf(change.uri)!, change.uri));
  }

  @override
  Future<void> save(Uri uri) => base.save(_absolute(uri));

  @override
  Stream<TomFileChangeEvent> get onDidChange =>
      base.onDidChange.where((event) => _within(event.uri));

  @override
  Stream<Uri> get onDidSave => base.onDidSave.where(_within);

  @override
  Stream<TomWillSaveEvent> get onWillSave =>
      base.onWillSave.where((event) => _within(event.uri));

  /// Leaves [base] open: it is the application's.
  @override
  Future<void> dispose() async {}
}

/// The todo files of a quest folder, for the todo aggregate: read through
/// [fileSystem], every sibling (archived, deleted) included, a todo picked
/// opened through [openFile] at the line that names it.
class ForgeQuestTodoSource implements TomTodoAggregateSource {
  ForgeQuestTodoSource({
    required TomFileSystem fileSystem,
    required this.quest,
    required this.openFile,
  }) : tree = ForgeFolderFileSystem(fileSystem, quest);

  /// The quest folder, absolute.
  final String quest;

  /// How a todo's file is opened: the kit's ([forgeOpenFileAtOf]).
  final ForgeOpenFileAt openFile;

  @override
  final ForgeFolderFileSystem tree;

  @override
  bool get includeSiblings => true;

  @override
  void openTodo(String path, String id) => unawaited(_open(path, id));

  Future<void> _open(String path, String id) async {
    final uri = tree.uriOf(path);
    int? line;
    try {
      final lines = (await tree.readText(uri)).split('\n');
      final pattern = RegExp('^\\s*(- )?id:\\s*[\'"]?${RegExp.escape(id)}');
      final index = lines.indexWhere(pattern.hasMatch);
      if (index >= 0) line = index;
    } on Object {
      // Opened at its start.
    }
    questsTrailEvent('quest view: open todo $id in $path at ${line ?? 0}');
    openFile(uri, line: line);
  }
}

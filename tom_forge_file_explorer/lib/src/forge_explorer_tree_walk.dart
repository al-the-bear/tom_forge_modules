/// The explorer's bounded walk of a root under a filter (D36 §2.2, §4): the
/// tree as the filter sees it, with every hidden entry counted.
library;

import 'dart:convert';

import 'package:tom_basics/utilities.dart' show TomGitignore;
import 'package:tom_file_session/tom_file_session.dart';
import 'package:tom_file_system/tom_file_system.dart';

/// How many entries the explorer's walk reads before it stops and says so,
/// as D36 §2.2 bounds the Workspace browser's: a root pointed at a home
/// folder cannot hang the explorer.
const int forgeExplorerWalkLimit = 50000;

/// An entry the filter hid, and the rule that hid it (D36 §4.2).
class ForgeExplorerHiddenEntry {
  /// Its absolute path.
  final String path;

  /// The rule that hid it, as one line ([ForgeFilterRule.describe]).
  final String rule;

  const ForgeExplorerHiddenEntry(this.path, this.rule);
}

/// The tree of one root under one filter, from one walk.
///
/// Keyed by absolute folder path, as the explorer keys its rows. Lists a
/// folder the walk did not reach are added later by
/// [ForgeExplorerTreeWalker.listDirectory], so the maps are mutable.
class ForgeExplorerTreeModel {
  /// The entries shown, by folder, folders first and then by name.
  final Map<String, List<TomFileEntry>> children = {};

  /// Hidden entries per folder (its direct children only).
  final Map<String, int> hiddenIn = {};

  /// Every hidden entry with its rule, for the hidden list.
  final List<ForgeExplorerHiddenEntry> hidden = [];

  /// Entries hidden by the filter but shown dimmed because the user asked to
  /// see the hidden entries, and everything below such a folder.
  final Set<String> dimmed = {};

  /// The `.gitignore` files in force in each folder listed.
  final Map<String, List<TomGitignore>> ignores = {};

  /// How many entries the walk read.
  int seen = 0;

  /// Whether the walk stopped at its limit: folders it did not finish are
  /// listed when they are opened.
  bool truncated = false;

  /// Hidden entries in all.
  int get hiddenTotal => hidden.length;
}

/// Walks a root under a filter, bounded by [limit] entries.
class ForgeExplorerTreeWalker {
  ForgeExplorerTreeWalker({
    required this.fileSystem,
    required this.rootUri,
    required this.filter,
    this.limit = forgeExplorerWalkLimit,
    this.showHidden = false,
  }) : rootPath = forgeExplorerFolderPath(rootUri);

  final TomFileSystem fileSystem;
  final Uri rootUri;

  /// The root as an absolute path without a trailing `/` (`/` itself kept).
  final String rootPath;
  final ForgeFilter filter;
  final int limit;

  /// Whether hidden entries are listed too, dimmed.
  final bool showHidden;

  /// The path of [absolute] relative to the root, `/`-separated.
  String relative(String absolute) {
    if (absolute == rootPath) return '';
    final prefix = rootPath == '/' ? '/' : '$rootPath/';
    return absolute.startsWith(prefix)
        ? absolute.substring(prefix.length)
        : absolute;
  }

  /// Walks the root once. [cancelled] is asked between folders; a walk
  /// cancelled answers what it has.
  Future<ForgeExplorerTreeModel> walk({bool Function()? cancelled}) async {
    final model = ForgeExplorerTreeModel();

    /// Whether anything in [dir] is shown; null when the walk did not finish
    /// it (its list is then left out, to be listed when it is opened).
    Future<bool?> visit(
      String dir,
      Uri uri,
      List<TomGitignore> inherited,
    ) async {
      if (cancelled?.call() ?? false) return null;
      final entries = await fileSystem.list(uri);
      final ignores = await _ignoresOf(dir, entries, inherited);
      model.ignores[dir] = ignores;
      final visible = <TomFileEntry>[];
      var complete = true;
      for (final entry in entries) {
        if (++model.seen > limit) {
          model.truncated = true;
          complete = false;
          break;
        }
        final path = entry.uri.toFilePath();
        final (subject, verdict) = _evaluate(entry, path, ignores);
        var shown = verdict.shown;
        if (entry.expandable && !filter.hidesSubtree(subject, verdict)) {
          final inner = await visit(path, Uri.file(path), ignores);
          // A folder the walk did not finish may hold shown entries.
          shown = shown || (inner ?? true);
        }
        _place(model, dir, entry, path, shown, verdict, visible);
      }
      if (!complete && dir != rootPath) return null;
      model.children[dir] = forgeExplorerSorted(visible);
      return visible.isNotEmpty;
    }

    await visit(rootPath, rootUri, const []);
    return model;
  }

  /// Lists the folder [dir] the walk did not reach into [model]: its direct
  /// children under the filter, a folder shown unless it is hidden with
  /// everything below it (nothing below it was read).
  Future<void> listDirectory(ForgeExplorerTreeModel model, String dir) async {
    final entries = await fileSystem.list(Uri.file(dir));
    final parent = _parentOf(dir);
    final ignores = await _ignoresOf(
      dir,
      entries,
      model.ignores[parent] ?? const [],
    );
    model.ignores[dir] = ignores;
    final insideDimmed = model.dimmed.contains(dir);
    final visible = <TomFileEntry>[];
    model.hiddenIn.remove(dir);
    model.hidden.removeWhere((h) => _parentOf(h.path) == dir);
    for (final entry in entries) {
      final path = entry.uri.toFilePath();
      final (subject, verdict) = _evaluate(entry, path, ignores);
      final shown =
          verdict.shown ||
          (entry.expandable && !filter.hidesSubtree(subject, verdict));
      _place(model, dir, entry, path, shown, verdict, visible);
      if (insideDimmed && showHidden) model.dimmed.add(path);
    }
    model.children[dir] = forgeExplorerSorted(visible);
  }

  void _place(
    ForgeExplorerTreeModel model,
    String dir,
    TomFileEntry entry,
    String path,
    bool shown,
    ForgeFilterVerdict verdict,
    List<TomFileEntry> visible,
  ) {
    if (shown) {
      visible.add(entry);
      return;
    }
    model.hiddenIn[dir] = (model.hiddenIn[dir] ?? 0) + 1;
    model.hidden.add(
      ForgeExplorerHiddenEntry(path, verdict.rule?.describe() ?? 'no rule'),
    );
    if (showHidden) {
      visible.add(entry);
      model.dimmed.add(path);
    }
  }

  (ForgeFilterSubject, ForgeFilterVerdict) _evaluate(
    TomFileEntry entry,
    String path,
    List<TomGitignore> ignores,
  ) {
    final rel = relative(path);
    bool? ignored;
    for (final g in ignores) {
      final v = g.verdict(rel, isDirectory: entry.isDirectory);
      if (v != null) ignored = v;
    }
    final subject = ForgeFilterSubject(
      path: rel,
      name: entry.name,
      isDirectory: entry.isDirectory,
      gitignored: ignored ?? false,
    );
    return (subject, filter.evaluate(subject));
  }

  /// [inherited] and the `.gitignore` of [dir] when it has one.
  Future<List<TomGitignore>> _ignoresOf(
    String dir,
    List<TomFileEntry> entries,
    List<TomGitignore> inherited,
  ) async {
    final own = entries
        .where((e) => e.name == '.gitignore' && !e.isDirectory)
        .firstOrNull;
    if (own == null) return inherited;
    try {
      final read = await fileSystem.read(own.uri);
      return [
        ...inherited,
        TomGitignore.parse(
          relative(dir),
          utf8.decode(read.bytes, allowMalformed: true),
        ),
      ];
    } on Object {
      // An unreadable .gitignore ignores nothing.
      return inherited;
    }
  }

  static String _parentOf(String path) {
    final i = path.lastIndexOf('/');
    return i > 0 ? path.substring(0, i) : '/';
  }
}

/// [uri]'s folder as an absolute path without a trailing `/` (`/` kept).
String forgeExplorerFolderPath(Uri uri) {
  final path = uri.toFilePath();
  return path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
}

/// [entries] folders first, then by name — the explorer's order.
List<TomFileEntry> forgeExplorerSorted(Iterable<TomFileEntry> entries) {
  final sorted = [...entries];
  sorted.sort((a, b) {
    if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
    return a.name.compareTo(b.name);
  });
  return sorted;
}

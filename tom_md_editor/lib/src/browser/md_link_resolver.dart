/// What a link in a Markdown document leads to, for a browser that follows
/// links into the workspace: an anchor in the document, another Markdown
/// document (with an anchor), a file to open in an editor (at a line with
/// `#L20`), an external URL, or a typed reference (`issue:`, `todo:`,
/// `trail:`, `quest:`, `test:`, and any a host registers). The same rules as
/// the VS Code extension's `linkResolver.ts`.
///
/// A relative path resolves against the current document's folder, then
/// against the workspace root; a file that exists in neither is an error.
library;

import 'package:path/path.dart' as p;

/// What kind of link it was.
enum MdLinkType {
  anchor,
  file,
  fileWithAnchor,
  external,
  issue,
  test,
  todo,
  trail,
  quest,
  unknown,
}

/// What the browser does with it.
enum MdLinkAction {
  /// Scroll to [MdResolvedLink.anchor] in the current document.
  scrollToAnchor,

  /// Show the Markdown document [MdResolvedLink.filePath].
  navigateMd,

  /// Show it and scroll to [MdResolvedLink.anchor].
  navigateMdAnchor,

  /// Open [MdResolvedLink.filePath] in an editor.
  openInEditor,

  /// Open it at [MdResolvedLink.lineNumber] (1-based).
  openInEditorLine,

  /// Open [MdResolvedLink.identifier] (a URL) outside.
  openExternal,

  /// Hand the typed reference [MdResolvedLink.identifier] to the host.
  runCommand,

  /// Show [MdResolvedLink.error].
  error,
}

/// A resolved link.
class MdResolvedLink {
  const MdResolvedLink({
    required this.type,
    required this.action,
    this.filePath,
    this.anchor,
    this.lineNumber,
    this.identifier,
    this.error,
  });

  final MdLinkType type;
  final MdLinkAction action;

  /// The absolute file path, for a file link.
  final String? filePath;

  /// The anchor without `#`.
  final String? anchor;

  /// The 1-based line, for `#L20`.
  final int? lineNumber;

  /// The URL or the typed reference's identifier.
  final String? identifier;

  /// Why the link leads nowhere.
  final String? error;
}

/// Where a link is followed from.
class MdLinkContext {
  const MdLinkContext({this.currentFilePath, this.workspaceRoot});

  /// The document holding the link.
  final String? currentFilePath;

  /// The workspace root.
  final String? workspaceRoot;
}

/// A typed reference, `<prefix>…`.
class MdLinkHandler {
  const MdLinkHandler(this.prefix, this.resolve);

  /// The prefix with its colon, e.g. `issue:`.
  final String prefix;

  /// Resolves the identifier after the prefix.
  final MdResolvedLink Function(String identifier, MdLinkContext context)
  resolve;
}

/// Resolves links; [exists] answers whether a path is a file.
class MdLinkResolver {
  MdLinkResolver({
    required this.exists,
    p.Context? pathContext,
    Iterable<MdLinkHandler> handlers = const [],
  }) : _path = pathContext ?? p.context {
    for (final h in [..._builtIns(), ...handlers]) {
      _handlers[h.prefix.toLowerCase()] = h;
    }
  }

  /// Whether the file at a path exists.
  final bool Function(String path) exists;

  final p.Context _path;
  final _handlers = <String, MdLinkHandler>{};

  List<MdLinkHandler> _builtIns() {
    MdLinkHandler command(String prefix, MdLinkType type) => MdLinkHandler(
      prefix,
      (id, _) => MdResolvedLink(
        type: type,
        action: MdLinkAction.runCommand,
        identifier: id,
      ),
    );
    return [
      command('issue:', MdLinkType.issue),
      command('todo:', MdLinkType.todo),
      command('trail:', MdLinkType.trail),
      command('test:', MdLinkType.test),
      MdLinkHandler('quest:', (id, context) {
        final root = context.workspaceRoot;
        if (root != null) {
          final overview = _path.join(root, '_ai', 'quests', id, 'overview.$id.md');
          if (exists(overview)) {
            return MdResolvedLink(
              type: MdLinkType.quest,
              action: MdLinkAction.navigateMd,
              filePath: overview,
              identifier: id,
            );
          }
        }
        return MdResolvedLink(
          type: MdLinkType.quest,
          action: MdLinkAction.runCommand,
          identifier: id,
        );
      }),
    ];
  }

  static final _external = RegExp(r'^(https?:|mailto:|tel:|file:)', caseSensitive: false);
  static final _lineAnchor = RegExp(r'^L(\d+)', caseSensitive: false);

  /// What following [href] from [context] does.
  MdResolvedLink resolve(String href, [MdLinkContext context = const MdLinkContext()]) {
    final link = href.trim();
    if (link.isEmpty) {
      return const MdResolvedLink(
        type: MdLinkType.unknown,
        action: MdLinkAction.error,
        error: 'Empty link',
      );
    }
    if (_external.hasMatch(link)) {
      return MdResolvedLink(
        type: MdLinkType.external,
        action: MdLinkAction.openExternal,
        identifier: link,
      );
    }
    if (link.startsWith('#')) {
      return MdResolvedLink(
        type: MdLinkType.anchor,
        action: MdLinkAction.scrollToAnchor,
        anchor: link.substring(1),
      );
    }
    final colon = link.indexOf(':');
    if (colon > 0 && colon < 20) {
      final handler = _handlers[link.substring(0, colon + 1).toLowerCase()];
      if (handler != null) return handler.resolve(link.substring(colon + 1), context);
    }
    return _file(link, context);
  }

  MdResolvedLink _file(String link, MdLinkContext context) {
    final hash = link.indexOf('#');
    final part = hash >= 0 ? link.substring(0, hash) : link;
    final anchor = hash >= 0 ? link.substring(hash + 1) : null;
    String? resolved;
    if (_path.isAbsolute(part)) {
      resolved = part;
    } else if (context.currentFilePath != null) {
      resolved = _path.normalize(_path.join(_path.dirname(context.currentFilePath!), part));
    } else if (context.workspaceRoot != null) {
      resolved = _path.normalize(_path.join(context.workspaceRoot!, part));
    }
    if (resolved != null && !exists(resolved) && context.workspaceRoot != null) {
      final fromRoot = _path.normalize(_path.join(context.workspaceRoot!, part));
      if (exists(fromRoot)) resolved = fromRoot;
    }
    if (resolved == null || !exists(resolved)) {
      return MdResolvedLink(
        type: MdLinkType.unknown,
        action: MdLinkAction.error,
        error: 'File not found: $part',
      );
    }
    if (resolved.toLowerCase().endsWith('.md')) {
      return anchor != null
          ? MdResolvedLink(
              type: MdLinkType.fileWithAnchor,
              action: MdLinkAction.navigateMdAnchor,
              filePath: resolved,
              anchor: anchor,
            )
          : MdResolvedLink(
              type: MdLinkType.file,
              action: MdLinkAction.navigateMd,
              filePath: resolved,
            );
    }
    final line = anchor == null ? null : _lineAnchor.firstMatch(anchor);
    return line != null
        ? MdResolvedLink(
            type: MdLinkType.file,
            action: MdLinkAction.openInEditorLine,
            filePath: resolved,
            lineNumber: int.parse(line.group(1)!),
          )
        : MdResolvedLink(
            type: MdLinkType.file,
            action: MdLinkAction.openInEditor,
            filePath: resolved,
          );
  }
}

/// A heading's anchor id, GitHub's way: `Hello World!` → `hello-world`.
String mdAnchorId(String text) => text
    .toLowerCase()
    .trim()
    .replaceAll(RegExp(r'[^\w\s-]'), '')
    .replaceAll(RegExp(r'\s+'), '-')
    .replaceAll(RegExp(r'-+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');

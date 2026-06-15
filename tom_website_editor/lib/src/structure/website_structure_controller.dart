import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tom_website_editor_core/tom_website_editor_core.dart';

import '../content/website_content_fs.dart';
import '../website_editor_controller.dart';
import 'copy_naming.dart';
import 'website_structure_node.dart';

/// Drives the §6b website-structure explorer: a filesystem-driven tree of the
/// active website's `content/` directory through the injectable
/// [WebsiteContentFs] seam.
///
/// Where the §6a content browser ([WebsiteContentController]) presents a *parsed*
/// catalog (component → module → submodule records), this explorer mirrors the
/// directory layout itself: the `site.yaml` file, the `areas/`, `components/`,
/// `pages/` directories listed by their config globs, the `copy/` directory
/// grouped by the §16 naming convention ([groupCopyFiles]), and the recursive
/// `diagrams/` tree. Each file node routes to an editor by extension
/// ([FileEditorKind]) — `.yaml` to `tom_yaml_editor`, `.md` to `tom_md_editor`.
///
/// The explorer is [isEnabled] only when the active website carries a `content:`
/// block; otherwise the tree is empty. Placeholder expansion of the content
/// `dir` reuses [PlaceholderResolver]; a resolution failure is surfaced via
/// [error] rather than a silent blank tree.
class WebsiteStructureController extends ChangeNotifier {
  WebsiteStructureController({
    required WebsiteEditorController editor,
    required WebsiteContentFs fileSystem,
    Map<String, String> builtins = const {},
    Map<String, String>? environment,
    String? homeDir,
    DateTime Function()? clock,
  })  : _editor = editor,
        _fs = fileSystem,
        _builtins = builtins,
        _environment = environment,
        _homeDir = homeDir,
        _clock = clock {
    _editor.addListener(_onEditorChanged);
  }

  final WebsiteEditorController _editor;
  final WebsiteContentFs _fs;
  final Map<String, String> _builtins;
  final Map<String, String>? _environment;
  final String? _homeDir;
  final DateTime Function()? _clock;

  List<StructureNode> _nodes = const [];
  bool _isLoading = false;
  String? _error;
  String? _loadedWebsiteId;

  /// The active website's content configuration, or `null` when it opts out.
  WebsiteContentConfig? get _content =>
      _editor.registry?.activeWebsite.content;

  /// `true` when the active website configures a `content:` block (§6b). When
  /// `false` the explorer is disabled and the tree is empty.
  bool get isEnabled => _content != null;

  /// The top-level sections of the structure tree (site.yaml, areas,
  /// components, copy, pages, diagrams), in that order.
  List<StructureNode> get nodes => List.unmodifiable(_nodes);

  /// `true` while a refresh is in flight.
  bool get isLoading => _isLoading;

  /// The last placeholder-resolution error, or `null` when the tree is healthy.
  String? get error => _error;

  /// Rebuilds the tree from disk for the active website (§6b refresh).
  ///
  /// Clears the tree (and any [error]) when the active website has no `content:`
  /// block. On a placeholder-resolution failure the tree is cleared and the
  /// reason is exposed via [error] (never a silent blank tree).
  Future<void> refresh() async {
    final registry = _editor.registry;
    final website = registry?.activeWebsite;
    final content = website?.content;
    _loadedWebsiteId = website?.id;
    if (registry == null || website == null || content == null) {
      _nodes = const [];
      _error = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();
    try {
      final dirUri = _resolveContentDir();
      final sections = <StructureNode>[];
      void addIfPresent(StructureNode? node) {
        if (node != null) sections.add(node);
      }

      addIfPresent(await _siteSection(dirUri, content));
      addIfPresent(await _globSection(dirUri, content.areas));
      addIfPresent(await _globSection(dirUri, content.components));
      addIfPresent(await _copySection(dirUri, content));
      addIfPresent(await _globSection(dirUri, content.pages));
      addIfPresent(await _diagramsSection(dirUri));

      _nodes = sections;
      _error = null;
    } on PlaceholderException catch (e) {
      _nodes = const [];
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates a new §16 copy file for [kind]/[parts] at its convention path under
  /// the `copy/` directory, writing a starter heading, then refreshes the tree.
  /// Returns the created file's [Uri].
  ///
  /// Throws [StateError] when the active website has no `content:` block, and
  /// [ArgumentError] when [parts] does not match the kind's arity.
  Future<Uri> createCopyFile(
    CopyFileKind kind, {
    List<String> parts = const [],
  }) async {
    final content = _content;
    if (content == null) {
      throw StateError(
          'createCopyFile requires an active website with a content: block');
    }
    final dirUri = _resolveContentDir();
    final copyDir = ContentGlob(content.copy, base: dirUri).directory;
    final uri = copyDir.resolve(copyFileName(kind, parts: parts));
    if (!await _fs.exists(uri)) {
      await _fs.write(uri, _starterCopy(kind, parts));
    }
    await refresh();
    return uri;
  }

  /// Creates a new file at [uri] with [content] (default empty) if it does not
  /// already exist, then refreshes the tree. Returns the created file's [Uri].
  ///
  /// Unlike [createCopyFile] this is a free-form create the §6b explorer drives
  /// from its per-directory "new file" affordance; the caller chooses the path.
  Future<Uri> createFile(Uri uri, {String content = ''}) async {
    if (!await _fs.exists(uri)) {
      await _fs.write(uri, content);
    }
    await refresh();
    return uri;
  }

  /// Deletes the file at [uri] through the FS seam, then refreshes the tree.
  Future<void> deleteFile(Uri uri) async {
    await _fs.delete(uri);
    await refresh();
  }

  /// Renames the file at [from] to a sibling named [newName] (a bare file name,
  /// not a path), then refreshes the tree. Returns the new [Uri].
  ///
  /// Throws [ArgumentError] when [newName] is blank or contains a path
  /// separator — a rename stays within the file's own directory.
  Future<Uri> renameFile(Uri from, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed.contains('/')) {
      throw ArgumentError.value(
          newName, 'newName', 'must be a non-empty file name without "/"');
    }
    final to = from.resolve(trimmed);
    await _fs.rename(from, to);
    await refresh();
    return to;
  }

  Future<StructureNode?> _siteSection(
      Uri dirUri, WebsiteContentConfig content) async {
    final siteUri = dirUri.resolve(content.site);
    if (!await _fs.exists(siteUri)) return null;
    return fileNode(siteUri);
  }

  /// A directory section listing the files matched by a `dir/glob` [pattern]
  /// (non-recursive), or `null` when the directory is absent.
  Future<StructureNode?> _globSection(Uri dirUri, String pattern) async {
    final glob = ContentGlob(pattern, base: dirUri);
    if (!await _fs.exists(glob.directory)) return null;
    final files = await _fs.listFiles(glob.directory);
    final matches = files.where(glob.matches).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    return StructureNode(
      label: _dirLabel(glob.directory),
      kind: StructureNodeKind.directory,
      uri: glob.directory,
      children: [for (final uri in matches) fileNode(uri)],
    );
  }

  /// The `copy/` section, grouped by the §16 naming convention, or `null` when
  /// the directory is absent.
  Future<StructureNode?> _copySection(
      Uri dirUri, WebsiteContentConfig content) async {
    final glob = ContentGlob(content.copy, base: dirUri);
    if (!await _fs.exists(glob.directory)) return null;
    final files = await _fs.listFiles(glob.directory);
    final matches = files.where(glob.matches).toList();
    return StructureNode(
      label: _dirLabel(glob.directory),
      kind: StructureNodeKind.group,
      uri: glob.directory,
      children: groupCopyFiles(matches),
    );
  }

  /// The recursive `diagrams/` section, or `null` when the directory is absent.
  /// Diagrams are convention-located at `<dir>/diagrams/` (no config glob).
  Future<StructureNode?> _diagramsSection(Uri dirUri) async {
    final diagramsUri = dirUri.resolve('diagrams/');
    if (!await _fs.exists(diagramsUri)) return null;
    return _buildDirTree(diagramsUri, label: 'diagrams');
  }

  /// Builds a directory node recursively from [dir], routing leaf files by
  /// extension and recursing into subdirectories.
  Future<StructureNode> _buildDirTree(Uri dir,
      {required String label}) async {
    final entries = await _fs.listEntries(dir);
    entries.sort((a, b) => a.uri.path.compareTo(b.uri.path));
    final children = <StructureNode>[];
    for (final entry in entries) {
      if (entry.isDirectory) {
        children.add(
            await _buildDirTree(entry.uri, label: _dirLabel(entry.uri)));
      } else {
        children.add(fileNode(entry.uri));
      }
    }
    return StructureNode(
      label: label,
      kind: StructureNodeKind.directory,
      uri: dir,
      children: children,
    );
  }

  /// Resolves the active website's content `dir` template to a directory [Uri]
  /// (trailing slash). Throws [PlaceholderException] on an unknown token.
  Uri _resolveContentDir() {
    final registry = _editor.registry!;
    final website = registry.activeWebsite;
    final content = website.content!;
    final resolver = PlaceholderResolver.forWebsite(
      registry.config,
      website,
      builtins: _builtins,
      environment: _environment,
      homeDir: _homeDir,
      clock: _clock,
    );
    final dir = resolver.resolve(content.dir,
        location: 'websites.${website.id}.content.dir');
    return _directoryUri(dir);
  }

  /// Builds a directory [Uri] (with a trailing slash) from an expanded [path].
  Uri _directoryUri(String path) =>
      Uri.file(path.endsWith('/') ? path : '$path/');

  /// The last non-empty path segment of a directory [uri] (its display name).
  String _dirLabel(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    return segments.isEmpty ? uri.toString() : segments.last;
  }

  /// A starter Markdown heading for a freshly created copy file. Site-level
  /// kinds get their own title; per-entity kinds use their slug [parts].
  String _starterCopy(CopyFileKind kind, List<String> parts) {
    final title = switch (kind) {
      CopyFileKind.home => 'Home',
      CopyFileKind.news => 'News',
      _ => parts.join(' '),
    };
    return '# $title\n';
  }

  void _onEditorChanged() {
    if (_editor.activeWebsiteId == _loadedWebsiteId && _editor.isLoaded) {
      notifyListeners();
      return;
    }
    unawaited(refresh());
  }

  @override
  void dispose() {
    _editor.removeListener(_onEditorChanged);
    super.dispose();
  }
}

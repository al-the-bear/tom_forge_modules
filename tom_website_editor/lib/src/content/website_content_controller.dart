import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tom_website_editor_core/tom_website_editor_core.dart';

import '../website_editor_controller.dart';
import 'content_field.dart';
import 'content_parser.dart';
import 'content_record.dart';
import 'website_content_fs.dart';

/// A parsed component file: its source [uri], the raw YAML [source] (kept for
/// span-precise pin writes), and the [record] tree built from it.
class ContentComponentDocument {
  const ContentComponentDocument({
    required this.uri,
    required this.source,
    required this.record,
  });

  /// The component file's location, for writes and identity.
  final Uri uri;

  /// The raw YAML text the [record] was parsed from (pin writes edit this).
  final String source;

  /// The component → modules → submodules tree parsed from [source].
  final ContentRecord record;
}

/// Drives the §6a content browser: turns the active website's `content:` config
/// into a catalog of component [components], the `site.yaml` file, and the
/// standalone [pages], all loaded through the injectable [WebsiteContentFs] seam.
///
/// It wraps the shared [WebsiteEditorController] (website selection + config live
/// there) and never imports the website's Dart code — every file is plain data
/// I/O (§1/§6a). The browser is [isEnabled] only when the active website carries
/// a `content:` block; otherwise the tree is empty and the view shows a disabled
/// state. Placeholder expansion of the content `dir` reuses [PlaceholderResolver];
/// a resolution failure is surfaced via [error] rather than a silent blank tree.
class WebsiteContentController extends ChangeNotifier {
  WebsiteContentController({
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

  List<ContentComponentDocument> _components = const [];
  List<Uri> _pages = const [];
  Uri? _siteFile;
  bool _isLoading = false;
  String? _error;

  /// The active website's content configuration, or `null` when it opts out.
  WebsiteContentConfig? get _content =>
      _editor.registry?.activeWebsite.content;

  /// `true` when the active website configures a `content:` block (§6a). When
  /// `false` the browser is disabled and the catalog is empty.
  bool get isEnabled => _content != null;

  /// The parsed component documents, sorted by file path.
  List<ContentComponentDocument> get components =>
      List.unmodifiable(_components);

  /// The standalone page files (`pages/*.md`), sorted by path.
  List<Uri> get pages => List.unmodifiable(_pages);

  /// The site-level copy file (`site.yaml`), or `null` when it is absent.
  Uri? get siteFile => _siteFile;

  /// `true` while a refresh is in flight.
  bool get isLoading => _isLoading;

  /// The last placeholder-resolution error, or `null` when the tree is healthy.
  String? get error => _error;

  String? _loadedWebsiteId;

  /// Rebuilds the catalog from disk for the active website (§6a refresh).
  ///
  /// Clears the catalog (and any [error]) when the active website has no
  /// `content:` block. On a placeholder-resolution failure the catalog is
  /// cleared and the reason is exposed via [error] (never a silent blank tree).
  Future<void> refresh() async {
    final registry = _editor.registry;
    final website = registry?.activeWebsite;
    final content = website?.content;
    _loadedWebsiteId = website?.id;
    if (registry == null || website == null || content == null) {
      _components = const [];
      _pages = const [];
      _siteFile = null;
      _error = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();
    try {
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
      final dirUri = _directoryUri(dir);

      _components = await _loadComponents(dirUri, content);
      _siteFile = await _resolveSite(dirUri, content);
      _pages = await _loadPages(dirUri, content);
      _error = null;
    } on PlaceholderException catch (e) {
      _components = const [];
      _pages = const [];
      _siteFile = null;
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<ContentComponentDocument>> _loadComponents(
    Uri dirUri,
    WebsiteContentConfig content,
  ) async {
    final glob = ContentGlob(content.components, base: dirUri);
    if (!await _fs.exists(glob.directory)) return const [];
    final files = await _fs.listFiles(glob.directory);
    final matches = files.where(glob.matches).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final docs = <ContentComponentDocument>[];
    for (final uri in matches) {
      final source = await _fs.read(uri);
      final record = parseComponentRecord(
        source,
        editableFields: content.editableFields,
        manualPin: content.manualPin,
      );
      docs.add(ContentComponentDocument(
          uri: uri, source: source, record: record));
    }
    return docs;
  }

  Future<Uri?> _resolveSite(Uri dirUri, WebsiteContentConfig content) async {
    final siteUri = dirUri.resolve(content.site);
    return await _fs.exists(siteUri) ? siteUri : null;
  }

  Future<List<Uri>> _loadPages(
      Uri dirUri, WebsiteContentConfig content) async {
    final glob = ContentGlob(content.pages, base: dirUri);
    if (!await _fs.exists(glob.directory)) return const [];
    final files = await _fs.listFiles(glob.directory);
    return files.where(glob.matches).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
  }

  /// Pins [field] of [document] with the configured `# @manual` marker so the
  /// hand edit survives the next regenerate (§6a), writing the change to disk
  /// and re-parsing the document. Returns `true` when a pin was written, `false`
  /// when the field was already pinned or the website has no content config.
  Future<bool> pinField(
    ContentComponentDocument document,
    ContentField field,
  ) async {
    final content = _content;
    if (content == null || field.isPinned) return false;

    final updated =
        pinFieldLine(document.source, field.sourceLine, content.manualPin);
    if (updated == document.source) return false;

    await _fs.write(document.uri, updated);
    final record = parseComponentRecord(
      updated,
      editableFields: content.editableFields,
      manualPin: content.manualPin,
    );
    final index = _components.indexWhere((d) => d.uri == document.uri);
    if (index >= 0) {
      final next = List.of(_components);
      next[index] = ContentComponentDocument(
          uri: document.uri, source: updated, record: record);
      _components = next;
    }
    notifyListeners();
    return true;
  }

  /// Persists a curated scalar edit (§6a): replaces [field]'s value with [value]
  /// in [document], writes the file back through [writeFile], and re-parses.
  ///
  /// Only editable fields are written; a managed field, an unchanged value, or a
  /// website without a content config is a no-op (`false`). A pinned field keeps
  /// its `# @manual` marker. Returns `true` when the file was rewritten.
  Future<bool> setFieldValue(
    ContentComponentDocument document,
    ContentField field,
    String value,
  ) async {
    final content = _content;
    if (content == null || !field.isEditable || value == field.value) {
      return false;
    }

    final updated = setFieldLineValue(
      document.source,
      field.sourceLine,
      value,
      preserveComment: field.isPinned ? content.manualPin : null,
    );
    if (updated == document.source) return false;

    await writeFile(document.uri, updated);
    final record = parseComponentRecord(
      updated,
      editableFields: content.editableFields,
      manualPin: content.manualPin,
    );
    final index = _components.indexWhere((d) => d.uri == document.uri);
    if (index >= 0) {
      final next = List.of(_components);
      next[index] = ContentComponentDocument(
          uri: document.uri, source: updated, record: record);
      _components = next;
    }
    notifyListeners();
    return true;
  }

  /// Reads [uri] as text through the content file system (for the inline editors
  /// and page panes).
  Future<String> readFile(Uri uri) => _fs.read(uri);

  /// Writes [content] to [uri] through the content file system (for inline
  /// editor / page saves).
  Future<void> writeFile(Uri uri, String content) =>
      _fs.write(uri, content);

  /// Builds a directory [Uri] (with a trailing slash, so relative globs resolve
  /// against it) from a placeholder-expanded [path].
  Uri _directoryUri(String path) =>
      Uri.file(path.endsWith('/') ? path : '$path/');

  void _onEditorChanged() {
    // Reload only when the active website actually changed, so unrelated editor
    // notifications (e.g. loading toggles) don't trigger redundant disk reads.
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

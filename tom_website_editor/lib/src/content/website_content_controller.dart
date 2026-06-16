import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tom_website_editor_core/tom_website_editor_core.dart';

import '../structure/copy_naming.dart';
import '../website_editor_controller.dart';
import 'content_copy_file.dart';
import 'content_field.dart';
import 'content_group.dart';
import 'content_page.dart';
import 'content_parser.dart';
import 'content_record.dart';
import 'repo_doc.dart';
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

/// A parsed external copy file (§16): its source [uri], the raw Markdown
/// [source] it was parsed from, and the front-matter + body [file] model.
class ContentCopyDocument {
  const ContentCopyDocument({
    required this.uri,
    required this.source,
    required this.file,
  });

  /// The copy file's location, for writes and identity.
  final Uri uri;

  /// The raw text the [file] was parsed from.
  final String source;

  /// The front-matter + body model parsed from [source].
  final ContentCopyFile file;
}

/// A parsed standalone page file (`pages/*.md`, §9 item 3): its source [uri],
/// the raw Markdown [source] it was parsed from, and the front-matter + body
/// [file] model. Pages carry `title` / `route` front-matter scalars (the
/// `route` determines the page's URL) above a region-aware Markdown body, so
/// they share the [ContentCopyFile] shape with §16 copy files.
class ContentPageDocument {
  const ContentPageDocument({
    required this.uri,
    required this.source,
    required this.file,
  });

  /// The page file's location, for writes and identity.
  final Uri uri;

  /// The raw text the [file] was parsed from.
  final String source;

  /// The front-matter (`title` / `route`) + body model parsed from [source].
  final ContentCopyFile file;
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
  List<ContentCopyDocument> _copyFiles = const [];
  List<ContentPageDocument> _pages = const [];
  Map<String, List<RepoDocRef>> _repoDocs = const {};
  Uri? _siteFile;
  String? _siteSource;
  SiteConfig? _siteConfig;
  List<ConfigIssue> _siteIssues = const [];
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

  /// The parsed external copy files (`copy/*.md`, §16), sorted by file path.
  List<ContentCopyDocument> get copyFiles => List.unmodifiable(_copyFiles);

  /// The site-level copy files (`home.md`, `news.md`): standalone copy that does
  /// not follow the per-entity `<C>_…` naming convention (§16). The §6a browser
  /// surfaces these together so the home page's editorial copy — including its
  /// news band — is reachable in one place. Sorted by file path.
  List<ContentCopyDocument> get siteLevelCopyFiles => List.unmodifiable([
        for (final doc in _copyFiles)
          if (_isSiteLevelCopy(doc.uri)) doc,
      ]);

  /// `true` when [uri]'s file name parses to a site-level copy kind (home/news).
  static bool _isSiteLevelCopy(Uri uri) {
    final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final parsed = parseCopyFileName(name);
    return parsed != null && siteLevelCopyKinds.contains(parsed.kind);
  }

  /// The parsed standalone page files (`pages/*.md`, §9 item 3), sorted by path.
  List<ContentPageDocument> get pages => List.unmodifiable(_pages);

  /// The repo-sourced docs (`README` / `LICENSE` / `release.md`, §9 item 5)
  /// discovered for the record with [recordId] — a component or one of its
  /// modules/submodules. Resolved server-side from the website's `sourceRoot`
  /// (not from `content/`), these are read-only provenance: the browser shows
  /// them badged read-only and never offers them for inline edit or pinning.
  ///
  /// Empty when the record has no source path, no `README`/`LICENSE`/`release`
  /// in its repo root, or when the website configures no `sourceRoot`.
  List<RepoDocRef> repoDocsFor(String recordId) =>
      _repoDocs[recordId] ?? const [];

  /// The site-level copy file (`site.yaml`), or `null` when it is absent.
  Uri? get siteFile => _siteFile;

  /// The parsed, validated `site.yaml` model (§9 item 4), or `null` when the
  /// site file is absent or could not be parsed. Surfaces the home page's
  /// [SiteConfig.featured] component (blank = no featured component) so the §6a
  /// site pane can show and edit it without hand-editing YAML.
  SiteConfig? get siteConfig => _siteConfig;

  /// Validation issues for the current `site.yaml` (errors and warnings). An
  /// empty or absent `home.featured` validates green; a featured pointing at an
  /// unknown component id is a non-fatal warning. Empty when the file is healthy
  /// or absent.
  List<ConfigIssue> get siteIssues => List.unmodifiable(_siteIssues);

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
      _copyFiles = const [];
      _pages = const [];
      _repoDocs = const {};
      _clearSite();
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
      _copyFiles = await _loadCopyFiles(dirUri, content);
      await _loadSite(dirUri, content);
      _pages = await _loadPages(dirUri, content);
      _repoDocs = await _loadRepoDocs(resolver, website);
      _error = null;
    } on PlaceholderException catch (e) {
      _components = const [];
      _copyFiles = const [];
      _pages = const [];
      _repoDocs = const {};
      _clearSite();
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

  Future<List<ContentCopyDocument>> _loadCopyFiles(
    Uri dirUri,
    WebsiteContentConfig content,
  ) async {
    final glob = ContentGlob(content.copy, base: dirUri);
    if (!await _fs.exists(glob.directory)) return const [];
    final files = await _fs.listFiles(glob.directory);
    final matches = files.where(glob.matches).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final docs = <ContentCopyDocument>[];
    for (final uri in matches) {
      final source = await _fs.read(uri);
      docs.add(ContentCopyDocument(
          uri: uri, source: source, file: ContentCopyFile.parse(source)));
    }
    return docs;
  }

  /// Resolves, reads, and parses `site.yaml` (§9 item 4) into [_siteConfig],
  /// validating `home.featured` against the loaded component ids so an unknown
  /// id surfaces as a warning. Clears the site state when the file is absent.
  Future<void> _loadSite(Uri dirUri, WebsiteContentConfig content) async {
    final siteUri = dirUri.resolve(content.site);
    if (!await _fs.exists(siteUri)) {
      _clearSite();
      return;
    }
    final source = await _fs.read(siteUri);
    final result = loadSiteConfig(source, knownComponentIds: _componentIds);
    _siteFile = siteUri;
    _siteSource = source;
    _siteConfig = result.config;
    _siteIssues = result.issues;
  }

  /// Clears every cached `site.yaml` field (used when the file is absent or the
  /// catalog is reset).
  void _clearSite() {
    _siteFile = null;
    _siteSource = null;
    _siteConfig = null;
    _siteIssues = const [];
  }

  /// The ids of the currently loaded components — the valid targets for
  /// `home.featured`.
  Set<String> get _componentIds =>
      {for (final doc in _components) doc.record.id};

  /// Sets (or clears) the home page's featured component (§9 item 4).
  ///
  /// A non-empty [componentId] writes `home.featured: <id>`; a `null` or blank
  /// [componentId] clears the value back to a bare `featured:` key (the site
  /// then renders the flat components grid). The change is written to disk and
  /// the model is re-parsed + re-validated in place.
  ///
  /// Returns `false` (no write) when there is no `site.yaml`, when the file has
  /// no `home.featured` key to edit, or when the value is unchanged. Setting an
  /// unknown component id still succeeds (the value loads as a non-fatal
  /// warning), so the editor never blocks a hand-chosen id.
  Future<bool> setSiteFeatured(String? componentId) async {
    final source = _siteSource;
    final config = _siteConfig;
    final uri = _siteFile;
    if (source == null || config == null || uri == null) return false;
    final sourceLine = config.featuredSourceLine;
    if (sourceLine == null) return false;

    final id = componentId?.trim();
    final desired = (id == null || id.isEmpty) ? null : id;
    if (desired == config.featured) return false;

    final updated = desired == null
        ? clearFieldLineValue(source, sourceLine)
        : setFieldLineValue(source, sourceLine, desired);
    if (updated == source) return false;

    await writeFile(uri, updated);
    final result = loadSiteConfig(updated, knownComponentIds: _componentIds);
    _siteSource = updated;
    _siteConfig = result.config;
    _siteIssues = result.issues;
    notifyListeners();
    return true;
  }

  /// Sets the detailed-content scope — the components whose `/docs` + `/api`
  /// trees the site exposes (§9 item 7) — to [ids].
  ///
  /// Writes `detailedComponents: [a, b]`, replacing the key in place when it
  /// already exists or inserting it (before `home:`) when it is absent, so a
  /// `site.yaml` that has not adopted the key can still be edited. An empty
  /// [ids] writes an explicit empty list (the site then exposes no detailed
  /// content), which is distinct from removing the key (the built-in default).
  /// The change is written to disk and the model is re-parsed + re-validated in
  /// place. Setting an unknown id still succeeds (it loads as a non-fatal
  /// warning), so the editor never blocks a hand-chosen scope.
  ///
  /// Returns `false` (no write) when there is no `site.yaml` or when the
  /// resulting list is unchanged.
  Future<bool> setSiteDetailedComponents(List<String> ids) async {
    final source = _siteSource;
    final config = _siteConfig;
    final uri = _siteFile;
    if (source == null || config == null || uri == null) return false;

    final desired = [
      for (final id in ids)
        if (id.trim().isNotEmpty) id.trim(),
    ];
    final current = config.detailedComponents;
    if (current != null && _sameList(current, desired)) return false;

    final updated = setDetailedComponentsLine(
        source, config.detailedComponentsSourceLine, desired);
    if (updated == source) return false;

    await writeFile(uri, updated);
    final result = loadSiteConfig(updated, knownComponentIds: _componentIds);
    _siteSource = updated;
    _siteConfig = result.config;
    _siteIssues = result.issues;
    notifyListeners();
    return true;
  }

  /// Order-sensitive equality of two id lists (the detailed-component list is an
  /// ordered scope, so re-ordering is a real change worth persisting).
  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<List<ContentPageDocument>> _loadPages(
      Uri dirUri, WebsiteContentConfig content) async {
    final glob = ContentGlob(content.pages, base: dirUri);
    if (!await _fs.exists(glob.directory)) return const [];
    final files = await _fs.listFiles(glob.directory);
    final matches = files.where(glob.matches).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final docs = <ContentPageDocument>[];
    for (final uri in matches) {
      final source = await _fs.read(uri);
      docs.add(ContentPageDocument(
          uri: uri, source: source, file: ContentCopyFile.parse(source)));
    }
    return docs;
  }

  /// Resolves the repo-sourced docs (§9 item 5) for every loaded component and
  /// its modules/submodules, keyed by record id.
  ///
  /// The repo root for a record is its [ContentRecord.source] (`_generated.source`
  /// for a component, the `path` field for a module) resolved against the
  /// website's `{sourceRoot}` path. A website that configures no `sourceRoot`
  /// simply has no repo docs — the missing placeholder is swallowed here (it is
  /// not a content-tree error) and an empty map is returned.
  Future<Map<String, List<RepoDocRef>>> _loadRepoDocs(
    PlaceholderResolver resolver,
    WebsiteEntry website,
  ) async {
    final String sourceRoot;
    try {
      sourceRoot = resolver.resolve('{sourceRoot}',
          location: 'websites.${website.id}.paths.sourceRoot');
    } on PlaceholderException {
      return const {}; // No sourceRoot configured → no repo-sourced docs.
    }
    final base = _directoryUri(sourceRoot);
    final docs = <String, List<RepoDocRef>>{};
    for (final document in _components) {
      await _collectRepoDocs(document.record, base, docs);
    }
    return docs;
  }

  /// Walks [record] and its children, reading each one's repo docs from
  /// `base/<record.source>/` into [out] (keyed by record id). A record with no
  /// source path, or whose repo root holds no README/LICENSE/release, adds no
  /// entry.
  Future<void> _collectRepoDocs(
    ContentRecord record,
    Uri base,
    Map<String, List<RepoDocRef>> out,
  ) async {
    final source = record.source;
    if (source != null && source.isNotEmpty) {
      final dir = base.resolve(source.endsWith('/') ? source : '$source/');
      final refs = await _resolveRepoDocs(dir);
      if (refs.isNotEmpty) out[record.id] = refs;
    }
    for (final child in record.children) {
      await _collectRepoDocs(child, base, out);
    }
  }

  /// Reads the README / LICENSE / release.md present directly under repo-root
  /// [dir], in display order, matching the website's `repo_docs_loader`
  /// (case- and extension-tolerant). An absent directory yields no docs.
  Future<List<RepoDocRef>> _resolveRepoDocs(Uri dir) async {
    if (!await _fs.exists(dir)) return const [];
    final files = await _fs.listFiles(dir);
    final refs = <RepoDocRef>[];
    for (final kind in RepoDocKind.values) {
      final uri = pickRepoDocFile(files, kind.stem);
      if (uri != null) refs.add(RepoDocRef(kind: kind, uri: uri));
    }
    return refs;
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

  /// Unpins [field] of [document]: removes the `# @manual` marker so the field
  /// reverts to generator-managed status and the next regenerate is free to
  /// overwrite its value again (§6a). Writes the change to disk and re-parses the
  /// document. The inverse of [pinField].
  ///
  /// Returns `true` when the marker was removed, `false` when the field was not
  /// pinned or the website has no content config. Note: unpin reverts the field's
  /// *status*, not its value — the current on-disk value is kept until the next
  /// generate run replaces it (the model stores no separate "generated original").
  Future<bool> unpinField(
    ContentComponentDocument document,
    ContentField field,
  ) async {
    final content = _content;
    if (content == null || !field.isPinned) return false;

    final updated =
        unpinFieldLine(document.source, field.sourceLine, content.manualPin);
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

  /// Persists a component's hand-authored module groups (§9 item 1): rewrites
  /// the `groups:` block of [document] to the canonical serialization of
  /// [groups], writes the file back, and re-parses it in place. Used by the
  /// browser's add / rename / reorder / assign-member edits.
  ///
  /// Member ids are validated against the component's real modules first: a
  /// group referencing an id that is not one of [document]'s modules is rejected
  /// (`false`, no write), so the browser can only persist groups whose members
  /// all resolve. A no-op rewrite (groups unchanged) or a website without a
  /// content config also returns `false`. The generator-owned fields
  /// (`id`/`name`/`category`/`modules`) are untouched, so the edit survives the
  /// next `generateContent`.
  Future<bool> setGroups(
    ContentComponentDocument document,
    List<ContentGroup> groups,
  ) async {
    final content = _content;
    if (content == null) return false;

    final moduleIds = document.record.moduleIds;
    final hasUnknownMember = groups.any(
        (group) => group.members.any((id) => !moduleIds.contains(id)));
    if (hasUnknownMember) return false;

    final updated = setComponentGroups(document.source, groups);
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

  /// Persists a copy-file front-matter edit (§16): replaces field [name]'s value
  /// with [value] in [document], writes the file back, and re-parses it in
  /// place. An unknown field or an unchanged value is a no-op (`false`); the
  /// body and every other front-matter line are preserved, so the edit survives
  /// the next `generateContent`. Returns `true` when the file was rewritten.
  Future<bool> setCopyFrontMatterValue(
    ContentCopyDocument document,
    String name,
    String value,
  ) async {
    final updated = document.file.withFrontMatterValue(name, value);
    return _saveCopy(document, updated);
  }

  /// Persists a copy-file body edit (§16): writes [document] with its body
  /// replaced by [newBody] and re-parses it in place. The §6.2 managed regions
  /// and their markers round-trip untouched; pair with [ContentPage.withRegionBody]
  /// to edit a single override region. A no-op edit returns `false`.
  Future<bool> setCopyBody(
    ContentCopyDocument document,
    ContentPage newBody,
  ) async {
    final updated = document.file.withBody(newBody);
    return _saveCopy(document, updated);
  }

  /// Writes [updated] for [document] when it differs from the source, re-parses
  /// the document in place, and notifies. Returns `false` for a no-op.
  Future<bool> _saveCopy(
    ContentCopyDocument document,
    ContentCopyFile updated,
  ) async {
    final source = updated.serialize();
    if (source == document.source) return false;

    await writeFile(document.uri, source);
    final index = _copyFiles.indexWhere((d) => d.uri == document.uri);
    if (index >= 0) {
      final next = List.of(_copyFiles);
      next[index] = ContentCopyDocument(
          uri: document.uri,
          source: source,
          file: ContentCopyFile.parse(source));
      _copyFiles = next;
    }
    notifyListeners();
    return true;
  }

  /// Persists a page front-matter edit (§9 item 3): replaces field [name]'s
  /// value with [value] in [document] (e.g. the `route` that determines the
  /// page URL), writes the file back, and re-parses it in place. An unknown
  /// field or an unchanged value is a no-op (`false`); the body and every other
  /// front-matter line are preserved. Returns `true` when the file was
  /// rewritten.
  Future<bool> setPageFrontMatterValue(
    ContentPageDocument document,
    String name,
    String value,
  ) async {
    final updated = document.file.withFrontMatterValue(name, value);
    return _savePage(document, updated);
  }

  /// Persists a page body edit (§9 item 3): writes [document] with its body
  /// replaced by [newBody] and re-parses it in place. The `@tom:override` /
  /// `@tom:managed` regions and their markers round-trip untouched; pair with
  /// [ContentPage.withRegionBody] to edit a single override region. A no-op edit
  /// returns `false`.
  Future<bool> setPageBody(
    ContentPageDocument document,
    ContentPage newBody,
  ) async {
    final updated = document.file.withBody(newBody);
    return _savePage(document, updated);
  }

  /// Writes [updated] for page [document] when it differs from the source,
  /// re-parses the document in place, and notifies. Returns `false` for a no-op.
  Future<bool> _savePage(
    ContentPageDocument document,
    ContentCopyFile updated,
  ) async {
    final source = updated.serialize();
    if (source == document.source) return false;

    await writeFile(document.uri, source);
    final index = _pages.indexWhere((d) => d.uri == document.uri);
    if (index >= 0) {
      final next = List.of(_pages);
      next[index] = ContentPageDocument(
          uri: document.uri,
          source: source,
          file: ContentCopyFile.parse(source));
      _pages = next;
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

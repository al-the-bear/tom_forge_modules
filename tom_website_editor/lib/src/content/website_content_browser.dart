import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_website_editor_core/tom_website_editor_core.dart';

import '../structure/copy_naming.dart';
import 'content_copy_file.dart';
import 'content_field.dart';
import 'content_group.dart';
import 'content_record.dart';
import 'repo_doc.dart';
import 'website_content_controller.dart';

/// The human-readable maturity-ladder explanation shown under the managed
/// `status` field (§9 item 6).
///
/// Mirrors `tom_package_scanner`'s `ComponentStatus` ladder and names the
/// **`release.md`** release marker (formerly `RELEASED.md`) — the file a
/// package carries in its directory to reach the `released` status — so the
/// editor's status provenance matches the scanner that produces the value.
const String kStatusLadderHelp =
    'Generator-managed by tom_package_scanner. Maturity ladder: '
    'not_started → works → published → released. A package reaches "released" '
    'when it carries a release.md marker in its package directory '
    '(or buildkit.yaml release.state: released).';

/// Forge view for the §6a content browser: a component → module → optional
/// submodule tree (plus `site.yaml` and `pages/`) on the left and a field /
/// page detail pane on the right.
///
/// All catalog state lives in the [WebsiteContentController]; this view renders
/// it and drives the pin action on tap. Managed (generator-owned) fields are
/// shown read-only with a badge and a "pin" affordance; curated / pinned fields
/// route to the inline editor named by their typed suffix (`-md` → Markdown,
/// `-json` → JSON, else plain string). When the active website has no `content:`
/// block the view shows a disabled state. The controller is owned by the module
/// (created in `activate`, disposed in `deactivate`) — the view does not dispose
/// it.
///
/// Tapping a leaf opens its backing file through [onOpenFile] (§6a navigation):
/// a component record opens `content/components/<c>.yaml`, a page opens
/// `content/pages/<p>.md`, and `site.yaml` opens itself. Editor routing is then
/// automatic via each editor's `canHandle`, so no per-extension branching lives
/// here. When [onOpenFile] is `null` (e.g. the view rendered in isolation) taps
/// only update the detail pane.
class WebsiteContentBrowser extends ForgeView {
  WebsiteContentBrowser({required this.controller, this.onOpenFile});

  /// Owns the catalog, refresh, and pin flow.
  final WebsiteContentController controller;

  /// Open-file seam: the host wires this to `ForgeLayoutController.openFile`
  /// so a tap routes the file to the matching editor.
  final void Function(Uri uri)? onOpenFile;

  final _title = ValueNotifier<String>('Content');
  final _titleExtension = ValueNotifier<String?>(null);

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => Icons.folder_copy_outlined;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints(
        minSize: Size(480, 360),
        preferredSize: Size(720, 640),
      );

  @override
  Widget buildMain(BuildContext context) => _ContentBrowserBody(
        controller: controller,
        title: _title,
        onOpenFile: onOpenFile,
      );

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

/// A selected catalog node: a record (with its owning document) or a file.
class _Selection {
  const _Selection.record(this.record, this.document)
      : page = null,
        copy = null,
        site = false;
  const _Selection.page(this.page)
      : record = null,
        document = null,
        copy = null,
        site = false;
  const _Selection.site()
      : record = null,
        document = null,
        page = null,
        copy = null,
        site = true;

  /// An external editorial copy file (`content/copy/*.md`, §16): a site-level
  /// file (`home.md` / `news.md`) or a per-entity / area copy file.
  const _Selection.copy(this.copy)
      : record = null,
        document = null,
        page = null,
        site = false;

  final ContentRecord? record;
  final ContentComponentDocument? document;
  final Uri? page;
  final Uri? copy;
  final bool site;
}

/// A tree-visible record paired with its owning document and path label (e.g.
/// `Button › Primary › Large`). Used to scope the attribute search (item 2b).
class _RecordHit {
  const _RecordHit(this.record, this.document, this.path);

  final ContentRecord record;
  final ContentComponentDocument document;
  final String path;
}

/// One attribute-search result: a field, its owning record/document, and the
/// record's path label so hits from several modules can be told apart.
class _AttrHit {
  const _AttrHit(this.record, this.document, this.field, this.path);

  final ContentRecord record;
  final ContentComponentDocument document;
  final ContentField field;
  final String path;
}

class _ContentBrowserBody extends StatefulWidget {
  const _ContentBrowserBody({
    required this.controller,
    required this.title,
    this.onOpenFile,
  });

  final WebsiteContentController controller;
  final ValueNotifier<String> title;
  final void Function(Uri uri)? onOpenFile;

  @override
  State<_ContentBrowserBody> createState() => _ContentBrowserBodyState();
}

class _ContentBrowserBodyState extends State<_ContentBrowserBody> {
  _Selection? _selection;

  /// Tree search (§9, item 2a): matches a record's label by case-insensitive
  /// `contains`. A matched node reveals its full subtree; components with no
  /// matching descendant are pruned from the tree.
  String _query = '';

  /// Detail-pane attribute search (item 2b): two needles that filter fields by
  /// name and by value across the tree-visible records. When either is set the
  /// detail pane shows aggregated attribute hits instead of the selection.
  String _attrNameQuery = '';
  String _attrValueQuery = '';

  /// `true` when an attribute search is active (either needle is non-empty).
  bool get _attrSearchActive =>
      _attrNameQuery.trim().isNotEmpty || _attrValueQuery.trim().isNotEmpty;

  /// Routes [uri] to the host's editor (via the open seam) when one is wired.
  void _open(Uri uri) => widget.onOpenFile?.call(uri);

  /// `true` when an open seam is wired, so open affordances are enabled.
  bool get _canOpen => widget.onOpenFile != null;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    // An in-place edit (pin / field / groups) rebuilds the owning document, so
    // the selection's object references go stale. Re-resolve the selection
    // against the live controller state by identity (file uri + record id) so
    // the detail pane survives an edit; a selection whose backing file is gone
    // (e.g. after a website switch) is dropped.
    setState(() => _selection = _reresolveSelection(_selection));
  }

  /// Maps [previous] onto the current controller state by identity, returning a
  /// refreshed selection (new record/document instances) or `null` when its
  /// backing file/record no longer exists.
  _Selection? _reresolveSelection(_Selection? previous) {
    if (previous == null) return null;
    final controller = widget.controller;
    if (previous.site) {
      return controller.siteFile != null ? const _Selection.site() : null;
    }
    if (previous.page != null) {
      return controller.pages.any((d) => d.uri == previous.page)
          ? _Selection.page(previous.page!)
          : null;
    }
    if (previous.copy != null) {
      final stillPresent =
          controller.copyFiles.any((doc) => doc.uri == previous.copy);
      return stillPresent ? _Selection.copy(previous.copy!) : null;
    }
    final oldRecord = previous.record!;
    final oldUri = previous.document!.uri;
    for (final document in controller.components) {
      if (document.uri != oldUri) continue;
      final found =
          _findRecord(document.record, oldRecord.id, oldRecord.kind);
      if (found != null) return _Selection.record(found, document);
    }
    return null;
  }

  /// Depth-first search for the record with [id] and [kind] within [root]'s
  /// tree (component → module → submodule), used to re-resolve a selection
  /// after the owning document is rebuilt.
  static ContentRecord? _findRecord(
      ContentRecord root, String id, ContentRecordKind kind) {
    if (root.id == id && root.kind == kind) return root;
    for (final child in root.children) {
      final found = _findRecord(child, id, kind);
      if (found != null) return found;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (!controller.isEnabled) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This website has no "content:" block — the content browser is '
            'disabled. Add a content section to tom.website-editor.yaml to '
            'browse its data model.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final error = controller.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) _buildErrorBanner(context, error),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 280, child: _buildTree(context)),
              const VerticalDivider(width: 1),
              Expanded(child: _buildDetail(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              size: 16, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(color: theme.colorScheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }

  Widget _buildTree(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            key: const ValueKey('tree-filter'),
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 18),
              hintText: 'Filter by name',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(child: _buildTreeList(context)),
      ],
    );
  }

  Widget _buildTreeList(BuildContext context) {
    final controller = widget.controller;
    final needle = _query.trim().toLowerCase();
    final children = <Widget>[];
    var total = 0;

    for (final document in controller.components) {
      total++;
      final tile = _buildRecordTile(document.record, document, needle);
      if (tile != null) children.add(tile);
    }

    final site = controller.siteFile;
    if (site != null) {
      total++;
      if (needle.isEmpty || _fileName(site).toLowerCase().contains(needle)) {
        children.add(ListTile(
          dense: true,
          leading: const Icon(Icons.description_outlined, size: 18),
          title: Text(_fileName(site)),
          selected: _selection?.site ?? false,
          onTap: () {
            setState(() => _selection = const _Selection.site());
            _open(site);
          },
        ));
      }
    }

    for (final doc in controller.siteLevelCopyFiles) {
      total++;
      final name = _fileName(doc.uri);
      if (needle.isEmpty || name.toLowerCase().contains(needle)) {
        children.add(ListTile(
          dense: true,
          key: ValueKey('site-copy-$name'),
          leading: const Icon(Icons.menu_book_outlined, size: 18),
          title: Text(name),
          subtitle: const Text('Site copy'),
          selected: _selection?.copy == doc.uri,
          onTap: () {
            setState(() => _selection = _Selection.copy(doc.uri));
            _open(doc.uri);
          },
        ));
      }
    }

    // Per-entity, area, and any non-convention ("loose") copy files (§16). The
    // site-level home/news files are surfaced above; every remaining copy file
    // is enumerated here so no copy file in content/copy/ is ever dropped from
    // the browser (mirroring the §6b structure explorer's completeness). Each
    // tile's subtitle names what the file is copy for, so its target is visible
    // without opening the pane.
    for (final doc in controller.copyFiles) {
      final parsed = parseCopyFileName(_fileName(doc.uri));
      if (parsed != null && siteLevelCopyKinds.contains(parsed.kind)) continue;
      total++;
      final name = _fileName(doc.uri);
      if (needle.isEmpty || name.toLowerCase().contains(needle)) {
        children.add(ListTile(
          dense: true,
          key: ValueKey('copy-$name'),
          leading: Icon(_copyKindIcon(parsed), size: 18),
          title: Text(name),
          subtitle: Text(_copyKindLabel(parsed)),
          selected: _selection?.copy == doc.uri,
          onTap: () {
            setState(() => _selection = _Selection.copy(doc.uri));
            _open(doc.uri);
          },
        ));
      }
    }

    for (final page in controller.pages) {
      total++;
      if (needle.isEmpty ||
          _fileName(page.uri).toLowerCase().contains(needle)) {
        final route = page.file.frontMatterValue('route');
        children.add(ListTile(
          dense: true,
          leading: const Icon(Icons.article_outlined, size: 18),
          title: Text(_fileName(page.uri)),
          // Surface the page's route inline so its URL is visible in the tree
          // without opening the detail pane (§9 item 3).
          subtitle: route == null ? null : Text(route),
          selected: _selection?.page == page.uri,
          onTap: () {
            setState(() => _selection = _Selection.page(page.uri));
            _open(page.uri);
          },
        ));
      }
    }

    if (total == 0) {
      return const Center(child: Text('No content found.'));
    }
    if (children.isEmpty) {
      return const Center(child: Text('No content matches the filter.'));
    }
    return ListView(children: children);
  }

  /// Builds the tile for [record], or `null` when the record is pruned (item
  /// 2a): with a non-empty [needle], a record is shown only if its own label
  /// matches or one of its descendants does. A record whose own label matches
  /// reveals its full subtree (the child needle is cleared); an unmatched
  /// container keeps only the descendants that themselves match.
  Widget? _buildRecordTile(
      ContentRecord record, ContentComponentDocument document, String needle) {
    final selfMatch =
        needle.isEmpty || record.label.toLowerCase().contains(needle);
    final childNeedle = selfMatch ? '' : needle;
    final childTiles = <Widget>[];
    for (final child in record.children) {
      final tile = _buildRecordTile(child, document, childNeedle);
      if (tile != null) childTiles.add(tile);
    }
    if (!selfMatch && childTiles.isEmpty) return null;

    if (record.children.isEmpty) {
      return ListTile(
        dense: true,
        leading: Icon(_recordIcon(record.kind), size: 18),
        title: Text(record.label),
        selected: identical(_selection?.record, record),
        onTap: () {
          setState(() => _selection = _Selection.record(record, document));
          _open(document.uri);
        },
      );
    }
    return ExpansionTile(
      dense: true,
      initiallyExpanded: true,
      leading: Icon(_recordIcon(record.kind), size: 18),
      title: Text(record.label),
      childrenPadding: const EdgeInsets.only(left: 12),
      onExpansionChanged: (_) {},
      children: [
        ListTile(
          dense: true,
          leading: const Icon(Icons.tune, size: 16),
          title: const Text('Fields'),
          selected: identical(_selection?.record, record),
          onTap: () {
            setState(() => _selection = _Selection.record(record, document));
            _open(document.uri);
          },
        ),
        ...childTiles,
      ],
    );
  }

  Widget _buildDetail(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAttrSearchBar(context),
        const Divider(height: 1),
        Expanded(
          child: _attrSearchActive
              ? _buildAttrResults(context)
              : _buildSelectionDetail(context),
        ),
      ],
    );
  }

  /// The two attribute search fields (item 2b): one filters fields by name, the
  /// other by value. When either is active, [_buildAttrResults] replaces the
  /// selection detail with the aggregated hits across the tree-visible records.
  Widget _buildAttrSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('attr-name-search'),
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.label_outline, size: 18),
                hintText: 'Search attribute names',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _attrNameQuery = value),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: const ValueKey('attr-value-search'),
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 18),
                hintText: 'Search attribute values',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _attrValueQuery = value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionDetail(BuildContext context) {
    final selection = _selection;
    if (selection == null) {
      return const Center(child: Text('Select a record or page.'));
    }
    if (selection.site) {
      return _buildSitePane(context, widget.controller.siteFile!);
    }
    if (selection.page != null) {
      return _buildPagePane(context, selection.page!);
    }
    if (selection.copy != null) {
      final parsed = parseCopyFileName(_fileName(selection.copy!));
      return _buildFilePane(
          context, selection.copy!, _copyDetailDescription(parsed));
    }
    return _buildRecordPane(context, selection.record!, selection.document!);
  }

  Widget _buildRecordPane(BuildContext context, ContentRecord record,
      ContentComponentDocument document) {
    final theme = Theme.of(context);
    // The groups editor applies to components that have modules to group (or
    // already carry a hand-authored groups block). Modules/submodules and
    // module-less components show none.
    final showGroups = record.kind == ContentRecordKind.component &&
        (record.children.isNotEmpty || record.groups.isNotEmpty);
    final repoDocs = widget.controller.repoDocsFor(record.id);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(record.label, style: theme.textTheme.titleMedium),
        Text(record.kind.name, style: theme.textTheme.labelSmall),
        const SizedBox(height: 12),
        for (final field in record.fields)
          _fieldRow(context, record, document, field),
        if (showGroups)
          _GroupsEditor(
            key: ValueKey('groups-editor-${document.uri}'),
            record: record,
            document: document,
            controller: widget.controller,
          ),
        if (repoDocs.isNotEmpty)
          _RepoDocsSection(recordId: record.id, docs: repoDocs),
      ],
    );
  }

  /// The aggregated attribute hits (item 2b): every field, across the records
  /// the tree currently shows, whose name and value match the active needles.
  /// Each hit is labelled with its owning record's path so attributes from
  /// several modules can be told apart.
  Widget _buildAttrResults(BuildContext context) {
    final theme = Theme.of(context);
    final hits = _attributeHits();
    if (hits.isEmpty) {
      return const Center(child: Text('No attributes match the search.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final hit in hits)
          Padding(
            key: ValueKey('attr-hit-${hit.record.id}-${hit.field.name}'),
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(hit.path,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 4),
                _fieldRow(context, hit.record, hit.document, hit.field),
              ],
            ),
          ),
      ],
    );
  }

  /// Builds a [_FieldRow] with the pin / unpin / edit / open seams wired to the
  /// controller. Shared by the record pane and the attribute-search results so
  /// both render and act on fields identically.
  Widget _fieldRow(BuildContext context, ContentRecord record,
      ContentComponentDocument document, ContentField field) {
    return _FieldRow(
      field: field,
      provenance: record.provenance,
      onPin: field.isEditable
          ? null
          : () => widget.controller.pinField(document, field),
      // Unpin reverts a pinned field to generator-managed status; the value
      // stays until the next generate run replaces it (§6a).
      onUnpin: field.isPinned
          ? () => unawaited(widget.controller.unpinField(document, field))
          : null,
      // Inline edit for short scalar fields; `-md` / `-json` route to the full
      // editor (item 4) so the two paths don't fight.
      onCommit:
          field.isEditable && field.editorKind == ContentEditorKind.string
              ? (value) => unawaited(
                  widget.controller.setFieldValue(document, field, value))
              : null,
      onOpenFull: field.isEditable &&
              field.editorKind != ContentEditorKind.string &&
              _canOpen
          ? () => _open(document.uri)
          : null,
    );
  }

  /// Walks the components, collecting the records the tree currently shows
  /// (item 2a's visibility rule) with their path label. This is the scope the
  /// attribute search operates over — "only the modules that have been found".
  List<_RecordHit> _visibleRecords() {
    final needle = _query.trim().toLowerCase();
    final hits = <_RecordHit>[];
    for (final document in widget.controller.components) {
      _collectVisible(document.record, document, needle, '', hits);
    }
    return hits;
  }

  /// Appends [record] and its visible descendants to [out] when they pass the
  /// tree needle, mirroring [_buildRecordTile]'s pruning. The parent is inserted
  /// before its descendants so paths read top-down.
  void _collectVisible(ContentRecord record, ContentComponentDocument document,
      String needle, String parentPath, List<_RecordHit> out) {
    final selfMatch =
        needle.isEmpty || record.label.toLowerCase().contains(needle);
    final path =
        parentPath.isEmpty ? record.label : '$parentPath › ${record.label}';
    final childNeedle = selfMatch ? '' : needle;
    final before = out.length;
    for (final child in record.children) {
      _collectVisible(child, document, childNeedle, path, out);
    }
    final hasVisibleChild = out.length > before;
    if (selfMatch || hasVisibleChild) {
      out.insert(before, _RecordHit(record, document, path));
    }
  }

  /// Every field (across [_visibleRecords]) whose name contains the name needle
  /// and whose value contains the value needle (each empty needle matches all).
  List<_AttrHit> _attributeHits() {
    final nameNeedle = _attrNameQuery.trim().toLowerCase();
    final valueNeedle = _attrValueQuery.trim().toLowerCase();
    if (nameNeedle.isEmpty && valueNeedle.isEmpty) return const [];
    final hits = <_AttrHit>[];
    for (final rec in _visibleRecords()) {
      for (final field in rec.record.fields) {
        final nameOk = nameNeedle.isEmpty ||
            field.name.toLowerCase().contains(nameNeedle);
        final valueOk = valueNeedle.isEmpty ||
            field.value.toLowerCase().contains(valueNeedle);
        if (nameOk && valueOk) {
          hits.add(_AttrHit(rec.record, rec.document, field, rec.path));
        }
      }
    }
    return hits;
  }

  Widget _buildFilePane(BuildContext context, Uri uri, String note) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_fileName(uri), style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          SelectableText(uri.path, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(note, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _canOpen ? () => _open(uri) : null,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open in editor'),
            ),
          ),
        ],
      ),
    );
  }

  /// The detail pane for `site.yaml` (§9 item 4): shows the site title/tagline
  /// for context and lets the home page's featured component be set from a
  /// dropdown of the site's real component ids (plus "(none)"), so the value is
  /// always valid without hand-editing YAML. The featured component is optional
  /// — "(none)" clears it and the components page renders the flat grid. A
  /// live validation status sits below the picker, and the raw file is still
  /// reachable via "Open in editor".
  Widget _buildSitePane(BuildContext context, Uri uri) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    final config = controller.siteConfig;
    // A parse failure leaves no model — fall back to the read-only file pane so
    // the user can open and fix the YAML directly.
    if (config == null) {
      return _buildFilePane(context, uri,
          'Site-level config (site.yaml) — could not be parsed. Open it to fix '
          'the YAML.');
    }

    final componentIds = [
      for (final document in controller.components) document.record.id,
    ]..sort();
    final knownIds = componentIds.toSet();
    final featured = config.featured;
    final canEditFeatured = config.featuredSourceLine != null;
    // Include the current (possibly unknown) featured id so the dropdown never
    // asserts on a value outside its item list.
    final ids = <String>{...componentIds, ?featured}.toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(_fileName(uri), style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        SelectableText(uri.path, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          'Site-level config. The home page’s featured component is set below; '
          'leave it as “(none)” to render the flat components grid.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        if (config.title != null) _siteInfoRow(context, 'Title', config.title!),
        if (config.taglineMd != null)
          _siteInfoRow(context, 'Tagline', config.taglineMd!),
        const SizedBox(height: 8),
        Text('Home featured component', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          'The component highlighted on the home page. Optional — “(none)” '
          'renders the flat components grid.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 8),
        InputDecorator(
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              key: const ValueKey('site-featured-dropdown'),
              value: featured,
              isExpanded: true,
              onChanged: canEditFeatured
                  ? (value) =>
                      unawaited(widget.controller.setSiteFeatured(value))
                  : null,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('(none)'),
                ),
                for (final id in ids)
                  DropdownMenuItem<String?>(
                    value: id,
                    child: Text(knownIds.contains(id) ? id : '$id (unknown)'),
                  ),
              ],
            ),
          ),
        ),
        if (!canEditFeatured) ...[
          const SizedBox(height: 4),
          Text(
            'site.yaml has no home.featured key yet — open it in the editor to '
            'add one.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
        const SizedBox(height: 16),
        _buildDetailedComponentsEditor(context, config, componentIds, knownIds),
        const SizedBox(height: 16),
        _buildSiteValidation(context),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _canOpen ? () => _open(uri) : null,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open in editor'),
          ),
        ),
      ],
    );
  }

  /// A read-only label/value row for a `site.yaml` scalar (title / tagline)
  /// shown for context above the featured-component picker.
  Widget _siteInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 2),
          SelectableText(value, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  /// The detailed-content scope editor (§9 item 7): a chip per known component
  /// id, selected when the component is in `site.yaml: detailedComponents` —
  /// i.e. when its `/docs` + `/api` trees are exposed. Toggling a chip writes
  /// the list back to disk (inserting the key when absent), so the scope is
  /// edited in place without touching raw YAML.
  ///
  /// When the key is absent the chips render unselected with a note that the
  /// website is using its built-in default; the first toggle makes the scope
  /// explicit. Any id listed but not a known component is shown as a trailing
  /// "(unknown)" chip so a stale entry stays visible and removable.
  Widget _buildDetailedComponentsEditor(
    BuildContext context,
    SiteConfig config,
    List<String> componentIds,
    Set<String> knownIds,
  ) {
    final theme = Theme.of(context);
    final selected = config.detailedComponents?.toSet() ?? const <String>{};
    final hasExplicitScope = config.detailedComponents != null;
    // Union of known ids and any explicitly-listed (possibly unknown) ids, so a
    // stale entry remains visible and toggle-off-able.
    final chipIds = <String>{...componentIds, ...selected}.toList()..sort();

    return Column(
      key: const ValueKey('site-detailed-components'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Detailed docs/API components', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          'The components whose /docs and /api trees the site exposes. The '
          'others still appear in Overview, Areas and Components but carry no '
          'detail. Tap a chip to add or remove it from the scope.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final id in chipIds)
              FilterChip(
                key: ValueKey('site-detailed-chip-$id'),
                label: Text(knownIds.contains(id) ? id : '$id (unknown)'),
                selected: selected.contains(id),
                onSelected: (value) =>
                    _toggleDetailedComponent(config, id, value),
              ),
          ],
        ),
        if (!hasExplicitScope) ...[
          const SizedBox(height: 4),
          Text(
            'No explicit scope set — the website uses its built-in default. '
            'Select a component to make the scope explicit.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ] else if (selected.isEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Scope is empty — no component exposes /docs or /api detail.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ],
    );
  }

  /// Adds or removes [id] from the detailed-content scope and persists the new
  /// list. Preserves the authored order: an added id is appended, a removed id
  /// is dropped in place.
  void _toggleDetailedComponent(SiteConfig config, String id, bool selected) {
    final next = config.detailedComponents?.toList() ?? <String>[];
    if (selected) {
      if (!next.contains(id)) next.add(id);
    } else {
      next.remove(id);
    }
    unawaited(widget.controller.setSiteDetailedComponents(next));
  }

  /// The live `site.yaml` validation status: a green "valid" line when there
  /// are no issues, or one row per issue (error or warning) otherwise. An empty
  /// `home.featured` produces no issue; an unknown featured id is a warning.
  Widget _buildSiteValidation(BuildContext context) {
    final theme = Theme.of(context);
    final issues = widget.controller.siteIssues;
    if (issues.isEmpty) {
      return Row(
        key: const ValueKey('site-validation-ok'),
        children: [
          Icon(Icons.check_circle_outline,
              size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text('site.yaml is valid.', style: theme.textTheme.bodySmall),
        ],
      );
    }
    return Column(
      key: const ValueKey('site-validation-issues'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final issue in issues)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  issue.severity == ConfigSeverity.error
                      ? Icons.error_outline
                      : Icons.warning_amber_rounded,
                  size: 16,
                  color: issue.severity == ConfigSeverity.error
                      ? theme.colorScheme.error
                      : theme.colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${issue.path}: ${issue.message}',
                      style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// The detail pane for a standalone page (§9 item 3): its `title` / `route`
  /// front-matter scalars are editable inline (the `route` determines the page's
  /// URL), and the region-aware body opens in the Markdown editor where the
  /// `@tom:override` / `@tom:managed` regions round-trip. Edits persist through
  /// [WebsiteContentController.setPageFrontMatterValue].
  Widget _buildPagePane(BuildContext context, Uri uri) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    ContentPageDocument? document;
    for (final doc in controller.pages) {
      if (doc.uri == uri) {
        document = doc;
        break;
      }
    }
    // A page whose backing file vanished (e.g. mid-refresh) falls back to the
    // read-only file pane rather than throwing.
    if (document == null) {
      return _buildFilePane(context, uri, 'Standalone page.');
    }

    final frontMatter = document.file.frontMatter;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(_fileName(uri), style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        SelectableText(uri.path, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          'Standalone page. The front-matter scalars below are editable; the '
          'route determines the page URL. Override (@tom:override) body '
          'regions are editable in the Markdown editor; managed '
          '(@tom:managed) regions are regenerated.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        if (frontMatter.isEmpty)
          Text('This page has no front-matter.',
              style: theme.textTheme.bodySmall)
        else ...[
          Text('Front matter', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          for (final field in frontMatter)
            _PageFrontMatterRow(
              key: ValueKey('page-field-${field.name}'),
              field: field,
              // Inline edit for short scalar fields; `-md` / `-json` route to
              // the full editor so the two paths don't fight.
              onCommit:
                  field.editorKind == ContentEditorKind.string
                      ? (value) => unawaited(controller.setPageFrontMatterValue(
                          document!, field.name, value))
                      : null,
              onOpenFull: field.editorKind != ContentEditorKind.string &&
                      _canOpen
                  ? () => _open(uri)
                  : null,
            ),
        ],
        const SizedBox(height: 16),
        Text('Body', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _canOpen ? () => _open(uri) : null,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open in editor'),
          ),
        ),
      ],
    );
  }

  static IconData _recordIcon(ContentRecordKind kind) => switch (kind) {
        ContentRecordKind.component => Icons.widgets_outlined,
        ContentRecordKind.module => Icons.view_module_outlined,
        ContentRecordKind.submodule => Icons.subdirectory_arrow_right,
      };

  static String _fileName(Uri uri) =>
      uri.pathSegments.isEmpty ? uri.toString() : uri.pathSegments.last;

  /// The tree-tile icon for a non-site-level copy file, by its parsed [name]
  /// (`null` for a file whose name does not follow the §16 convention).
  static IconData _copyKindIcon(CopyName? name) => switch (name?.kind) {
        CopyFileKind.area => Icons.dashboard_outlined,
        CopyFileKind.component => Icons.widgets_outlined,
        CopyFileKind.module => Icons.view_module_outlined,
        CopyFileKind.submodule => Icons.subdirectory_arrow_right,
        _ => Icons.menu_book_outlined,
      };

  /// The tree-tile subtitle for a non-site-level copy file: names what entity
  /// the file is copy for (e.g. "Module copy · auth › login") so its target is
  /// visible without opening the pane. A non-convention name is labelled so it
  /// is clearly surfaced rather than silently dropped (§16).
  static String _copyKindLabel(CopyName? name) {
    if (name == null) return 'Copy file (non-standard name)';
    final target = name.parts.join(' › ');
    return switch (name.kind) {
      CopyFileKind.home => 'Site copy',
      CopyFileKind.news => 'Site copy',
      CopyFileKind.area => 'Area copy · $target',
      CopyFileKind.component => 'Component copy · $target',
      CopyFileKind.module => 'Module copy · $target',
      CopyFileKind.submodule => 'Submodule copy · $target',
    };
  }

  /// The detail-pane routing description for a selected copy file, by its parsed
  /// [name]. Site-level copy names the home/news routing; per-entity copy names
  /// the entity it documents. Both edit the Markdown body in tom_md_editor.
  static String _copyDetailDescription(CopyName? name) {
    if (name == null) {
      return 'Editorial copy file (§16). Its name does not match the '
          'home/news/<entity> convention; edits the Markdown body in '
          'tom_md_editor.';
    }
    switch (name.kind) {
      case CopyFileKind.home:
      case CopyFileKind.news:
        return 'Site-level copy (§16). Edits the Markdown body in '
            'tom_md_editor; news.md feeds the home page news band.';
      case CopyFileKind.area:
      case CopyFileKind.component:
      case CopyFileKind.module:
      case CopyFileKind.submodule:
        final target = name.parts.join(' › ');
        return '${_copyKindLabel(name).split(' · ').first} for "$target" '
            '(§16). Front-matter carries the curated fields '
            '(tagline / summary / enables); the overview is the Markdown body, '
            'edited in tom_md_editor.';
    }
  }
}

/// One field row: managed fields show a read-only value, a "managed" badge and a
/// pin button; editable fields show the inline editor named by their typed
/// suffix.
/// The read-only "Repository documents" section (§9 item 5): the record's
/// repo-sourced `README` / `LICENSE` / `release.md`, surfaced as provenance.
///
/// These live in the upstream repository (resolved server-side from
/// `sourceRoot`), so they are shown visible + badged read-only and are never
/// offered for inline edit or pinning — distinguishing repo-owned docs from the
/// editable copy and generator-managed fields above.
class _RepoDocsSection extends StatelessWidget {
  const _RepoDocsSection({required this.recordId, required this.docs});

  /// The owning record's id, for per-row test keys.
  final String recordId;

  /// The discovered repo docs, in display order (README, LICENSE, release).
  final List<RepoDocRef> docs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: ValueKey('repo-docs-$recordId'),
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Repository documents', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Sourced from the upstream repository — read-only here. Edit these '
            'in the source repo; the editor never regenerates or pins them.',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 8),
          for (final doc in docs) _repoDocRow(context, doc),
        ],
      ),
    );
  }

  /// One read-only repo-doc row: the doc label, its discovered file name, and a
  /// "repo-sourced" badge. Keyed `repo-doc-<recordId>-<kind>` (badge keyed
  /// `repo-doc-badge-<recordId>-<kind>`) for tests.
  Widget _repoDocRow(BuildContext context, RepoDocRef doc) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.secondary;
    return Padding(
      key: ValueKey('repo-doc-$recordId-${doc.kind.name}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.menu_book_outlined, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.kind.label,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(doc.fileName,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontFamily: 'monospace')),
              ],
            ),
          ),
          Tooltip(
            message: 'Lives in the upstream repository (${doc.fileName}) — '
                'read-only here; never regenerated or pinned by the editor.',
            child: Container(
              key: ValueKey('repo-doc-badge-$recordId-${doc.kind.name}'),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 11, color: color),
                  const SizedBox(width: 3),
                  Text('repo-sourced',
                      style:
                          theme.textTheme.labelSmall?.copyWith(color: color)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.field,
    required this.onPin,
    this.onUnpin,
    this.provenance,
    this.onCommit,
    this.onOpenFull,
  });

  final ContentField field;

  /// The owning record's `_generated` provenance (§6a); shown as a tooltip on
  /// managed fields. `null` when the record has no `_generated` block.
  final String? provenance;

  /// Pin callback (managed fields only); `null` for editable fields.
  final VoidCallback? onPin;

  /// Unpin callback (pinned fields only); `null` for non-pinned fields. Reverts
  /// the field to generator-managed status.
  final VoidCallback? onUnpin;

  /// Persist an inline scalar edit (editable string fields only); `null` when
  /// the field is managed or routes to the full editor.
  final ValueChanged<String>? onCommit;

  /// Open the field's backing file in the full editor (editable `-md` / `-json`
  /// fields); `null` when no open seam is wired or the field edits inline.
  final VoidCallback? onOpenFull;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(field.name,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              _badge(context),
              if (!field.isEditable && provenance != null) ...[
                const SizedBox(width: 4),
                _provenanceBadge(context, provenance!),
              ],
              if (field.isPinned && onUnpin != null) ...[
                const SizedBox(width: 4),
                TextButton.icon(
                  key: ValueKey('unpin-${field.name}'),
                  icon: const Icon(Icons.push_pin, size: 14),
                  label: const Text('Unpin'),
                  onPressed: onUnpin,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          if (field.isEditable)
            _EditableField(
              field: field,
              onCommit: onCommit,
              onOpenFull: onOpenFull,
            )
          else
            _ManagedValue(field: field, onPin: onPin),
          if (field.name == 'status') _statusLadderHint(context),
          if (valueHasPlaceholder(field.value)) _placeholderHint(context),
        ],
      ),
    );
  }

  /// The classification badge — pinned / editable / managed — with a tooltip
  /// explaining its lifecycle. Keyed `badge-<name>` so tests can target it.
  Widget _badge(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color, tip) = field.isPinned
        ? (
            'pinned',
            theme.colorScheme.primary,
            'Pinned with the manual marker (@manual) — protected from '
                'regeneration.',
          )
        : field.isEditable
            ? (
                'editable',
                theme.colorScheme.tertiary,
                'Hand-curated — edits are kept across regeneration.',
              )
            : (
                'managed',
                theme.colorScheme.outline,
                'Generator-managed — replaced on the next regenerate unless '
                    'pinned.',
              );
    return Tooltip(
      message: tip,
      child: Container(
        key: ValueKey('badge-${field.name}'),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: theme.textTheme.labelSmall?.copyWith(color: color)),
      ),
    );
  }

  /// A "generated" badge whose tooltip carries the record's `_generated`
  /// provenance. Keyed `provenance-<name>` for tests.
  Widget _provenanceBadge(BuildContext context, String detail) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.secondary;
    return Tooltip(
      message: 'Generated · $detail',
      child: Container(
        key: ValueKey('provenance-${field.name}'),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 11, color: color),
            const SizedBox(width: 3),
            Text('generated',
                style: theme.textTheme.labelSmall?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }

  /// A help hint explaining the component/module maturity ladder and the
  /// `release.md` release marker (§9 item 6). Shown under the managed `status`
  /// field so the reader sees, in place, what each status means and how a
  /// package reaches "released" — without hunting through the scanner docs.
  /// Keyed `status-ladder-hint` for tests.
  Widget _statusLadderHint(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.secondary;
    return Padding(
      key: const ValueKey('status-ladder-hint'),
      padding: const EdgeInsets.only(top: 4),
      child: Tooltip(
        message: kStatusLadderHelp,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.timeline_outlined, size: 13, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(kStatusLadderHelp,
                  style: theme.textTheme.labelSmall?.copyWith(color: color)),
            ),
          ],
        ),
      ),
    );
  }

  /// A hint marking a value that contains a §3 placeholder, which resolves only
  /// when the generator runs. Keyed `placeholder-hint-<name>` for tests.
  Widget _placeholderHint(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.tertiary;
    return Padding(
      key: ValueKey('placeholder-hint-${field.name}'),
      padding: const EdgeInsets.only(top: 4),
      child: Tooltip(
        message: 'Contains a {placeholder} (§3) — the literal value is '
            'computed when the website regenerates.',
        child: Row(
          children: [
            Icon(Icons.bolt_outlined, size: 13, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Text('Placeholder — resolves at generate time',
                  style: theme.textTheme.labelSmall?.copyWith(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A read-only managed value with a "pin (# @manual)" affordance.
class _ManagedValue extends StatelessWidget {
  const _ManagedValue({required this.field, required this.onPin});

  final ContentField field;
  final VoidCallback? onPin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              field.value.isEmpty ? '—' : field.value,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontFamily: 'monospace'),
            ),
          ),
          if (onPin != null)
            TextButton.icon(
              icon: const Icon(Icons.push_pin_outlined, size: 14),
              label: const Text('Pin'),
              onPressed: onPin,
            ),
        ],
      ),
    );
  }
}

/// An editable field. Short scalar (`string`) fields edit inline and persist on
/// submit via [onCommit]; `-md` / `-json` fields are not edited inline (that
/// would fight the full editor item 4 routes to) — they show a read-only preview
/// and an open-in-editor affordance ([onOpenFull]).
class _EditableField extends StatefulWidget {
  const _EditableField({required this.field, this.onCommit, this.onOpenFull});

  final ContentField field;

  /// Persist the committed scalar value (string fields).
  final ValueChanged<String>? onCommit;

  /// Open the backing file in the full editor (`-md` / `-json` fields).
  final VoidCallback? onOpenFull;

  @override
  State<_EditableField> createState() => _EditableFieldState();
}

class _EditableFieldState extends State<_EditableField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.field.value);

  @override
  void didUpdateWidget(covariant _EditableField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync when the bound field's value changes underneath us (e.g. a refresh
    // after a save), without clobbering text the user is actively typing.
    if (oldWidget.field.value != widget.field.value &&
        _controller.text != widget.field.value) {
      _controller.text = widget.field.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    final key = ValueKey('content-field-${field.name}');
    if (field.editorKind == ContentEditorKind.string) {
      return TextField(
        key: key,
        controller: _controller,
        maxLines: 1,
        onSubmitted: widget.onCommit,
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          helperText: _editorLabel(field.editorKind),
        ),
      );
    }
    return _FullEditorField(
      fieldKey: key,
      value: field.value,
      label: _editorLabel(field.editorKind),
      onOpenFull: widget.onOpenFull,
    );
  }

  static String _editorLabel(ContentEditorKind kind) => switch (kind) {
        ContentEditorKind.markdown => 'Markdown',
        ContentEditorKind.json => 'JSON',
        ContentEditorKind.string => 'Text',
      };
}

/// One editable page front-matter row (§9 item 3): the field [name] as a label
/// and an inline [TextField] for short scalars (`title`, `route`), or a
/// full-editor handoff for `-md` / `-json` typed fields. Mirrors [_EditableField]
/// but binds to a [CopyFrontMatterField] (page/copy front-matter), persisting on
/// submit via [onCommit].
class _PageFrontMatterRow extends StatefulWidget {
  const _PageFrontMatterRow({
    super.key,
    required this.field,
    this.onCommit,
    this.onOpenFull,
  });

  final CopyFrontMatterField field;

  /// Persist the committed scalar value (string fields).
  final ValueChanged<String>? onCommit;

  /// Open the backing file in the full editor (`-md` / `-json` fields).
  final VoidCallback? onOpenFull;

  @override
  State<_PageFrontMatterRow> createState() => _PageFrontMatterRowState();
}

class _PageFrontMatterRowState extends State<_PageFrontMatterRow> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.field.value);

  @override
  void didUpdateWidget(covariant _PageFrontMatterRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync when the bound field's value changes underneath us (e.g. a refresh
    // after a save), without clobbering text the user is actively typing.
    if (oldWidget.field.value != widget.field.value &&
        _controller.text != widget.field.value) {
      _controller.text = widget.field.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final field = widget.field;
    final key = ValueKey('page-field-input-${field.name}');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(field.name, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          if (field.editorKind == ContentEditorKind.string)
            TextField(
              key: key,
              controller: _controller,
              maxLines: 1,
              onSubmitted: widget.onCommit,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
            )
          else
            _FullEditorField(
              fieldKey: key,
              value: field.value,
              label: field.editorKind == ContentEditorKind.markdown
                  ? 'Markdown'
                  : 'JSON',
              onOpenFull: widget.onOpenFull,
            ),
        ],
      ),
    );
  }
}

/// The component's module-groups editor (§9 item 1): add / rename / reorder
/// groups and assign module ids to them. The groups are hand-authored and
/// survive regeneration; this section reads [ContentRecord.groups] and persists
/// every edit through [WebsiteContentController.setGroups], which validates that
/// each assigned id resolves to a real module of the component.
///
/// The "Add member" menu offers only the component's real modules not already
/// in the group, so an unresolvable id can never be introduced from the UI; a
/// stale member left over from a hand edit is surfaced as a read-only warning.
class _GroupsEditor extends StatelessWidget {
  const _GroupsEditor({
    super.key,
    required this.record,
    required this.document,
    required this.controller,
  });

  final ContentRecord record;
  final ContentComponentDocument document;
  final WebsiteContentController controller;

  /// Persists [groups] (the validated, member-resolving list) for this
  /// component's document.
  void _apply(List<ContentGroup> groups) =>
      unawaited(controller.setGroups(document, groups));

  void _addGroup() => _apply([
        ...record.groups,
        const ContentGroup(label: 'New group', members: []),
      ]);

  void _renameGroup(int index, String label) {
    final next = List.of(record.groups);
    next[index] = next[index].copyWith(label: label);
    _apply(next);
  }

  void _deleteGroup(int index) {
    final next = List.of(record.groups)..removeAt(index);
    _apply(next);
  }

  void _moveGroup(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= record.groups.length) return;
    final next = List.of(record.groups);
    final moved = next.removeAt(index);
    next.insert(target, moved);
    _apply(next);
  }

  void _addMember(int index, String moduleId) {
    final next = List.of(record.groups);
    next[index] =
        next[index].copyWith(members: [...next[index].members, moduleId]);
    _apply(next);
  }

  void _removeMember(int index, String moduleId) {
    final next = List.of(record.groups);
    next[index] = next[index].copyWith(
        members: next[index].members.where((m) => m != moduleId).toList());
    _apply(next);
  }

  /// The module label for [id], falling back to the id when unresolved.
  String _moduleLabel(String id) {
    for (final child in record.children) {
      if (child.id == id) return child.label;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = record.groups;
    final ungrouped = record.ungroupedModuleIds;
    final unknown = record.unknownGroupMembers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Divider(),
        Row(
          children: [
            Expanded(
              child: Text('Module groups',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            TextButton.icon(
              key: const ValueKey('add-group'),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add group'),
              onPressed: _addGroup,
            ),
          ],
        ),
        Text(
          'Hand-authored groupings of this component’s modules. Editable '
          'and preserved across regeneration; modules left out fall under '
          '“Other modules” on the page.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 8),
        if (unknown.isNotEmpty) _buildUnknownWarning(context, unknown),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No groups yet.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic)),
          )
        else
          for (var i = 0; i < groups.length; i++)
            _buildGroupCard(context, i, groups[i]),
        const SizedBox(height: 12),
        _buildOtherModules(context, ungrouped),
      ],
    );
  }

  Widget _buildUnknownWarning(BuildContext context, Set<String> unknown) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('groups-unknown-warning'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 16, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Unknown member id(s): ${unknown.join(', ')} — these do not '
              'resolve to a module of this component. Remove them to clear the '
              'warning.',
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, int index, ContentGroup group) {
    final theme = Theme.of(context);
    final available = [
      for (final child in record.children)
        if (!group.members.contains(child.id)) child.id,
    ];
    return Card(
      key: ValueKey('group-card-$index'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _GroupLabelField(
                    key: ValueKey('group-label-$index'),
                    label: group.label,
                    onCommit: (value) => _renameGroup(index, value),
                  ),
                ),
                IconButton(
                  key: ValueKey('group-up-$index'),
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  tooltip: 'Move up',
                  onPressed: index == 0 ? null : () => _moveGroup(index, -1),
                ),
                IconButton(
                  key: ValueKey('group-down-$index'),
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  tooltip: 'Move down',
                  onPressed: index == record.groups.length - 1
                      ? null
                      : () => _moveGroup(index, 1),
                ),
                IconButton(
                  key: ValueKey('group-delete-$index'),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Delete group',
                  onPressed: () => _deleteGroup(index),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final member in group.members)
                  InputChip(
                    key: ValueKey('group-member-$index-$member'),
                    label: Text(_moduleLabel(member)),
                    onDeleted: () => _removeMember(index, member),
                    deleteIcon: Icon(Icons.close,
                        key: ValueKey('group-member-remove-$index-$member'),
                        size: 16),
                  ),
                if (available.isEmpty && group.members.isEmpty)
                  Text('No modules assigned.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic)),
                if (available.isNotEmpty)
                  PopupMenuButton<String>(
                    key: ValueKey('group-add-member-$index'),
                    tooltip: 'Assign a module',
                    onSelected: (moduleId) => _addMember(index, moduleId),
                    itemBuilder: (context) => [
                      for (final moduleId in available)
                        PopupMenuItem<String>(
                          key: ValueKey('group-assign-$index-$moduleId'),
                          value: moduleId,
                          child: Text(_moduleLabel(moduleId)),
                        ),
                    ],
                    child: Chip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: const Text('Add module'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherModules(BuildContext context, List<String> ungrouped) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('groups-other-modules'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Other modules',
            style: theme.textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        if (ungrouped.isEmpty)
          Text('All modules are grouped.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontStyle: FontStyle.italic))
        else
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final id in ungrouped)
                Chip(
                  key: ValueKey('other-module-$id'),
                  label: Text(_moduleLabel(id)),
                ),
            ],
          ),
      ],
    );
  }
}

/// An inline, commit-on-submit text field for a group's label. Keeps its own
/// [TextEditingController] and re-syncs when the bound [label] changes under it
/// (e.g. after a save re-parses the document), mirroring [_EditableFieldState].
class _GroupLabelField extends StatefulWidget {
  const _GroupLabelField({
    super.key,
    required this.label,
    required this.onCommit,
  });

  final String label;
  final ValueChanged<String> onCommit;

  @override
  State<_GroupLabelField> createState() => _GroupLabelFieldState();
}

class _GroupLabelFieldState extends State<_GroupLabelField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.label);

  @override
  void didUpdateWidget(covariant _GroupLabelField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.label != widget.label &&
        _controller.text != widget.label) {
      _controller.text = widget.label;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      maxLines: 1,
      onSubmitted: widget.onCommit,
      decoration: const InputDecoration(
        isDense: true,
        labelText: 'Group label',
        border: OutlineInputBorder(),
      ),
    );
  }
}

/// A read-only preview of a `-md` / `-json` field with an open-in-editor button
/// that routes the backing file to the full editor (item 4).
class _FullEditorField extends StatelessWidget {
  const _FullEditorField({
    required this.fieldKey,
    required this.value,
    required this.label,
    required this.onOpenFull,
  });

  final Key fieldKey;
  final String value;
  final String label;
  final VoidCallback? onOpenFull;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: fieldKey,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '—' : value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style:
                theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onOpenFull,
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('Open in editor'),
            ),
          ),
        ],
      ),
    );
  }
}

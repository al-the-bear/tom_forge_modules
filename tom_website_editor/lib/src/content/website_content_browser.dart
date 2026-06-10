import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'content_field.dart';
import 'content_record.dart';
import 'website_content_controller.dart';

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
        site = false;
  const _Selection.page(this.page)
      : record = null,
        document = null,
        site = false;
  const _Selection.site()
      : record = null,
        document = null,
        page = null,
        site = true;

  final ContentRecord? record;
  final ContentComponentDocument? document;
  final Uri? page;
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
    // A refresh rebuilds documents, so a stale selection must be dropped.
    setState(() => _selection = null);
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

    for (final page in controller.pages) {
      total++;
      if (needle.isEmpty || _fileName(page).toLowerCase().contains(needle)) {
        children.add(ListTile(
          dense: true,
          leading: const Icon(Icons.article_outlined, size: 18),
          title: Text(_fileName(page)),
          selected: _selection?.page == page,
          onTap: () {
            setState(() => _selection = _Selection.page(page));
            _open(page);
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
      return _buildFilePane(context, widget.controller.siteFile!,
          'Site-level copy (site.yaml).');
    }
    if (selection.page != null) {
      return _buildFilePane(context, selection.page!,
          'Standalone page. Override (@tom:override) regions are editable; '
          'managed (@tom:managed) regions are regenerated.');
    }
    return _buildRecordPane(context, selection.record!, selection.document!);
  }

  Widget _buildRecordPane(BuildContext context, ContentRecord record,
      ContentComponentDocument document) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(record.label, style: theme.textTheme.titleMedium),
        Text(record.kind.name, style: theme.textTheme.labelSmall),
        const SizedBox(height: 12),
        for (final field in record.fields)
          _fieldRow(context, record, document, field),
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

  static IconData _recordIcon(ContentRecordKind kind) => switch (kind) {
        ContentRecordKind.component => Icons.widgets_outlined,
        ContentRecordKind.module => Icons.view_module_outlined,
        ContentRecordKind.submodule => Icons.subdirectory_arrow_right,
      };

  static String _fileName(Uri uri) =>
      uri.pathSegments.isEmpty ? uri.toString() : uri.pathSegments.last;
}

/// One field row: managed fields show a read-only value, a "managed" badge and a
/// pin button; editable fields show the inline editor named by their typed
/// suffix.
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

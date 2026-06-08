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
    final controller = widget.controller;
    final children = <Widget>[];

    for (final document in controller.components) {
      children.add(_buildRecordTile(document.record, document));
    }

    final site = controller.siteFile;
    if (site != null) {
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

    for (final page in controller.pages) {
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

    if (children.isEmpty) {
      return const Center(child: Text('No content found.'));
    }
    return ListView(children: children);
  }

  Widget _buildRecordTile(
      ContentRecord record, ContentComponentDocument document) {
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
        for (final child in record.children)
          _buildRecordTile(child, document),
      ],
    );
  }

  Widget _buildDetail(BuildContext context) {
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
          _FieldRow(
            field: field,
            onPin: field.isEditable
                ? null
                : () => widget.controller.pinField(document, field),
          ),
      ],
    );
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
  const _FieldRow({required this.field, required this.onPin});

  final ContentField field;

  /// Pin callback (managed fields only); `null` for editable fields.
  final VoidCallback? onPin;

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
            ],
          ),
          const SizedBox(height: 4),
          if (field.isEditable)
            _EditableField(field: field)
          else
            _ManagedValue(field: field, onPin: onPin),
        ],
      ),
    );
  }

  Widget _badge(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = field.isPinned
        ? ('pinned', theme.colorScheme.primary)
        : field.isEditable
            ? ('editable', theme.colorScheme.tertiary)
            : ('managed', theme.colorScheme.outline);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: theme.textTheme.labelSmall?.copyWith(color: color)),
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

/// An editable field rendered with the inline editor named by its typed suffix:
/// `-md` Markdown, `-json` JSON (both multi-line, monospace), else a plain
/// single-line string.
class _EditableField extends StatelessWidget {
  const _EditableField({required this.field});

  final ContentField field;

  @override
  Widget build(BuildContext context) {
    final multiline = field.editorKind != ContentEditorKind.string;
    return TextField(
      key: ValueKey('content-field-${field.name}'),
      controller: TextEditingController(text: field.value),
      maxLines: multiline ? 6 : 1,
      style: multiline
          ? const TextStyle(fontFamily: 'monospace', fontSize: 13)
          : null,
      decoration: InputDecoration(
        isDense: true,
        border: const OutlineInputBorder(),
        helperText: _editorLabel(field.editorKind),
      ),
    );
  }

  static String _editorLabel(ContentEditorKind kind) => switch (kind) {
        ContentEditorKind.markdown => 'Markdown',
        ContentEditorKind.json => 'JSON',
        ContentEditorKind.string => 'Text',
      };
}

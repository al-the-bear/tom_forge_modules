import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:tom_dart_editor/tom_dart_editor.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import '../structure/review_controls.dart';
import '../structure/review_store.dart';
import '../structure/spec_model.dart';
import 'markdown_io_dialog.dart';
import 'root_navigator.dart';
import 'spec_document_controller.dart';
import 'spec_markdown.dart';

/// The model-driven document editor (§13).
///
/// Walks the [SpecModel] class graph for the active root and renders each
/// `SpecField` by kind, backed by the shared [SpecDocumentController] so the
/// human UI and the agent tools (§8) edit one document. The body is a compact,
/// variable-height tree (§13.1): empty nodes/subtrees collapse to a single
/// clickable chip that inline-expands the editor in place; non-empty nodes
/// render expanded; lists carry add/remove.
///
/// The active root is driven by the §14 root navigator through the shared
/// [SpecDocumentController] (step 20): the editor projects the *same* document
/// through whichever root is selected (Project Definition by default), so
/// switching roots re-renders consistently without copying data. An optional
/// fixed [rootType] override pins a single projection (used by focused tests).
class SpecDocumentEditor extends ForgeEditor {
  SpecDocumentEditor({
    required this.controller,
    this.rootType,
    String title = 'Document',
  })  : _title = ValueNotifier<String>(title),
        _titleExtension = ValueNotifier<String?>(null),
        _isDirty = ValueNotifier<bool>(controller.isDirty),
        uri = Uri(scheme: 'specs', host: 'docspecs', path: '/document') {
    controller.addListener(_syncDirty);
  }

  /// The shared document controller (also driven by the agent tools).
  final SpecDocumentController controller;

  /// The root type/section id to render; null selects the model's first root.
  final String? rootType;

  final ValueNotifier<String> _title;
  final ValueNotifier<String?> _titleExtension;
  final ValueNotifier<bool> _isDirty;

  void _syncDirty() => _isDirty.value = controller.isDirty;

  @override
  final Uri uri;

  @override
  IconData get icon => Icons.article_outlined;

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  ValueListenable<bool> get isDirty => _isDirty;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  void markClean() => _isDirty.value = false;

  // The document editor is a fixed split, not a file-routing target.
  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.reject;

  @override
  Widget buildMain(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MarkdownIoBar(controller: controller),
          Expanded(
            child:
                SpecDocumentTreeView(controller: controller, rootType: rootType),
          ),
        ],
      );

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

/// The §15.2 markdown import/export action bar above the document tree.
class _MarkdownIoBar extends StatelessWidget {
  const _MarkdownIoBar({required this.controller});

  final SpecDocumentController controller;

  Future<void> _export(BuildContext context) async {
    await controller.ensureLoaded();
    if (!context.mounted) return;
    await showMarkdownExportDialog(context, controller);
  }

  Future<void> _import(BuildContext context) async {
    await controller.ensureLoaded();
    if (!context.mounted) return;
    await showMarkdownImportDialog(context, controller);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: () => _export(context),
              icon: const Icon(Icons.upload_file_outlined, size: 16),
              label: const Text('Export md'),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: () => _import(context),
              icon: const Icon(Icons.download_outlined, size: 16),
              label: const Text('Import md'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loads the model then renders the compact document tree for the active root.
class SpecDocumentTreeView extends StatelessWidget {
  const SpecDocumentTreeView({
    super.key,
    required this.controller,
    this.rootType,
  });

  final SpecDocumentController controller;
  final String? rootType;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SpecModel>(
      future: controller.ensureLoaded(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Failed to load model:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          );
        }
        final model = snapshot.data;
        if (model == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return SpecDocumentTree(
          controller: controller,
          model: model,
          rootType: rootType,
        );
      },
    );
  }
}

/// The compact, value-backed document tree (§13.1).
class SpecDocumentTree extends StatefulWidget {
  const SpecDocumentTree({
    super.key,
    required this.controller,
    required this.model,
    this.rootType,
  });

  final SpecDocumentController controller;
  final SpecModel model;
  final String? rootType;

  @override
  State<SpecDocumentTree> createState() => _SpecDocumentTreeState();
}

class _SpecDocumentTreeState extends State<SpecDocumentTree> {
  /// Paths the user clicked open even though they are still empty (D2).
  final Set<String> _manuallyExpanded = {};

  SpecDocumentController get _controller => widget.controller;
  SpecModel get _model => widget.model;
  ReviewStore get _store => widget.controller.review;

  String _rootSeg(SpecRoot r) => r.sectionId ?? r.type;
  String _fieldSeg(SpecField f) => f.sectionId ?? f.name;

  /// A node is empty when no value exists at or beneath its path (D4).
  bool _isEmpty(String path) => !_controller.hasValuesUnder(path);

  /// Whether to render [path] expanded: non-empty, or the user opened it (D2).
  bool _isExpanded(String path) =>
      !_isEmpty(path) || _manuallyExpanded.contains(path);

  void _toggleOpen(String path) =>
      setState(() => _manuallyExpanded.add(path));

  /// The root to render: the navigator's active selection (§14, step 20), then
  /// this editor's fixed [rootType] override, then the default (Project
  /// Definition). The tree rebuilds on every controller change, so a navigator
  /// selection re-renders this projection over the same shared document.
  SpecRoot? _activeRoot() {
    final roots = _model.roots;
    if (roots.isEmpty) return null;
    final selector = _controller.activeRootType ?? widget.rootType;
    if (selector == null) return defaultNavigatorRoot(roots);
    for (final r in roots) {
      if (r.type == selector || r.sectionId == selector) return r;
    }
    return defaultNavigatorRoot(roots);
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild whenever the shared document, review state, or active-root
    // selection changes. The active root is resolved *inside* the builder so a
    // navigator switch (a controller notification) re-renders the new
    // projection — not just the captured initial root.
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _store]),
      builder: (context, _) {
        final root = _activeRoot();
        if (root == null) {
          return const Center(child: Text('No document roots in the model'));
        }
        final cls = _model.classNamed(root.type);
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            _NodeHeader(
              label: root.title,
              sectionId: _rootSeg(root),
              path: _rootSeg(root),
              store: _store,
              help: root.description,
              isHeading: true,
            ),
            if (cls != null)
              _classBody(cls, _rootSeg(root), {root.type})
            else
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('No class definition for this root.'),
              ),
          ],
        );
      },
    );
  }

  /// Renders a class's fields: expanded fields first (in order), then a row of
  /// chips for the empty ones beneath them (D5).
  Widget _classBody(SpecClass cls, String basePath, Set<String> seenTypes) {
    final expanded = <Widget>[];
    final chips = <Widget>[];
    for (final field in cls.fields) {
      final path = '$basePath/${_fieldSeg(field)}';
      if (_isExpanded(path)) {
        expanded.add(_expandedField(field, path, seenTypes));
      } else {
        chips.add(_EmptyChip(
          label: field.name,
          onTap: () => _toggleOpen(path),
        ));
      }
    }
    return Padding(
      padding: const EdgeInsets.only(left: 10, top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...expanded,
          if (chips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Wrap(spacing: 6, runSpacing: 4, children: chips),
            ),
        ],
      ),
    );
  }

  Widget _expandedField(SpecField field, String path, Set<String> seenTypes) {
    switch (field.kind) {
      case SpecFieldKind.content:
      case SpecFieldKind.scalar:
        return _contentField(field, path);
      case SpecFieldKind.enumValue:
        return _enumField(field, path);
      case SpecFieldKind.form:
        return _formField(field, path);
      case SpecFieldKind.list:
        return _listField(field, path, seenTypes);
      case SpecFieldKind.complex:
      case SpecFieldKind.section:
        return _complexField(field, path, seenTypes);
    }
  }

  Widget _fieldHeader(SpecField field, String path) => _NodeHeader(
        label: field.name,
        sectionId: field.sectionId,
        path: path,
        store: _store,
        help: field.help ?? field.doc,
      );

  Widget _contentField(SpecField field, String path) {
    // Dart-code content (`@ContentType('code'|'code-dart')`) gets the
    // summary-backed Dart editor (§13 l / B1) — SDK-free analysis from the
    // embedded `assets/summaries/*.sum` bundles, with a graceful fall-back to a
    // plain monospace field when those assets are not bundled (the common case
    // in tests/CI/dev). Non-Dart code (sql/ddl) and prose stay plain text.
    if (isDartCodeContentType(field.contentType)) {
      return _FieldBlock(
        header: _fieldHeader(field, path),
        child: _CodeField(
          key: ValueKey('code:$path'),
          value: _controller.content(path) ?? '',
          onChanged: (v) => _controller.setContent(path, v),
        ),
      );
    }
    final multiline = field.kind == SpecFieldKind.content;
    return _FieldBlock(
      header: _fieldHeader(field, path),
      child: _ValueField(
        key: ValueKey('content:$path'),
        value: _controller.content(path) ?? '',
        minLines: multiline ? 3 : 1,
        maxLines: multiline ? 8 : 1,
        onChanged: (v) => _controller.setContent(path, v),
      ),
    );
  }


  Widget _enumField(SpecField field, String path) {
    final current = _controller.content(path);
    return _FieldBlock(
      header: _fieldHeader(field, path),
      child: DropdownButton<String>(
        value: field.enumValues.contains(current) ? current : null,
        isExpanded: true,
        hint: const Text('Select a value'),
        items: [
          for (final v in field.enumValues)
            DropdownMenuItem<String>(value: v, child: Text(v)),
        ],
        onChanged: (v) {
          if (v != null) _controller.setContent(path, v);
        },
      ),
    );
  }

  Widget _formField(SpecField field, String path) {
    return _FieldBlock(
      header: _fieldHeader(field, path),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final ff in field.formFields)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ff.label.isNotEmpty ? ff.label : ff.name,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  _ValueField(
                    key: ValueKey('form:$path/${ff.name}'),
                    value: _controller.formField(path, ff.name) ?? '',
                    hint: ff.hint,
                    onChanged: (v) =>
                        _controller.setFormField(path, ff.name, v),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _listField(SpecField field, String path, Set<String> seenTypes) {
    final items = _controller.listItems(path);
    final elem = _model.classNamed(field.elementType);
    final recursive =
        field.elementType != null && seenTypes.contains(field.elementType);
    final nextSeen = {...seenTypes, if (field.elementType != null) field.elementType!};
    return _FieldBlock(
      header: _fieldHeader(field, path),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final itemPath in items)
            _ListItem(
              label: field.elementType ?? 'item',
              onRemove: () => _controller.removeListItem(itemPath),
              child: (elem == null || recursive)
                  ? _recursiveNote(field.elementType)
                  : _classBody(elem, itemPath, nextSeen),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _controller.addListItem(path),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add item'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _complexField(SpecField field, String path, Set<String> seenTypes) {
    final nested = _model.classNamed(field.type);
    final recursive = field.type != null && seenTypes.contains(field.type);
    if (nested == null || recursive) {
      return _FieldBlock(
        header: _fieldHeader(field, path),
        child: _recursiveNote(field.type),
      );
    }
    return _FieldBlock(
      header: _fieldHeader(field, path),
      child: _classBody(nested, path, {...seenTypes, field.type!}),
    );
  }

  Widget _recursiveNote(String? type) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'recursive type${type != null ? ' · $type' : ''}',
          style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
}

/// A field block: its headline row plus the editor/sub-tree beneath it.
class _FieldBlock extends StatelessWidget {
  const _FieldBlock({required this.header, required this.child});

  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          Padding(
            padding: const EdgeInsets.only(left: 2, top: 2),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// The headline of a node: markdown label, optional section-id chip, and the
/// review-state badge beside it (D5). Help text renders below.
class _NodeHeader extends StatelessWidget {
  const _NodeHeader({
    required this.label,
    required this.path,
    required this.store,
    this.sectionId,
    this.help,
    this.isHeading = false,
  });

  final String label;
  final String path;
  final ReviewStore store;
  final String? sectionId;
  final String? help;
  final bool isHeading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: SpecMarkdown(
                isHeading ? '## $label' : '**$label**',
              ),
            ),
            if (sectionId != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(sectionId!,
                    style: const TextStyle(
                        fontSize: 10, fontFamily: 'monospace')),
              ),
            ],
            const SizedBox(width: 6),
            ReviewControls(store: store, path: path, nodeLabel: label),
          ],
        ),
        if (help != null && help!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 1, bottom: 2),
            child: SpecMarkdown(help!, muted: true),
          ),
      ],
    );
  }
}

/// A clickable chip standing in for an empty node/subtree (§13.1, D2).
class _EmptyChip extends StatelessWidget {
  const _EmptyChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      avatar: const Icon(Icons.add, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
    );
  }
}

/// A populated list item: a remove affordance plus the item's sub-tree (D3).
class _ListItem extends StatelessWidget {
  const _ListItem({
    required this.label,
    required this.onRemove,
    required this.child,
  });

  final String label;
  final VoidCallback onRemove;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.dividerColor, width: 2),
        ),
      ),
      padding: const EdgeInsets.only(left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant)),
              const Spacer(),
              IconButton(
                tooltip: 'Remove item',
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}

/// Whether a `@ContentType` value denotes Dart/d4rt code — the only flavour the
/// summary-backed Dart editor understands (§13 l). SQL/DDL `code-*` and prose
/// stay plain text. Public so the routing can be unit-tested without widgets.
bool isDartCodeContentType(String? contentType) =>
    contentType == 'code' || contentType == 'code-dart';

/// Asset paths for the pre-generated analyzer summaries (B1). Bundled by the
/// build (`build.dart` step 4); gitignored, so absent in a plain dev checkout.
const String _kSdkSummaryAsset = 'assets/summaries/sdk_summary.sum';
const String _kPackagesSummaryAsset = 'assets/summaries/packages.sum';

/// One-shot, cached probe for whether both summary bundles are actually present
/// in the asset bundle. Uses the asset manifest (cheap) rather than loading the
/// ~40 MB packages bundle. Cached so the per-keystroke rebuilds stay free.
Future<bool>? _summaryAssetsProbe;
Future<bool> _summaryAssetsAvailable() {
  return _summaryAssetsProbe ??= () async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets().toSet();
      return assets.contains(_kSdkSummaryAsset) &&
          assets.contains(_kPackagesSummaryAsset);
    } catch (_) {
      return false;
    }
  }();
}

/// A Dart-code content field (§13 l). Renders the summary-backed Dart editor
/// when the embedded `.sum` bundles are available, else degrades to the plain
/// multiline [_ValueField] so dev/test/CI without the heavy assets still work.
class _CodeField extends StatelessWidget {
  const _CodeField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _summaryAssetsAvailable(),
      builder: (context, snap) {
        if (snap.data == true) {
          return SizedBox(
            height: 240,
            child: SimpleSummaryBackedDartCodeEditor(
              initialCode: value,
              sdkSummaryAsset: _kSdkSummaryAsset,
              packageSummaryAsset: _kPackagesSummaryAsset,
              onChanged: onChanged,
            ),
          );
        }
        // Assets absent (or still probing): plain multiline fallback.
        return _ValueField(
          value: value,
          minLines: 3,
          maxLines: 12,
          onChanged: onChanged,
        );
      },
    );
  }
}

/// A debounce-free text editor whose [TextEditingController] survives tree
/// rebuilds (the whole tree re-renders on every keystroke via the shared
/// controller's `notifyListeners`). It only re-seeds its text when an *external*
/// change (e.g. an agent edit) makes the incoming [value] diverge from what the
/// user is currently typing, so the caret is never clobbered mid-edit.
class _ValueField extends StatefulWidget {
  const _ValueField({
    super.key,
    required this.value,
    required this.onChanged,
    this.minLines = 1,
    this.maxLines = 1,
    this.hint,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final int minLines;
  final int maxLines;
  final String? hint;

  @override
  State<_ValueField> createState() => _ValueFieldState();
}

class _ValueFieldState extends State<_ValueField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_ValueField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _ctrl.text) {
      _ctrl.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hint,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      onChanged: widget.onChanged,
    );
  }
}

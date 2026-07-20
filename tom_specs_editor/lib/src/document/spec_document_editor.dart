import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show EditorCapabilities, EditorStateSnapshot, StandardEditingActions;
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
/// through whichever root is selected (the Solution Blueprint master by default), so
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
    controller.addListener(_onControllerChanged);
  }

  /// The shared document controller (also driven by the agent tools).
  final SpecDocumentController controller;

  /// The root type/section id to render; null selects the model's first root.
  final String? rootType;

  final ValueNotifier<String> _title;
  final ValueNotifier<String?> _titleExtension;
  final ValueNotifier<bool> _isDirty;

  /// Fires on every controller change so the shell rebuilds the action bar's
  /// undo/redo enablement against the latest [stateSnapshot] (OE-11).
  final StreamController<void> _stateChanges =
      StreamController<void>.broadcast();

  void _onControllerChanged() {
    _isDirty.value = controller.isDirty;
    if (!_stateChanges.isClosed) _stateChanges.add(null);
  }

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

  // ── EditorActionProvider: shell global undo/redo (§10, OE-11) ──
  //
  // The shell routes the standard `forge.edit.undo`/`forge.edit.redo` actions
  // to the *active editor* (`DefaultShellApi.executeAction`), and derives their
  // enablement from this editor's [stateSnapshot]. Wiring those to the shared
  // controller's own [DefaultUndoManager] makes the shell's global undo button,
  // menu, and shortcut reflect and drive the document's snapshot stack — the
  // single authority. We deliberately do *not* push `notifyTextEdit` bridge
  // entries onto the shell's own undo manager, which would double-count.

  @override
  Set<String> get supportedActionIds => const {
        StandardEditingActions.undoActionId,
        StandardEditingActions.redoActionId,
      };

  @override
  EditorCapabilities get capabilities => const EditorCapabilities(
        hasTextBuffer: false,
        supportsUndoRedo: true,
        supportsClipboard: false,
        supportsLineEditing: false,
        supportsSelection: false,
      );

  @override
  EditorStateSnapshot get stateSnapshot => EditorStateSnapshot(
        // A model-driven tree, not a text buffer: line-editing actions stay
        // disabled (isTextMode false); only undo/redo enablement is live.
        isTextMode: false,
        canUndo: controller.canUndo,
        canRedo: controller.canRedo,
      );

  @override
  bool executeAction(String actionId) {
    switch (actionId) {
      case StandardEditingActions.undoActionId:
        unawaited(controller.undo());
        return true;
      case StandardEditingActions.redoActionId:
        unawaited(controller.redo());
        return true;
      default:
        return false;
    }
  }

  @override
  Stream<void> get onStateChanged => _stateChanges.stream;
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
            const Spacer(),
            _StrictValidationToggle(controller: controller),
          ],
        ),
      ),
    );
  }
}

/// The csmc9 strict-mode document-validation toggle for the top bar. When on, it
/// shows the live count of [SpecValidationError]s the runtime validator reports
/// for the whole document; toggling it flips [SpecDocumentController.strictValidation]
/// so the tree renders (or hides) the per-section diagnostics overlay. It
/// rebuilds on every controller change so the error count stays live as the
/// user edits.
class _StrictValidationToggle extends StatelessWidget {
  const _StrictValidationToggle({required this.controller});

  final SpecDocumentController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([controller, controller.strictValidation]),
      builder: (context, _) {
        final on = controller.strictValidation.value;
        final errorCount = on ? controller.validate().length : 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (on) ...[
              Icon(
                errorCount == 0
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                size: 16,
                color: errorCount == 0
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
              const SizedBox(width: 4),
              Text(
                errorCount == 0
                    ? 'Valid'
                    : '$errorCount issue${errorCount == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 12,
                  color: errorCount == 0
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
              ),
              const SizedBox(width: 6),
            ],
            const Text('Strict', style: TextStyle(fontSize: 12)),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: on,
                onChanged: controller.setStrictValidation,
              ),
            ),
          ],
        );
      },
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

  /// Editor strict mode (YRD9): headline editing is offered only on list-entry
  /// sections; fixed sections show their default headline read-only.
  bool get _strict => _controller.strictHeadlineEditing.value;

  /// The current per-section validation diagnostics (csmc9). Empty unless
  /// strict-mode validation is on; recomputed in [build] on every controller
  /// change so the overlay tracks edits live.
  Map<String, List<SpecValidationError>> _diagnostics = const {};

  /// The diagnostics anchored on [path] (empty when none / strict mode off).
  List<SpecValidationError> _diagnosticsFor(String path) =>
      _diagnostics[path] ?? const [];

  String _rootSeg(SpecRoot r) => r.sectionId ?? r.type;
  String _fieldSeg(SpecField f) => f.sectionId ?? f.name;

  /// The title shown for the section at [path]: its stored headline (YRD3) when
  /// present, else the effective default (YRD4 `@Headline` / derived name).
  String _titleFor(String path) =>
      _controller.headline(path) ?? _controller.effectiveDefaultHeadline(path);

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
      animation: Listenable.merge([
        _controller,
        _store,
        _controller.strictHeadlineEditing,
        _controller.strictValidation,
      ]),
      builder: (context, _) {
        // csmc9: recompute the validation overlay for this frame. Only when
        // strict-mode validation is on — otherwise no diagnostics render.
        _diagnostics = _controller.strictValidation.value
            ? _controller.validationByPath()
            : const {};
        final root = _activeRoot();
        if (root == null) {
          return const Center(child: Text('No document roots in the model'));
        }
        final cls = _model.classNamed(root.type);
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            _NodeHeader(
              label: _titleFor(_rootSeg(root)),
              sectionId: _rootSeg(root),
              path: _rootSeg(root),
              store: _store,
              help: root.description,
              diagnostics: _diagnosticsFor(_rootSeg(root)),
              isHeading: true,
              // The root is a fixed section: headline editing only in
              // non-strict mode (YRD9 item 2/3).
              headlineEditable: !_strict,
              headlineValue: _controller.headline(_rootSeg(root)),
              headlineDefault:
                  _controller.effectiveDefaultHeadline(_rootSeg(root)),
              onHeadlineChanged: (v) =>
                  _controller.setHeadline(_rootSeg(root), v),
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

  /// Renders a class's fields in document order: each expanded field at its
  /// position, and every contiguous run of empty fields collapsed into one
  /// `Wrap` of chips at *that* position (D5). This keeps each chip "after the
  /// last rendered subsection, before the next sibling" rather than bunching all
  /// empty fields into a single trailing row.
  Widget _classBody(SpecClass cls, String basePath, Set<String> seenTypes) {
    final children = <Widget>[];
    var pendingChips = <Widget>[];

    void flushChips() {
      if (pendingChips.isEmpty) return;
      children.add(Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: Wrap(spacing: 6, runSpacing: 4, children: pendingChips),
      ));
      pendingChips = <Widget>[];
    }

    for (final field in cls.fields) {
      final path = '$basePath/${_fieldSeg(field)}';
      if (_isExpanded(path)) {
        flushChips();
        children.add(_expandedField(field, path, seenTypes));
      } else {
        pendingChips.add(_EmptyChip(
          label: field.name,
          onTap: () => _toggleOpen(path),
        ));
      }
    }
    flushChips();

    return Padding(
      padding: const EdgeInsets.only(left: 10, top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
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
        label: _titleFor(path),
        sectionId: field.sectionId,
        path: path,
        store: _store,
        help: field.help ?? field.doc,
        diagnostics: _diagnosticsFor(path),
        // A field is a fixed section (its id is the model's @SectionId): its
        // headline is editable only in non-strict mode (YRD9 item 2/3). The
        // section id itself is never editable here — only list-entry ids are.
        headlineEditable: !_strict,
        headlineValue: _controller.headline(path),
        headlineDefault: _controller.effectiveDefaultHeadline(path),
        onHeadlineChanged: (v) => _controller.setHeadline(path, v),
      );

  Widget _contentField(SpecField field, String path) {
    // Dart/d4rt-code content gets the summary-backed Dart editor (§13 l / B1),
    // analysed against the summary scope its `@ContentType` maps to (step 11):
    // `code`/`code-dart` → `dart-plain`, `code-d4rt-flutter` → `d4rt-flutter`,
    // `code-d4rt-doc` → `d4rt-document`. `_CodeField` degrades to a plain field
    // when the scope is not registered (assets absent or scope not yet declared).
    // Non-Dart code (sql/ddl) and prose stay plain text.
    final codeScope = scopeForContentType(field.contentType);
    if (codeScope != null) {
      return _FieldBlock(
        header: _fieldHeader(field, path),
        child: _CodeField(
          key: ValueKey('code:$path'),
          scope: codeScope,
          value: _controller.content(path) ?? '',
          onChanged: (v) => _controller.setContent(path, v),
        ),
      );
    }
    // Flutter-layout content (§13 k) renders live from d4rt-flutter source.
    if (isFlutterLayoutContentType(field.contentType)) {
      return _FieldBlock(
        header: _fieldHeader(field, path),
        child: _LayoutField(
          key: ValueKey('layout:$path'),
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
              itemPath: itemPath,
              label: field.elementType ?? 'item',
              diagnostics: _diagnosticsFor(itemPath),
              onRemove: () => _controller.removeListItem(itemPath),
              // A list item is a list-entry section: its headline and section
              // id are editable in BOTH modes (YRD9 item 2). The headline
              // prefills from the element class's @Headline default / stem
              // (item 4); the id from the @SectionIdPattern generator on add.
              headline: _titleFor(itemPath),
              idValue: _controller.itemSectionId(itemPath),
              onHeadlineChanged: (v) => _controller.setHeadline(itemPath, v),
              onIdChanged: (v) => _controller.setItemSectionId(itemPath, v),
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

/// The headline of a node: its title (markdown label, or an editable field in
/// non-strict mode), optional section-id chip, and the review-state badge
/// beside it (D5). Help text renders below.
///
/// YRD9: for a fixed section the title is editable only when [headlineEditable]
/// is true (non-strict mode); otherwise it renders read-only. The section id of
/// a fixed section is never editable here (it is the model's `@SectionId`) — only
/// list-entry ids are, and those are edited by [_ListItem].
class _NodeHeader extends StatelessWidget {
  const _NodeHeader({
    required this.label,
    required this.path,
    required this.store,
    this.sectionId,
    this.help,
    this.isHeading = false,
    this.headlineEditable = false,
    this.headlineValue,
    this.headlineDefault = '',
    this.onHeadlineChanged,
    this.diagnostics = const [],
  });

  final String label;
  final String path;
  final ReviewStore store;
  final String? sectionId;
  final String? help;
  final bool isHeading;

  /// The strict-mode validation errors anchored on this section (csmc9). Empty
  /// unless strict-mode validation is on and the runtime validator flagged this
  /// path; rendered as a badge beside the title.
  final List<SpecValidationError> diagnostics;

  /// Whether the headline renders as an editable field (non-strict mode).
  final bool headlineEditable;

  /// The stored headline (YRD3), or `null` when the section shows its default.
  final String? headlineValue;

  /// The effective default headline (YRD4), used as the field's prefill/hint.
  final String headlineDefault;
  final ValueChanged<String>? onHeadlineChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: (headlineEditable && onHeadlineChanged != null)
                  ? _HeaderEditField(
                      key: ValueKey('headline:$path'),
                      value: headlineValue ?? headlineDefault,
                      hint: headlineDefault,
                      bold: true,
                      onCommitted: onHeadlineChanged!,
                    )
                  : SpecMarkdown(
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
            if (diagnostics.isNotEmpty) ...[
              const SizedBox(width: 6),
              _DiagnosticsBadge(diagnostics: diagnostics),
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

/// The csmc9 strict-mode diagnostics badge shown beside a section's title: an
/// error icon with a count, whose tooltip lists every [SpecValidationError]
/// anchored on the section (`code: message`). It is a pure read-only overlay of
/// the runtime validator's output — one badge per offending section, so a
/// `oneOfCaseMismatch` shows on exactly the mis-selected subsection.
class _DiagnosticsBadge extends StatelessWidget {
  const _DiagnosticsBadge({required this.diagnostics});

  final List<SpecValidationError> diagnostics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = diagnostics.length;
    return Tooltip(
      message: [
        for (final e in diagnostics) '• ${e.code.name}: ${e.message}',
      ].join('\n'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 12, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 3),
            Text('$count',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onErrorContainer)),
          ],
        ),
      ),
    );
  }
}

/// A compact commit-on-blur text field for editing a section's headline or a
/// list item's section id (YRD9). Unlike the value fields it does *not* commit
/// per keystroke — it commits on Enter or focus loss, so a headline edit is one
/// undo step and an in-progress id never trips a mid-typing uniqueness check.
/// It re-seeds its text when an external change makes the incoming [value]
/// diverge from what the user typed (e.g. a rejected id edit reverting).
class _HeaderEditField extends StatefulWidget {
  const _HeaderEditField({
    super.key,
    required this.value,
    required this.onCommitted,
    this.hint,
    this.bold = false,
  });

  final String value;
  final ValueChanged<String> onCommitted;
  final String? hint;
  final bool bold;

  @override
  State<_HeaderEditField> createState() => _HeaderEditFieldState();
}

class _HeaderEditFieldState extends State<_HeaderEditField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.value);
  late final FocusNode _focus = FocusNode()..addListener(_onFocusChange);

  void _onFocusChange() {
    if (!_focus.hasFocus) _commit();
  }

  void _commit() {
    if (_ctrl.text == widget.value) return;
    widget.onCommitted(_ctrl.text);
  }

  @override
  void didUpdateWidget(_HeaderEditField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-seed only when not being edited, so an external revert (e.g. a rejected
    // id) shows through without clobbering an in-progress edit.
    if (!_focus.hasFocus && widget.value != _ctrl.text) {
      _ctrl.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      style: TextStyle(
        fontSize: 13,
        fontWeight: widget.bold ? FontWeight.w600 : FontWeight.normal,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hint,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      onSubmitted: (_) => _commit(),
      onEditingComplete: _commit,
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
    required this.itemPath,
    required this.label,
    required this.onRemove,
    required this.headline,
    required this.idValue,
    required this.onHeadlineChanged,
    required this.onIdChanged,
    required this.child,
    this.diagnostics = const [],
  });

  /// The item's structural path (`…/§item`), used to key the edit fields so
  /// they keep their identity across rebuilds.
  final String itemPath;

  /// The element-type label shown as a muted caption on the item's header row.
  final String label;
  final VoidCallback onRemove;

  /// The item's effective headline (stored value, or the @Headline / stem
  /// default) — always editable for a list-entry section (YRD9 item 2).
  final String headline;

  /// The item's stored section id (YRD3), or `null` while none is stored.
  final String? idValue;

  final ValueChanged<String> onHeadlineChanged;
  final ValueChanged<String> onIdChanged;
  final Widget child;

  /// Strict-mode validation errors anchored on this list-item section (csmc9) —
  /// e.g. a `oneOfCaseMismatch` when the item is itself a `@OneOf` container.
  final List<SpecValidationError> diagnostics;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _HeaderEditField(
                  key: ValueKey('item-headline:$itemPath'),
                  value: headline,
                  hint: label,
                  bold: true,
                  onCommitted: onHeadlineChanged,
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 120,
                child: _HeaderEditField(
                  key: ValueKey('item-id:$itemPath'),
                  value: idValue ?? '',
                  hint: 'id',
                  onCommitted: onIdChanged,
                ),
              ),
              if (diagnostics.isNotEmpty) ...[
                const SizedBox(width: 6),
                _DiagnosticsBadge(diagnostics: diagnostics),
              ],
              IconButton(
                tooltip: 'Remove item',
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant)),
          ),
          child,
        ],
      ),
    );
  }
}

/// Maps a `@ContentType` code flavour to the summary scope its editor analyses
/// against (step 11), or null for non-code content (prose, sql/ddl, layout) that
/// never gets the summary-backed Dart editor.
///
/// Scope names are the bundle names declared in `tom_specs_editor/buildkit.yaml`
/// (registered by the generated `SummaryScopes.initialize()`). They are kept as
/// string literals — not the generated `SummaryScopes` constants — so this
/// routing compiles even when the generated helper has not been produced yet.
/// `code-d4rt-doc` maps to a scope (`d4rt-document`) that is not declared yet;
/// until it is, that scope stays unregistered and the field degrades to plain
/// text (the absent-scope fallback below).
String? scopeForContentType(String? contentType) {
  switch (contentType) {
    case 'code':
    case 'code-dart':
      return 'dart-plain';
    case 'code-d4rt-flutter':
      return 'd4rt-flutter';
    case 'code-d4rt-doc':
      return 'd4rt-document';
    default:
      return null;
  }
}

/// Whether a `@ContentType` value denotes Dart/d4rt code the summary-backed
/// editor handles — i.e. it maps to a summary scope. SQL/DDL `code-*` and prose
/// stay plain text. Public so the routing can be unit-tested without widgets.
bool isDartCodeContentType(String? contentType) =>
    scopeForContentType(contentType) != null;

/// Whether a `@ContentType` value denotes a live Flutter layout — content that
/// is d4rt-flutter source meant to be *rendered* (not edited as text) via
/// `SourceFlutterD4rt().build<Widget>(source, context)` (§13 k). No such
/// content type exists in the model yet; this predicate fixes the convention so
/// the routing and a future model-side layout section line up. Public for unit
/// testing the routing without widgets.
bool isFlutterLayoutContentType(String? contentType) =>
    contentType == 'layout' ||
    contentType == 'flutter' ||
    contentType == 'flutter-layout' ||
    contentType == 'd4rt-flutter';

/// A Dart-code content field (§13 l). Renders the summary-backed Dart editor
/// bound to its [scope] when that scope is registered, else degrades to the
/// plain multiline [_ValueField] so dev/test/CI without the heavy `.sum` bundles
/// — and not-yet-declared scopes — still work.
class _CodeField extends StatelessWidget {
  const _CodeField({
    super.key,
    required this.scope,
    required this.value,
    required this.onChanged,
  });

  /// Summary scope (bundle) name this code field analyses against.
  final String scope;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // Per-scope availability probe (step 11): render the summary-backed editor
    // only when [scope] is registered (its `.sum` bundles were generated and
    // `SummaryScopes.initialize()` ran in `main()` before `runApp`). The check is
    // synchronous because registration completes before the first frame; in
    // dev/test/CI without the assets the scope stays absent and we fall back.
    if (SummaryScopeRegistry.instance.isRegistered(scope)) {
      return SizedBox(
        height: 240,
        child: SimpleSummaryBackedDartCodeEditor(
          initialCode: value,
          scope: scope,
          onChanged: onChanged,
        ),
      );
    }
    return _ValueField(
      value: value,
      minLines: 3,
      maxLines: 12,
      onChanged: onChanged,
    );
  }
}

/// A Flutter-layout content field (§13 k). The §13 target is a *live* preview
/// rendered by `SourceFlutterD4rt().build<Widget>(source, context)` from
/// `tom_d4rt_flutter`. That package cannot currently be a dependency of this
/// editor: its transitive `tom_d4rt → analyzer ^8` conflicts with
/// `tom_dart_editor → analyzer ^10` (the OE-1 code editor). Until `tom_d4rt`
/// moves to analyzer ^10 (d4rt-quest scope — tracked as OE-3a), this seam
/// renders the layout source read-only beneath a note. The single drop-in
/// point for the live call is marked below.
class _LayoutField extends StatelessWidget {
  const _LayoutField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;

  /// Kept so the field signature matches the other content fields and the live
  /// drop-in (an editable source + preview split) stays trivial. The read-only
  /// preview does not yet emit edits.
  // ignore: unused_field
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ── §13 k drop-in point ───────────────────────────────────────────────
    // Once `tom_d4rt_flutter` is addable (OE-3a), replace the read-only
    // preview below with a guarded live render:
    //   try {
    //     return SourceFlutterD4rt().build<Widget>(value, context);
    //   } catch (_) { /* fall through to the source preview */ }
    // ──────────────────────────────────────────────────────────────────────
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard_customize_outlined,
                  size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Flutter layout — live preview pending d4rt analyzer-10 '
                  'upgrade (OE-3a)',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            value.isEmpty ? '(empty)' : value,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ],
      ),
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

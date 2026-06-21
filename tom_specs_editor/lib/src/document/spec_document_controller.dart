import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;
import 'package:tom_forge_agentic/tom_forge_agentic.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart'
    show DefaultUndoManager, ShellEditorIntegration, UndoEntry;

import '../structure/review_store.dart';
import '../structure/spec_model.dart';
import 'docspecs_file.dart';
import 'markdown_document.dart';
import 'spec_document.dart';

/// A node located by [SpecDocumentController.resolve]: the structural meaning of
/// a section-ID path against the `SpecModel` graph.
class ResolvedNode {
  /// The full section-ID path this node was resolved from.
  final String path;

  /// The render kind of the node (the field's kind, or [SpecFieldKind.complex]
  /// for a document root / list element class).
  final SpecFieldKind kind;

  /// The class/element type name this node carries, when it has one.
  final String? type;

  /// The field this node corresponds to (null for a document root).
  final SpecField? field;

  /// The class this node *is* (for roots, complex fields, and list elements).
  final SpecClass? cls;

  /// Whether this node is an individual element of a list (a `-N` suffix).
  final bool isListItem;

  ResolvedNode({
    required this.path,
    required this.kind,
    this.type,
    this.field,
    this.cls,
    this.isListItem = false,
  });
}

/// The single document controller shared by the UI and the agent tools (§8).
///
/// It wraps the read-only [SpecModel] (schema), the live sparse [SpecDocument]
/// (instance values), and the [ReviewStore] (structural review). Every mutation
/// the agent tools perform routes through here so the UI and the tools see the
/// same state; edits [notifyListeners] so the document editor re-renders.
///
/// The model is supplied as a [Future] so the host can construct the controller
/// synchronously during bootstrap; callers [ensureLoaded] before touching
/// schema-dependent operations.
class SpecDocumentController extends ChangeNotifier {
  SpecDocumentController({
    required Future<SpecModel> modelFuture,
    required this.review,
    SpecDocument? document,
    this.defaultOutlineDepth = 2,
    ChangeLog? changeLog,
    int maxSnapshots = 50,
  })  : _modelFuture = modelFuture,
        document = document ?? SpecDocument(),
        changeLog = changeLog ?? ChangeLog(),
        _undo = DefaultUndoManager(maxEntries: maxSnapshots) {
    _savedState = this.document.captureState();
    _savedFingerprint = _savedState.fingerprint;
  }

  final Future<SpecModel> _modelFuture;

  /// The structural-review store (shared with the structure browser).
  final ReviewStore review;

  /// The live, sparse document instance.
  final SpecDocument document;

  /// Default recursion depth for [outline] when the caller omits one.
  final int defaultOutlineDepth;

  /// The agent change log (§9): records every mutation; resets on save.
  final ChangeLog changeLog;

  /// The snapshot-based undo stack (§10), capped at `maxSnapshots` entries.
  final DefaultUndoManager _undo;

  /// The document state as of the last save (or load) — the review's base pane
  /// (`baseAtLastSave`, §9) and the dirty reference (§10).
  late SpecDocumentState _savedState;
  late String _savedFingerprint;

  /// The active agent turn id, or `null` when the user is editing freely.
  /// Edits made during a turn share this id so the change log groups them and
  /// the undo stack collapses them into one step (§9, §10).
  String? _currentTurnId;

  /// Per-edit counter feeding synthetic turn ids for free user edits.
  int _editSeq = 0;

  /// Monotonic id source for change-log entries.
  int _entrySeq = 0;

  SpecModel? _model;

  /// The resolved model. Only valid after [ensureLoaded] has completed.
  SpecModel get model => _model!;

  /// Whether the model future has resolved — synchronous callers (e.g. the
  /// `${file}` placeholder provider, OE-12) check this before touching
  /// schema-dependent operations like [exportMarkdown].
  bool get isModelLoaded => _model != null;

  /// Loads and caches the model future on first use.
  Future<SpecModel> ensureLoaded() async => _model ??= await _modelFuture;

  // --- §14 root navigation (step 20) -------------------------------------

  /// The section id / type name of the document root the editor renders, or
  /// `null` for the default (Project Definition). Driven by the §14 root
  /// navigator; the editor projects the *same* shared [document] through the
  /// chosen root, so switching roots never copies or forks data.
  String? _activeRootType;

  /// The active root selector (section id or type name), or `null` for default.
  String? get activeRootType => _activeRootType;

  /// Selects the active document root by section id or type name (`null` =
  /// default). A no-op when unchanged; otherwise [notifyListeners] so the
  /// navigator highlight and the document tree re-render together over the one
  /// shared document.
  void setActiveRoot(String? rootType) {
    if (_activeRootType == rootType) return;
    _activeRootType = rootType;
    notifyListeners();
  }

  // --- Layer A: schema lookups -------------------------------------------

  /// The class identified by [id], which may be a class name or a section id.
  SpecClass? classById(String id) {
    final byName = model.classes[id];
    if (byName != null) return byName;
    for (final c in model.classes.values) {
      if (c.sectionId == id) return c;
    }
    return null;
  }

  // --- Path resolution ----------------------------------------------------

  String _segOf(SpecField f) => f.sectionId ?? f.name;
  String _rootSeg(SpecRoot r) => r.sectionId ?? r.type;

  SpecRoot? _rootBySeg(String seg) {
    for (final r in model.roots) {
      if (_rootSeg(r) == seg || r.type == seg) return r;
    }
    return null;
  }

  /// Resolves a section-ID [path] to its structural meaning, or `null` if no
  /// such node exists. The first segment is a document root; each subsequent
  /// segment is a field's section id/name, or a `<listSeg>-<n>` list item.
  ResolvedNode? resolve(String path) {
    final segs = path.split('/');
    if (segs.isEmpty) return null;
    final root = _rootBySeg(segs.first);
    if (root == null) return null;

    SpecClass? cur = model.classNamed(root.type);
    var node = ResolvedNode(
      path: segs.first,
      kind: SpecFieldKind.complex,
      type: root.type,
      cls: cur,
    );
    var acc = segs.first;

    for (final seg in segs.skip(1)) {
      if (cur == null) return null;
      SpecField? field;
      String? itemSuffix;

      for (final f in cur.fields) {
        if (_segOf(f) == seg) {
          field = f;
          break;
        }
      }
      if (field == null) {
        final dash = seg.lastIndexOf('-');
        if (dash > 0) {
          final base = seg.substring(0, dash);
          final suffix = seg.substring(dash + 1);
          if (int.tryParse(suffix) != null) {
            for (final f in cur.fields) {
              if (_segOf(f) == base && f.kind == SpecFieldKind.list) {
                field = f;
                itemSuffix = suffix;
                break;
              }
            }
          }
        }
      }
      if (field == null) return null;

      acc = '$acc/$seg';
      if (itemSuffix != null) {
        cur = model.classNamed(field.elementType);
        node = ResolvedNode(
          path: acc,
          kind: SpecFieldKind.complex,
          type: field.elementType,
          field: field,
          cls: cur,
          isListItem: true,
        );
      } else {
        switch (field.kind) {
          case SpecFieldKind.complex:
            cur = model.classNamed(field.type);
            node = ResolvedNode(
              path: acc,
              kind: field.kind,
              type: field.type,
              field: field,
              cls: cur,
            );
          case SpecFieldKind.list:
            cur = null; // a deeper segment must use a `-n` item suffix
            node = ResolvedNode(
              path: acc,
              kind: field.kind,
              type: field.elementType,
              field: field,
            );
          default:
            cur = null;
            node = ResolvedNode(
              path: acc,
              kind: field.kind,
              type: field.type ?? field.contentType,
              field: field,
            );
        }
      }
    }
    return node;
  }

  // --- Layer B: live outline ---------------------------------------------

  /// A compact outline of the live document beneath [rootId] (a root section id
  /// or type name), to [depth] levels. Each node carries its path, kind, type,
  /// and — for lists — the live item count and item children.
  Map<String, Object?>? outline(String rootId, {int? depth}) {
    final root = _rootBySeg(rootId);
    if (root == null) return null;
    final cls = model.classNamed(root.type);
    final maxDepth = depth ?? defaultOutlineDepth;
    return {
      'id': _rootSeg(root),
      'type': root.type,
      'kind': SpecFieldKind.complex.name,
      if (cls != null)
        'children': _outlineClass(cls, _rootSeg(root), maxDepth, {root.type}),
    };
  }

  List<Map<String, Object?>> _outlineClass(
    SpecClass cls,
    String parentPath,
    int depth,
    Set<String> seenTypes,
  ) {
    final out = <Map<String, Object?>>[];
    for (final f in cls.fields) {
      final path = '$parentPath/${_segOf(f)}';
      final node = <String, Object?>{
        'id': path,
        'name': f.name,
        'kind': f.kind.name,
      };
      switch (f.kind) {
        case SpecFieldKind.list:
          final items = document.listItems(path);
          node['count'] = items.length;
          if (f.elementType != null) node['elementType'] = f.elementType;
          final elem = model.classNamed(f.elementType);
          if (depth > 1 && elem != null && items.isNotEmpty) {
            final nextSeen = {...seenTypes};
            final recursive = !nextSeen.add(f.elementType!);
            node['items'] = [
              for (final itemPath in items)
                {
                  'id': itemPath,
                  'kind': SpecFieldKind.complex.name,
                  'type': f.elementType,
                  if (recursive)
                    'recursive': true
                  else
                    'children':
                        _outlineClass(elem, itemPath, depth - 1, nextSeen),
                },
            ];
          }
        case SpecFieldKind.complex:
          final nested = model.classNamed(f.type);
          if (f.type != null) node['type'] = f.type;
          if (depth > 1 && nested != null) {
            final nextSeen = {...seenTypes};
            if (nextSeen.add(f.type!)) {
              node['children'] =
                  _outlineClass(nested, path, depth - 1, nextSeen);
            } else {
              node['recursive'] = true;
            }
          }
        case SpecFieldKind.form:
          node['fields'] = [for (final ff in f.formFields) ff.name];
        case SpecFieldKind.enumValue:
          node['enumValues'] = f.enumValues;
        case SpecFieldKind.content:
        case SpecFieldKind.section:
        case SpecFieldKind.scalar:
          if (f.type != null) node['type'] = f.type;
      }
      out.add(node);
    }
    return out;
  }

  /// Cardinality/identity metadata for the node at [path] (Layer B, no body).
  Map<String, Object?>? sectionMeta(String path) {
    final node = resolve(path);
    if (node == null) return null;
    final meta = <String, Object?>{
      'id': node.path,
      'kind': node.kind.name,
      if (node.type != null) 'type': node.type,
    };
    final f = node.field;
    if (f != null) {
      meta['name'] = f.name;
      if (f.kind == SpecFieldKind.list) {
        meta['count'] = document.listItems(node.path).length;
        if (f.elementType != null) meta['elementType'] = f.elementType;
      }
      if (f.kind == SpecFieldKind.form) {
        meta['fields'] = [for (final ff in f.formFields) ff.name];
      }
      if (f.kind == SpecFieldKind.enumValue) {
        meta['enumValues'] = f.enumValues;
      }
    }
    return meta;
  }

  // --- Layer C: content + mutations --------------------------------------

  /// The tool-call id to stamp on the next recorded change, when a mutation
  /// originates from an agent tool. Cleared per turn by [endTurn].
  String? activeToolCallId;

  /// The content value at [path], or `null`.
  String? content(String path) => document.content(path);

  /// Whether any value exists at [path] or beneath it — the structural
  /// emptiness test the compact tree uses to decide chip-vs-expanded (§13.1,
  /// D4). An untouched node is empty and renders as a clickable chip.
  bool hasValuesUnder(String path) => document.hasValuesUnder(path);

  /// The ordered item paths of the list at [listPath] (empty when none).
  List<String> listItems(String listPath) => document.listItems(listPath);

  /// The form [field] value at [path], or `null`.
  String? formField(String path, String field) =>
      document.formField(path, field);

  /// Sets the content at [path]. Snapshots + records the change unless it is a
  /// no-op (§9, §10).
  void setContent(String path, String value) {
    final before = document.captureState();
    final beforeVal = document.content(path);
    document.setContent(path, value);
    _commit(
      before,
      () => ChangeEntry(
        id: _nextEntryId(),
        sectionId: path,
        kind: ChangeKind.content,
        turnId: _turnIdForEdit(),
        beforeThisEdit: beforeVal,
        afterThisEdit: value.isEmpty ? null : value,
        baseAtLastSave: _savedState.contentAt(path),
        toolCallId: activeToolCallId,
      ),
    );
  }

  /// Sets the form [field] at [path]. Snapshots + records the change unless it
  /// is a no-op.
  void setFormField(String path, String field, String value) {
    final before = document.captureState();
    final beforeVal = document.formField(path, field);
    document.setFormField(path, field, value);
    _commit(
      before,
      () => ChangeEntry(
        id: _nextEntryId(),
        sectionId: path,
        kind: ChangeKind.formField,
        field: field,
        turnId: _turnIdForEdit(),
        beforeThisEdit: beforeVal,
        afterThisEdit: value.isEmpty ? null : value,
        baseAtLastSave: _savedState.formFieldAt(path, field),
        toolCallId: activeToolCallId,
      ),
    );
  }

  /// Appends a list item at [listPath] and returns its new path.
  String addListItem(String listPath) {
    final before = document.captureState();
    final itemPath = document.addListItem(listPath);
    _commit(
      before,
      () => ChangeEntry(
        id: _nextEntryId(),
        sectionId: itemPath,
        kind: ChangeKind.listAdd,
        turnId: _turnIdForEdit(),
        afterThisEdit: itemPath,
        toolCallId: activeToolCallId,
      ),
    );
    return itemPath;
  }

  /// Removes the list item at [itemPath]; returns whether one was removed.
  bool removeListItem(String itemPath) {
    final before = document.captureState();
    final removed = document.removeListItem(itemPath);
    if (removed) {
      _commit(
        before,
        () => ChangeEntry(
          id: _nextEntryId(),
          sectionId: itemPath,
          kind: ChangeKind.listRemove,
          turnId: _turnIdForEdit(),
          beforeThisEdit: itemPath,
          toolCallId: activeToolCallId,
        ),
      );
    }
    return removed;
  }

  /// Applies a structural-review decision at [path], routed through the shared
  /// [ReviewStore] (which persists immediately).
  ///
  /// Review decisions live in the [ReviewStore], not the [SpecDocument], so a
  /// review is **recorded** in the change log (it is a mutation, §9) but is not
  /// part of the snapshot/undo stack (§10) — undoing a review is a separate
  /// concern owned by the review store.
  void setReview(String path, void Function(ReviewEntry) mutate) {
    review.update(path, mutate);
    changeLog.record(ChangeEntry(
      id: _nextEntryId(),
      sectionId: path,
      kind: ChangeKind.review,
      turnId: _turnIdForEdit(),
      toolCallId: activeToolCallId,
    ));
    notifyListeners();
  }

  // --- §9 Change log & three-way review ----------------------------------

  /// Resolves the live current value at [entry]'s section, for the review's
  /// pane-3 ("current") column.
  String? currentValueFor(ChangeEntry entry) =>
      entry.kind == ChangeKind.formField
          ? document.formField(entry.sectionId, entry.field!)
          : document.content(entry.sectionId);

  /// Applies a **pick-a-pane** resolution (§9, M1): the chosen [pane]'s value
  /// becomes the section's new value. This is an ordinary edit — it routes
  /// through [setContent]/[setFormField], so picking a *different* value
  /// **creates a new undo entry**; picking the current value is a no-op.
  void applyPanePick(ChangeEntry entry, ReviewPane pane) {
    final value = entry.valueForPane(pane, current: currentValueFor(entry));
    if (entry.kind == ChangeKind.formField) {
      setFormField(entry.sectionId, entry.field!, value ?? '');
    } else {
      setContent(entry.sectionId, value ?? '');
    }
  }

  // --- §10 Undo / redo ----------------------------------------------------

  /// Begins an agent [turnId]: edits until [endTurn] share the turn (change-log
  /// grouping, §9) and collapse into a single undo step (§10).
  void beginTurn(String turnId) {
    _currentTurnId = turnId;
    _undo.beginUndoGroup(label: 'Agent turn $turnId');
  }

  /// Ends the active agent turn, committing its edits as one undo step.
  void endTurn() {
    _undo.endUndoGroup();
    _currentTurnId = null;
    activeToolCallId = null;
  }

  /// Whether there is an edit to undo.
  bool get canUndo => _undo.undoCount > 0;

  /// Whether there is an undone edit to redo.
  bool get canRedo => _undo.redoCount > 0;

  /// Whether the document differs from its last-saved state (§10).
  bool get isDirty => document.captureState().fingerprint != _savedFingerprint;

  /// Undoes the most recent edit (or agent turn).
  Future<void> undo() => _undo.undo();

  /// Redoes the most recently undone edit (or agent turn).
  Future<void> redo() => _undo.redo();

  /// Save-point bookkeeping (§9, §10): the saved state becomes the new base,
  /// the change log resets, and dirty clears. The undo stack is deliberately
  /// **kept** so post-save undo still works (§9, N6).
  void save() {
    _savedState = document.captureState();
    _savedFingerprint = _savedState.fingerprint;
    changeLog.reset();
    notifyListeners();
  }

  // --- §15.1 native `*.docspecs.yaml` save / load ------------------------

  /// Serializes the document + review state to [file] as a two-pass
  /// `*.docspecs.yaml` (§15.1), then re-baselines as a save point.
  ///
  /// The agent change log is **not** serialized (it resets on save, M2); the
  /// optional [sessionId] is written to a `<file>.session` sidecar (A2), never
  /// into the document YAML. The undo stack is kept (post-save undo still
  /// works, N6), matching [save]'s contract.
  Future<void> saveDocSpecs(File file, {String? sessionId}) async {
    final yaml = DocSpecsFile.encode(document: document, review: review.entries);
    await file.parent.create(recursive: true);
    await file.writeAsString(yaml);
    await DocSpecsFile.writeSessionId(file, sessionId);
    save();
  }

  /// Loads document + review state from a two-pass `*.docspecs.yaml` [file]
  /// (§15.1), restoring the full UI state. Returns the SDK session id from the
  /// sidecar, or `null` when absent.
  ///
  /// A load is a fresh save point: the change log resets, the undo stack is
  /// cleared (there is nothing before the loaded document to undo to), and the
  /// loaded state becomes the dirty reference.
  Future<String?> loadDocSpecs(File file) async {
    final parsed = DocSpecsFile.decode(await file.readAsString());
    document.loadJson(parsed.document);
    review.replaceEntries(parsed.review);
    _undo.clear();
    changeLog.reset();
    _savedState = document.captureState();
    _savedFingerprint = _savedState.fingerprint;
    notifyListeners();
    return await DocSpecsFile.readSessionId(file);
  }

  // --- §15.2 markdown import / export ------------------------------------

  /// Renders the populated subtree of the root identified by [rootSeg] (a root
  /// section id or type name) as a schema-conformant markdown document with a
  /// `<!-- docspec: -->` header (§15.2). Throws [ArgumentError] for an unknown
  /// root.
  String exportMarkdown(String rootSeg) {
    final root = _rootBySeg(rootSeg);
    if (root == null) {
      throw ArgumentError('No document root for "$rootSeg"');
    }
    return MarkdownDocument(this).exportRoot(root);
  }

  /// Imports [text] as a **full overwrite** of the covered root scope (§15.2,
  /// IO1): the parsed values replace everything under the imported root(s),
  /// applied as a single undoable step. Returns the parse report — unmapped or
  /// malformed blocks are listed in [MarkdownImportResult.rejections], never
  /// silently dropped.
  MarkdownImportResult importMarkdown(String text) {
    final result = MarkdownDocument(this).parse(text);
    _applyMarkdownImport(result);
    return result;
  }

  /// Replaces every value under [MarkdownImportResult.rootPrefixes] with the
  /// parsed values, as one undo entry. Built by merging the parsed values over
  /// the live document minus the covered scope, then reloading — so other roots
  /// are untouched and list seq/item paths are restored exactly.
  void _applyMarkdownImport(MarkdownImportResult result) {
    if (result.rootPrefixes.isEmpty) return;
    final before = document.captureState();

    final doc = document.toJson();
    final content = <String, Object?>{};
    final forms = <String, Object?>{};
    final lists = <String, Object?>{};
    (doc['content'] as Map?)?.forEach((k, v) => content['$k'] = v);
    (doc['forms'] as Map?)?.forEach((k, v) => forms['$k'] = v);
    (doc['lists'] as Map?)?.forEach((k, v) => lists['$k'] = v);

    bool underScope(String key) => result.rootPrefixes.any(
        (p) => key == p || key.startsWith('$p/') || key.startsWith('$p-'));
    content.removeWhere((k, _) => underScope(k));
    forms.removeWhere((k, _) => underScope(k));
    lists.removeWhere((k, _) => underScope(k));

    content.addAll(result.content);
    forms.addAll(result.forms);
    lists.addAll(result.lists);

    document.loadJson({'content': content, 'forms': forms, 'lists': lists});

    final after = document.captureState();
    if (before.fingerprint == after.fingerprint) return;
    _undo.push(UndoEntry(
      undo: () async {
        document.restoreState(before);
        notifyListeners();
      },
      redo: () async {
        document.restoreState(after);
        notifyListeners();
      },
    ));
    notifyListeners();
  }

  /// Wires the controller's [undo]/[redo] into the Forge shell via
  /// [ShellEditorIntegration.registerAction] (§10). The controller's own undo
  /// stack is the single authority; the shell's undo/redo actions dispatch to
  /// it.
  void attachIntegration(ShellEditorIntegration integration) {
    integration.registerAction(
      StandardEditingActions.undoActionId,
      undo,
      isEnabled: () => canUndo,
    );
    integration.registerAction(
      StandardEditingActions.redoActionId,
      redo,
      isEnabled: () => canRedo,
    );
  }

  // --- internals ----------------------------------------------------------

  String _nextEntryId() => 'c${++_entrySeq}';

  String _turnIdForEdit() => _currentTurnId ?? 'u${++_editSeq}';

  /// Pushes the before→after snapshot pair and records [makeEntry] — unless the
  /// edit changed nothing (no-op edits don't snapshot or record, §10).
  void _commit(SpecDocumentState before, ChangeEntry Function() makeEntry) {
    final after = document.captureState();
    if (before.fingerprint == after.fingerprint) return;
    _undo.push(UndoEntry(
      undo: () async {
        document.restoreState(before);
        notifyListeners();
      },
      redo: () async {
        document.restoreState(after);
        notifyListeners();
      },
    ));
    changeLog.record(makeEntry());
    notifyListeners();
  }

  @override
  void dispose() {
    _undo.dispose();
    changeLog.dispose();
    super.dispose();
  }
}

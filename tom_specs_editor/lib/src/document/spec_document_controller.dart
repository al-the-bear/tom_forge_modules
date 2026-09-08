import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;
import 'package:tom_forge_agentic/tom_forge_agentic.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart'
    show DefaultUndoManager, ShellEditorIntegration, UndoEntry;
import 'package:tom_som_dart_runtime/tom_som_dart_runtime.dart'
    show
        SpecNodeCreator,
        SomMetaTree,
        SpecDocumentMarkdown,
        SpecSectionIdCollision,
        SpecValidationError,
        buildSomMetaTree,
        generateListItemSectionId,
        validateDocument;

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

/// A projection anchor found along a structural path
/// (`tom_specs_editor_specification.md` §14, N12): the section id of the
/// deepest annotated class on the path, and the index of the segment it was
/// found at. Shared by [SpecDocumentController.canonicalPathFor] (which
/// re-roots on the id) and [SpecDocumentController.storagePathFor] (which
/// re-roots on the master's structural path), so the two can never disagree
/// about *which* section a path names.
class _PathAnchor {
  const _PathAnchor(this.sectionId, this.index);

  final String sectionId;
  final int index;
}

/// The single document controller shared by the UI and the agent tools
/// (`tom_specs_editor_specification.md` §8).
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
    bool strictHeadlineEditing = true,
    bool strictValidation = false,
  }) : _modelFuture = modelFuture,
       document = document ?? SpecDocument(),
       changeLog = changeLog ?? ChangeLog(),
       strictHeadlineEditing = ValueNotifier<bool>(strictHeadlineEditing),
       strictValidation = ValueNotifier<bool>(strictValidation),
       _undo = DefaultUndoManager(maxEntries: maxSnapshots) {
    _savedState = this.document.captureState();
    _savedFingerprint = _savedState.fingerprint;
  }

  final Future<SpecModel> _modelFuture;

  /// Editor "strict" mode (YRD9): when `true`, headline/id editing is offered
  /// only on list-entry sections; fixed sections show their effective default
  /// headline read-only. When `false`, headlines are editable everywhere. The
  /// document tree listens to this notifier so a preference change re-renders
  /// the header controls without rebuilding the controller. It gates *writes*
  /// only — no document/format change of its own.
  final ValueNotifier<bool> strictHeadlineEditing;

  /// Editor "strict mode" for **document validation** (csmc9): when `true`, the
  /// document editor runs the canonical runtime document validator
  /// ([validateDocument]) over the live document on load and after every edit,
  /// and surfaces each [SpecValidationError] as a diagnostic badge on the
  /// section it anchors on (including `oneOfCaseMismatch` and the
  /// cross-registry `danglingReference`). When `false`, no
  /// validation runs and no diagnostics show. It is a pure read-only overlay —
  /// it never blocks or mutates an edit. Distinct from [strictHeadlineEditing],
  /// which gates headline/id *writes* (YRD9).
  final ValueNotifier<bool> strictValidation;

  /// The structural-review store (shared with the structure browser).
  final ReviewStore review;

  /// The live, sparse document instance.
  final SpecDocument document;

  /// Default recursion depth for [outline] when the caller omits one.
  final int defaultOutlineDepth;

  /// The agent change log (`tom_specs_editor_specification.md` §9): records
  /// every mutation; resets on save.
  final ChangeLog changeLog;

  /// The snapshot-based undo stack (`tom_specs_editor_specification.md` §10),
  /// capped at `maxSnapshots` entries.
  final DefaultUndoManager _undo;

  /// The document state as of the last save (or load) — the review's base pane
  /// (`baseAtLastSave`, `tom_specs_editor_specification.md` §9) and the dirty
  /// reference (`tom_specs_editor_specification.md` §10).
  late SpecDocumentState _savedState;
  late String _savedFingerprint;

  /// The active agent turn id, or `null` when the user is editing freely. Edits
  /// made during a turn share this id so the change log groups them and the
  /// undo stack collapses them into one step
  /// (`tom_specs_editor_specification.md` §9, §10).
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

  /// Loads and caches the model future on first use, then binds both stores to
  /// [storagePathFor] so every projection route folds onto one entry
  /// (`tom_specs_editor_specification.md` §14).
  ///
  /// The binding waits for the model because the mapping is derived from it.
  /// Both stores tolerate being written before that: [storagePathFor] is the
  /// identity while the model is unresolved (there is nothing to fold before a
  /// model exists), and both stores re-key whatever they already hold when the
  /// mapper arrives.
  Future<SpecModel> ensureLoaded() async {
    if (_model != null) return _model!;
    _model = await _modelFuture;
    document.installPathNormalizer(storagePathFor);
    review.installKeyMapper(storagePathFor);
    return _model!;
  }

  // --- `tom_specs_editor_specification.md` §14 root navigation (step 20) -----

  /// The section id / type name of the document root the editor renders, or
  /// `null` for the default (the Solution Blueprint master). Driven by the
  /// `tom_specs_editor_specification.md` §14 root navigator; the editor
  /// projects the *same* shared [document] through the chosen root, so
  /// switching roots never copies or forks data.
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

  // --- `tom_specs_editor_specification.md` §14 cross-projection
  // --- identity (N12, OE-18) -------------------------------------------------

  /// Whether [rootSeg] names a *projection* root — one of the thirteen roots
  /// that project over the Solution Blueprint (the twelve Phase-3
  /// `@Document(basedOn: [SolutionBlueprint])` documents plus
  /// `D13CodeSpecsProjection`, the Phase-4 code-generation projection) —
  /// rather than the Solution Blueprint master itself.
  ///
  /// Solution Blueprint (`type == 'SolutionBlueprint'` or `sectionId == 'SBP'`)
  /// is the source of truth; every other root projects a subset of the
  /// blueprint's sections. Returns `false` for an unknown [rootSeg].
  bool isProjectionRoot(String rootSeg) {
    final root = _rootBySeg(rootSeg);
    if (root == null) return false;
    return !(root.type == 'SolutionBlueprint' || root.sectionId == 'SBP');
  }

  /// Maps a structural [path] to its **canonical** form, anchored on the deepest
  /// section that carries a stable section id *and* a projection annotation
  /// (`@MapsTo` / `@DetailedIn`) — the N12 projection→PD binding.
  ///
  /// A projection root (e.g. `RequirementsSpecification`) aggregates the *same*
  /// SBP00 classes the master uses. When such an aggregated class is annotated,
  /// its unique class section id identifies the one shared underlying section
  /// regardless of which root the editor reached it through. So
  /// `RSP/functionalRequirements` and `SBP/systemOverview/requirements/
  /// functionalRequirements` both canonicalize to `FR/…`, naming the identical
  /// node.
  ///
  /// Segments *below* the anchor are preserved verbatim, so list items and
  /// nested fields keep their relative position under the shared section. A path
  /// whose deepest annotated+section-id'd class is the root itself (or that has
  /// none — purely structural, unannotated classes) is returned unchanged: those
  /// stay route-local, which is what keeps per-document instances of an
  /// *unannotated* shared class (e.g. each document's own `DocumentHeader`)
  /// distinct rather than conflated.
  ///
  /// This is the **identity** primitive — it answers "are these two routes the
  /// same section?" in a root-independent name. It is not the storage key:
  /// values and reviews are keyed by [storagePathFor], which resolves the same
  /// anchor but re-roots it on the master's structural path (so the store stays
  /// a prefix-consistent tree).
  String canonicalPathFor(String path) {
    final segs = path.split('/');
    final anchor = _anchorOf(segs);
    if (anchor == null) return path;
    final below = segs.sublist(anchor.index + 1);
    return [anchor.sectionId, ...below].join('/');
  }

  /// Maps a structural [path] to the **storage key** the value store and the
  /// [ReviewStore] hold it under: the same anchor [canonicalPathFor] finds, but
  /// re-rooted on where that anchored section sits in the **Solution Blueprint
  /// master** tree.
  ///
  /// So `RSP/functionalRequirements` and
  /// `SBP/systemOverview/requirements/functionalRequirements` both store as the
  /// latter — one entry, edited identically from either route
  /// (`tom_specs_editor_specification.md` §14, N12). A path with no anchor (a
  /// route-local unannotated class such as each document's own
  /// `DocumentHeader`, or a bare root segment) is returned unchanged and stays
  /// route-local.
  ///
  /// **Why the master path and not the bare anchor id.** The store's emptiness
  /// and purge logic is a prefix scan, so its key space has to be a tree: a
  /// subtree of paths must map to a subtree of keys. Anchor-id-rooted canonical
  /// paths are *not* — everything above the anchor is replaced, so
  /// `hasValuesUnder('SBP/systemOverview')` would stop seeing a value stored
  /// under `FR/…`. Master structural paths are the fixed point of that
  /// requirement: the rewrite is the identity on the master route, every
  /// projection route folds *into* the master tree rather than out of it, and
  /// prefix scans keep working untouched. It is also the key space the
  /// `*.docspecs.yaml` codec, the document validator, the markdown codec and
  /// [SpecNodeCreator] already walk, so they all see projection edits for free.
  ///
  /// Idempotent and prefix-preserving, as [SpecDocument.pathNormalizer]
  /// requires. Before the model resolves there is nothing to fold, so the
  /// mapping is the identity; [ensureLoaded] re-keys both stores once it can
  /// answer properly. Memoized from then on — the model is immutable once
  /// loaded, so a path's key never changes again.
  String storagePathFor(String path) {
    if (!isModelLoaded) return path;
    return _storagePathCache[path] ??= _computeStoragePath(path);
  }

  final Map<String, String> _storagePathCache = {};

  String _computeStoragePath(String path) {
    final segs = path.split('/');
    final anchor = _anchorOf(segs);
    if (anchor == null) return path;
    final masterBase = _masterPathBySectionId()[anchor.sectionId];
    // No master home (a projection-local annotated class — a
    // `tom_specs_editor_specification.md` §14 pure-projection invariant
    // violation): keep the path route-local rather than invent a key outside
    // the structural tree.
    if (masterBase == null) return path;
    final below = segs.sublist(anchor.index + 1);
    return [masterBase, ...below].join('/');
  }

  /// The deepest projection anchor along [segs] — the last segment whose
  /// resolved class carries **both** a section id and a projection annotation
  /// (`@MapsTo` / `@DetailedIn`) — or `null` when the path has none.
  ///
  /// The scan **stops at the first list item**. Below an item, identity is
  /// positional (which item), not class-level: anchoring there would collapse
  /// every item of the list onto one key. The item's own suffix is instead
  /// carried verbatim under the anchor that owns the list.
  _PathAnchor? _anchorOf(List<String> segs) {
    if (segs.isEmpty) return null;
    _PathAnchor? anchor;
    var acc = '';
    for (var i = 0; i < segs.length; i++) {
      acc = i == 0 ? segs[0] : '$acc/${segs[i]}';
      final node = resolve(acc);
      if (node == null) break;
      if (node.isListItem) break;
      final cls = node.cls;
      if (cls != null &&
          cls.sectionId != null &&
          (cls.mapsTo != null || cls.detailedIn != null)) {
        anchor = _PathAnchor(cls.sectionId!, i);
      }
    }
    return anchor;
  }

  Map<String, String>? _masterPathIndex;

  /// Section id → its structural path in the **Solution Blueprint master**
  /// tree, built once per model. Only single-valued (root and complex) field
  /// steps are walked: a list element class has no fixed path (its identity is
  /// the `-N` item suffix), and [_anchorOf] never anchors below an item, so
  /// such a class can never be looked up here.
  Map<String, String> _masterPathBySectionId() =>
      _masterPathIndex ??= _buildMasterPathIndex();

  Map<String, String> _buildMasterPathIndex() {
    final index = <String, String>{};
    final master = model.roots.firstWhere(
      (r) => r.type == 'SolutionBlueprint' || r.sectionId == 'SBP',
      orElse: () => model.roots.first,
    );
    // Visited classes are never revisited: the first (document-order) path a
    // class is reached by is its home, and every class beneath it was recorded
    // from there. That also bounds the walk linearly over a shared DAG.
    final visited = <String>{};
    void walk(SpecClass? cls, String path) {
      if (cls == null || !visited.add(cls.name)) return;
      final id = cls.sectionId;
      // First occurrence wins: `@SectionId` is globally unique
      // (`tom_specs_model_rules.md` §10.2), so a second hit would be a model
      // defect, not a legitimate second home.
      if (id != null) index.putIfAbsent(id, () => path);
      for (final f in cls.fields) {
        if (f.kind != SpecFieldKind.complex) continue;
        walk(model.classNamed(f.type), '$path/${_segOf(f)}');
      }
    }

    walk(model.classNamed(master.type), _rootSeg(master));
    return index;
  }

  // --- Layer A: schema lookups -----------------------------------------------

  /// The class identified by [id], which may be a class name or a section id.
  SpecClass? classById(String id) {
    final byName = model.classes[id];
    if (byName != null) return byName;
    for (final c in model.classes.values) {
      if (c.sectionId == id) return c;
    }
    return null;
  }

  // --- Path resolution -------------------------------------------------------

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

  // --- Layer B: live outline -------------------------------------------------

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
                    'children': _outlineClass(
                      elem,
                      itemPath,
                      depth - 1,
                      nextSeen,
                    ),
                },
            ];
          }
        case SpecFieldKind.complex:
          final nested = model.classNamed(f.type);
          if (f.type != null) node['type'] = f.type;
          if (depth > 1 && nested != null) {
            final nextSeen = {...seenTypes};
            if (nextSeen.add(f.type!)) {
              node['children'] = _outlineClass(
                nested,
                path,
                depth - 1,
                nextSeen,
              );
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

  // --- csmc9 strict-mode document validation ---------------------------------

  /// Runs the canonical runtime document validator ([validateDocument]) over the
  /// live [document] against the resolved [model], returning every
  /// [SpecValidationError] in the runtime's stable order. Returns an empty list
  /// when the model has not resolved yet (validation is schema-dependent) — the
  /// caller [ensureLoaded]s before relying on it, but the guard keeps a
  /// pre-load call safe. The full result covers every [SpecValidationCode]
  /// (`danglingPath`, `kindMismatch`, `unknownFormField`, `minItems`,
  /// `oneOfCaseMismatch`).
  List<SpecValidationError> validate() {
    if (_model == null) return const [];
    return validateDocument(_model!, document);
  }

  /// The [validate] result grouped by the section path each error anchors on,
  /// so the document editor can slice out the diagnostics for a single section
  /// header in one lookup. The `oneOfCaseMismatch` for a mis-selected subsection
  /// is keyed on that subsection's path, so it surfaces on the offending node.
  Map<String, List<SpecValidationError>> validationByPath() {
    final byPath = <String, List<SpecValidationError>>{};
    for (final err in validate()) {
      (byPath[err.path] ??= <SpecValidationError>[]).add(err);
    }
    return byPath;
  }

  /// Toggles strict-mode document validation (csmc9). Notifies listeners so the
  /// document tree re-renders with (or without) the diagnostics overlay; the
  /// [strictValidation] notifier itself also fires for direct listeners.
  void setStrictValidation(bool value) {
    if (strictValidation.value == value) return;
    strictValidation.value = value;
    notifyListeners();
  }

  // --- Layer C: content + mutations ------------------------------------------

  /// The tool-call id to stamp on the next recorded change, when a mutation
  /// originates from an agent tool. Cleared per turn by [endTurn].
  String? activeToolCallId;

  /// The content value at [path], or `null`.
  String? content(String path) => document.content(path);

  /// Whether any value exists at [path] or beneath it — the structural
  /// emptiness test the compact tree uses to decide chip-vs-expanded
  /// (`tom_specs_editor_specification.md` §13.1, D4). An untouched node is
  /// empty and renders as a clickable chip.
  bool hasValuesUnder(String path) => document.hasValuesUnder(path);

  /// The ordered item paths of the list at [listPath] (empty when none).
  List<String> listItems(String listPath) => document.listItems(listPath);

  /// The form [field] value at [path], or `null`.
  String? formField(String path, String field) =>
      document.formField(path, field);

  // --- YRD9 headline + list-item section id ----------------------------------

  /// The stored headline at [path], or `null` when the section renders its
  /// effective default (YRD3 store). Editors compose this with
  /// [effectiveHeadline] to show the current title.
  String? headline(String path) => document.headline(path);

  /// The effective default headline of the node at [path] — the title shown
  /// when no headline is stored (YRD4 precedence: `@Headline` default, else the
  /// derived Title-Case name / list-item stem). Returns the empty string when
  /// [path] does not resolve.
  ///
  /// This is the *default*, not the stored value: [headline] wins over it. New
  /// sections prefill their headline field from this (YRD9 item 4), and strict
  /// mode shows it read-only for fixed sections.
  String effectiveDefaultHeadline(String path) {
    final node = resolve(path);
    if (node == null) return '';
    if (node.isListItem) {
      final elem = node.cls;
      return elem?.headline ??
          SpecDocumentMarkdown.itemTitleStem(node.type ?? 'item');
    }
    final field = node.field;
    if (field != null) {
      return field.headline ?? SpecDocumentMarkdown.titleCase(field.name);
    }
    // A document root: its title, else the Title-Case type name.
    final root = _rootBySeg(node.path.split('/').first);
    if (root != null) {
      final title = root.title;
      if (title.isNotEmpty) return title;
      return SpecDocumentMarkdown.titleCase(root.type);
    }
    return SpecDocumentMarkdown.titleCase(node.type ?? node.path);
  }

  /// Sets the stored headline at [path]. To keep untouched documents
  /// byte-stable (YRD3, SOM §11.7), a value equal to the
  /// [effectiveDefaultHeadline]
  /// *clears* the stored headline rather than storing a redundant copy. Routes
  /// through the undo/dirty machinery (no change-log entry — headlines are not
  /// part of the agent change log).
  void setHeadline(String path, String value) {
    final effective = value.trim() == effectiveDefaultHeadline(path).trim()
        ? ''
        : value;
    if (document.headline(path) == (effective.isEmpty ? null : effective)) {
      return;
    }
    final before = document.captureState();
    document.setHeadline(path, effective);
    _commitDocMutation(before);
  }

  /// The stored section id of the list item at [itemPath], or `null` when it
  /// carries only its positional pattern id (AA1 read path).
  String? itemSectionId(String itemPath) => document.itemSectionId(itemPath);

  /// Overrides the section id of the list item at [itemPath] (AA1 criterion 5),
  /// routed through undo/dirty. Returns `false` (mutating nothing) when [id] is
  /// empty, unchanged, or collides with another id in the same list — the
  /// editor re-seeds its field to the stored value on a rejected edit.
  bool setItemSectionId(String itemPath, String id) {
    if (id.isEmpty || document.itemSectionId(itemPath) == id) return false;
    final before = document.captureState();
    try {
      document.setItemSectionId(itemPath, id);
    } on SpecSectionIdCollision {
      return false;
    } on ArgumentError {
      return false;
    }
    _commitDocMutation(before);
    return true;
  }

  /// Sets the content at [path]. Snapshots + records the change unless it is a
  /// no-op (`tom_specs_editor_specification.md` §9, §10).
  ///
  /// The change log is keyed by [storagePathFor], like the store itself, so two
  /// routes to one section produce one section's history
  /// (`tom_specs_editor_specification.md` §14) — and the `baseAtLastSave`
  /// lookup hits the raw snapshot map with the right key.
  void setContent(String path, String value) {
    final key = storagePathFor(path);
    final before = document.captureState();
    final beforeVal = document.content(path);
    document.setContent(path, value);
    _commit(
      before,
      () => ChangeEntry(
        id: _nextEntryId(),
        sectionId: key,
        kind: ChangeKind.content,
        turnId: _turnIdForEdit(),
        beforeThisEdit: beforeVal,
        afterThisEdit: value.isEmpty ? null : value,
        baseAtLastSave: _savedState.contentAt(key),
        toolCallId: activeToolCallId,
      ),
    );
  }

  /// Sets the form [field] at [path]. Snapshots + records the change unless it
  /// is a no-op.
  void setFormField(String path, String field, String value) {
    final key = storagePathFor(path);
    final before = document.captureState();
    final beforeVal = document.formField(path, field);
    document.setFormField(path, field, value);
    _commit(
      before,
      () => ChangeEntry(
        id: _nextEntryId(),
        sectionId: key,
        kind: ChangeKind.formField,
        field: field,
        turnId: _turnIdForEdit(),
        beforeThisEdit: beforeVal,
        afterThisEdit: value.isEmpty ? null : value,
        baseAtLastSave: _savedState.formFieldAt(key, field),
        toolCallId: activeToolCallId,
      ),
    );
  }

  /// Appends a list item at [listPath] and returns its new path.
  ///
  /// When the owning list field carries a `@SectionIdPattern`, the new item is
  /// prefilled with a generated section id (YRD9 item 4 / AA1) built from the
  /// pattern, the current date, and the list's existing ids. The id is stored
  /// but editable per the editor mode; generation is skipped for lists without
  /// a pattern (they keep their positional id).
  String addListItem(String listPath) {
    final before = document.captureState();
    final generatedId = _generatedItemSectionId(listPath);
    final itemPath = document.addListItem(listPath, sectionId: generatedId);
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

  /// Adds the model-permitted child [childSegment] under [parentPath] — the SOM §13
  /// constrained-creation gate — returning the new node's path.
  ///
  /// The add is validated against the meta-model by [SpecNodeCreator]; an
  /// illegal add throws `SpecCreationError` (`tom_som_dart_runtime`) and mutates
  /// nothing. A **list** child appends a fresh item and records a change-log
  /// entry + undo snapshot, exactly like [addListItem]; a **single-valued**
  /// child returns its path *without* mutating the sparse store (the caller sets
  /// its value next), so it records nothing until that value is set — the no-op
  /// rule of [_commit]. This is the mutation the engine's `spec` scope binds to
  /// (plan step 18), so a script add and a tool add land in the one change log.
  String addChild(String parentPath, String childSegment, {String? itemId}) {
    final before = document.captureState();
    final childPath = SpecNodeCreator(
      model,
      document,
    ).add(parentPath, childSegment, itemId: itemId);
    _commit(
      before,
      () => ChangeEntry(
        id: _nextEntryId(),
        sectionId: childPath,
        kind: ChangeKind.listAdd,
        turnId: _turnIdForEdit(),
        afterThisEdit: childPath,
        toolCallId: activeToolCallId,
      ),
    );
    return childPath;
  }

  /// Applies a structural-review decision at [path], routed through the shared
  /// [ReviewStore] (which persists immediately).
  ///
  /// Review decisions live in the [ReviewStore], not the [SpecDocument], so a
  /// review is **recorded** in the change log (it is a mutation,
  /// `tom_specs_editor_specification.md` §9) but is not part of the
  /// snapshot/undo stack (`tom_specs_editor_specification.md` §10) — undoing a
  /// review is a separate concern owned by the review store.
  void setReview(String path, void Function(ReviewEntry) mutate) {
    review.update(path, mutate);
    changeLog.record(
      ChangeEntry(
        id: _nextEntryId(),
        sectionId: storagePathFor(path),
        kind: ChangeKind.review,
        turnId: _turnIdForEdit(),
        toolCallId: activeToolCallId,
      ),
    );
    notifyListeners();
  }

  // --- `tom_specs_editor_specification.md` §9 change log & review ------------

  /// Resolves the live current value at [entry]'s section, for the review's
  /// pane-3 ("current") column.
  String? currentValueFor(ChangeEntry entry) =>
      entry.kind == ChangeKind.formField
      ? document.formField(entry.sectionId, entry.field!)
      : document.content(entry.sectionId);

  /// Applies a **pick-a-pane** resolution (`tom_specs_editor_specification.md`
  /// §9, M1): the chosen [pane]'s value becomes the section's new value. This
  /// is an ordinary edit — it routes through [setContent]/[setFormField], so
  /// picking a *different* value **creates a new undo entry**; picking the
  /// current value is a no-op.
  void applyPanePick(ChangeEntry entry, ReviewPane pane) {
    final value = entry.valueForPane(pane, current: currentValueFor(entry));
    if (entry.kind == ChangeKind.formField) {
      setFormField(entry.sectionId, entry.field!, value ?? '');
    } else {
      setContent(entry.sectionId, value ?? '');
    }
  }

  // --- `tom_specs_editor_specification.md` §10 Undo / redo -------------------

  /// Begins an agent [turnId]: edits until [endTurn] share the turn (change-log
  /// grouping, `tom_specs_editor_specification.md` §9) and collapse into a
  /// single undo step (`tom_specs_editor_specification.md` §10).
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

  /// Whether the document differs from its last-saved state
  /// (`tom_specs_editor_specification.md` §10).
  bool get isDirty => document.captureState().fingerprint != _savedFingerprint;

  /// Undoes the most recent edit (or agent turn).
  Future<void> undo() => _undo.undo();

  /// Redoes the most recently undone edit (or agent turn).
  Future<void> redo() => _undo.redo();

  /// Save-point bookkeeping (`tom_specs_editor_specification.md` §9, §10): the
  /// saved state becomes the new base, the change log resets, and dirty clears.
  /// The undo stack is deliberately **kept** so post-save undo still works
  /// (`tom_specs_editor_specification.md` §9, N6).
  void save() {
    _savedState = document.captureState();
    _savedFingerprint = _savedState.fingerprint;
    changeLog.reset();
    notifyListeners();
  }

  // --- `tom_specs_editor_specification.md` §15.1 `*.docspecs.yaml` I/O -------

  /// Serializes the document + review state to [file] as a two-pass
  /// `*.docspecs.yaml` (`tom_specs_editor_specification.md` §15.1), then
  /// re-baselines as a save point.
  ///
  /// The agent change log is **not** serialized (it resets on save, M2); the
  /// optional [sessionId] is written to a `<file>.session` sidecar (A2), never
  /// into the document YAML. The undo stack is kept (post-save undo still
  /// works, N6), matching [save]'s contract.
  Future<void> saveDocSpecs(File file, {String? sessionId}) async {
    await ensureLoaded();
    final yaml = DocSpecsFile.encode(
      document: document,
      tree: _masterTree(),
      review: review.entries,
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(yaml);
    await DocSpecsFile.writeSessionId(file, sessionId);
    save();
  }

  /// Loads document + review state from a two-pass `*.docspecs.yaml` [file]
  /// (`tom_specs_editor_specification.md` §15.1), restoring the full UI state.
  /// Returns the SDK session id from the sidecar, or `null` when absent.
  ///
  /// A load is a fresh save point: the change log resets, the undo stack is
  /// cleared (there is nothing before the loaded document to undo to), and the
  /// loaded state becomes the dirty reference.
  Future<String?> loadDocSpecs(File file) async {
    await ensureLoaded();
    final parsed = DocSpecsFile.decode(
      await file.readAsString(),
      _masterTree(),
    );
    document.restoreState(parsed.document.captureState());
    review.replaceEntries(parsed.review);
    _undo.clear();
    changeLog.reset();
    _savedState = document.captureState();
    _savedFingerprint = _savedState.fingerprint;
    notifyListeners();
    return await DocSpecsFile.readSessionId(file);
  }

  /// The metadata tree of the Solution Blueprint master root — the
  /// tree-driven `*.docspecs.yaml` codec walks it to place every document value
  /// at its hierarchical section-id path. Solution Blueprint (`type ==
  /// 'SolutionBlueprint'` or `sectionId == 'SBP'`) is the source of truth; the
  /// twelve Phase-3 roots project subsets of it. Falls back to the first root
  /// for models that carry no explicit master (e.g. single-root test models).
  SomMetaTree _masterTree() {
    final master = model.roots.firstWhere(
      (r) => r.type == 'SolutionBlueprint' || r.sectionId == 'SBP',
      orElse: () => model.roots.first,
    );
    return buildSomMetaTree(model, rootType: master.type);
  }

  // --- `tom_specs_editor_specification.md` §15.2 markdown import / export ----

  /// Renders the populated subtree of the root identified by [rootSeg] (a root
  /// section id or type name) as a schema-conformant markdown document with a
  /// `<!-- docspec: -->` header (`tom_specs_editor_specification.md` §15.2).
  /// Throws [ArgumentError] for an unknown root.
  String exportMarkdown(String rootSeg) {
    final root = _rootBySeg(rootSeg);
    if (root == null) {
      throw ArgumentError('No document root for "$rootSeg"');
    }
    return MarkdownDocument(this).exportRoot(root);
  }

  /// Imports [text] as a **full overwrite** of the covered root scope
  /// (`tom_specs_editor_specification.md` §15.2, IO1): the parsed values
  /// replace everything under the imported root(s), applied as a single
  /// undoable step. Returns the parse report — unmapped or malformed blocks are
  /// listed in [MarkdownImportResult.rejections], never silently dropped.
  MarkdownImportResult importMarkdown(String text) {
    final result = MarkdownDocument(this).parse(text);
    _applyMarkdownImport(result);
    return result;
  }

  /// Replaces every value under [MarkdownImportResult.rootPrefixes] with the
  /// parsed values, as one undo entry: purge the covered scope, then merge the
  /// parsed values over what is left and reload — so other roots are untouched
  /// and list seq/item paths are restored exactly.
  ///
  /// **Both halves are store-agnostic on purpose.** The purge runs through
  /// [SpecDocument.removeValuesUnder], which clears every store the document
  /// holds, and the carry-over is whatever [SpecDocument.toJson] then emits.
  /// Naming the stores here instead would silently drop any store the document
  /// gains later — which is exactly how stored headlines (YRD3) and codeSpec
  /// mappings (`codespecs_mapping.md` §9.2) came to be wiped across the whole
  /// document by an import covering a single root.
  ///
  /// This is the one place that works on the raw stores
  /// ([SpecDocument.toJson]/[SpecDocument.loadJson] bypass the key normalizer),
  /// so the parser's structural paths are mapped through [storagePathFor] by
  /// hand before they meet the live keys. The scope needs no such mapping —
  /// [SpecDocument.removeValuesUnder] normalizes what it is given.
  void _applyMarkdownImport(MarkdownImportResult result) {
    if (result.rootPrefixes.isEmpty) return;
    final before = document.captureState();

    for (final prefix in result.rootPrefixes) {
      document.removeValuesUnder(prefix);
    }

    final doc = document.toJson();
    document.loadJson({
      'content': _storeOf(doc, 'content')
        ..addAll(_toStorageKeys(result.content)),
      'forms': _storeOf(doc, 'forms')..addAll(_toStorageKeys(result.forms)),
      'lists': _storeOf(doc, 'lists')
        ..addAll(_listsToStorageKeys(result.lists)),
      'headlines': _storeOf(doc, 'headlines')
        ..addAll(_toStorageKeys(result.headlines)),
      'codeSpecs': _storeOf(doc, 'codeSpecs')
        ..addAll(_toStorageKeys(result.codeSpecs)),
    });

    final after = document.captureState();
    if (before.fingerprint == after.fingerprint) return;
    _undo.push(
      UndoEntry(
        undo: () async {
          document.restoreState(before);
          notifyListeners();
        },
        redo: () async {
          document.restoreState(after);
          notifyListeners();
        },
      ),
    );
    notifyListeners();
  }

  /// The [store] entry of a [SpecDocument.toJson] view as a plain mutable map,
  /// ready to be merged into. Empty stores are omitted from that view, so a
  /// missing entry reads as `{}`.
  Map<String, Object?> _storeOf(Map<String, Object?> doc, String store) {
    final held = doc[store];
    return {
      if (held is Map)
        for (final e in held.entries) '${e.key}': e.value,
    };
  }

  /// [values] re-keyed from structural into storage space ([storagePathFor]).
  Map<String, Object?> _toStorageKeys(Map<String, Object?> values) => {
    for (final e in values.entries) storagePathFor(e.key): e.value,
  };

  /// [lists] re-keyed into storage space — the list paths *and* the item paths
  /// nested inside each `{seq, items, ids?}` record, which are stored as keys
  /// in their own right and so must move with their list.
  Map<String, Object?> _listsToStorageKeys(
    Map<String, Map<String, Object?>> lists,
  ) {
    final out = <String, Object?>{};
    for (final entry in lists.entries) {
      final spec = Map<String, Object?>.of(entry.value);
      final items = spec['items'];
      if (items is List) {
        spec['items'] = [for (final it in items) storagePathFor('$it')];
      }
      final ids = spec['ids'];
      if (ids is Map) {
        spec['ids'] = {
          for (final e in ids.entries) storagePathFor('${e.key}'): e.value,
        };
      }
      out[storagePathFor(entry.key)] = spec;
    }
    return out;
  }

  /// Wires the controller's [undo]/[redo] into the Forge shell via
  /// [ShellEditorIntegration.registerAction]
  /// (`tom_specs_editor_specification.md` §10). The controller's own undo stack
  /// is the single authority; the shell's undo/redo actions dispatch to it.
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

  // --- internals -------------------------------------------------------------

  String _nextEntryId() => 'c${++_entrySeq}';

  String _turnIdForEdit() => _currentTurnId ?? 'u${++_editSeq}';

  /// The section id to prefill a new item of the list at [listPath] with, or
  /// `null` when the list field has no `@SectionIdPattern` (YRD9 item 4 / AA1).
  String? _generatedItemSectionId(String listPath) {
    final field = resolve(listPath)?.field;
    final pattern = field?.sectionIdPattern;
    if (pattern == null || pattern.isEmpty) return null;
    return generateListItemSectionId(
      pattern,
      DateTime.now(),
      document.listItemSectionIds(listPath),
    );
  }

  /// Pushes a before→after undo snapshot for a document mutation that is *not*
  /// part of the agent change log (headline / list-item id edits, YRD9). Undo,
  /// redo, and dirty tracking work exactly as for content edits; only the
  /// change-log/turn machinery is skipped. A no-op edit snapshots nothing.
  void _commitDocMutation(SpecDocumentState before) {
    final after = document.captureState();
    if (before.fingerprint == after.fingerprint) return;
    _undo.push(
      UndoEntry(
        undo: () async {
          document.restoreState(before);
          notifyListeners();
        },
        redo: () async {
          document.restoreState(after);
          notifyListeners();
        },
      ),
    );
    notifyListeners();
  }

  /// Pushes the before→after snapshot pair and records [makeEntry] — unless the
  /// edit changed nothing (no-op edits don't snapshot or record,
  /// `tom_specs_editor_specification.md` §10).
  void _commit(SpecDocumentState before, ChangeEntry Function() makeEntry) {
    final after = document.captureState();
    if (before.fingerprint == after.fingerprint) return;
    _undo.push(
      UndoEntry(
        undo: () async {
          document.restoreState(before);
          notifyListeners();
        },
        redo: () async {
          document.restoreState(after);
          notifyListeners();
        },
      ),
    );
    changeLog.record(makeEntry());
    notifyListeners();
  }

  @override
  void dispose() {
    strictHeadlineEditing.dispose();
    strictValidation.dispose();
    _undo.dispose();
    changeLog.dispose();
    super.dispose();
  }
}

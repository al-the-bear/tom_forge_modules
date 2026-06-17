import 'package:flutter/foundation.dart';

import '../structure/review_store.dart';
import '../structure/spec_model.dart';
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
  })  : _modelFuture = modelFuture,
        document = document ?? SpecDocument();

  final Future<SpecModel> _modelFuture;

  /// The structural-review store (shared with the structure browser).
  final ReviewStore review;

  /// The live, sparse document instance.
  final SpecDocument document;

  /// Default recursion depth for [outline] when the caller omits one.
  final int defaultOutlineDepth;

  SpecModel? _model;

  /// The resolved model. Only valid after [ensureLoaded] has completed.
  SpecModel get model => _model!;

  /// Loads and caches the model future on first use.
  Future<SpecModel> ensureLoaded() async => _model ??= await _modelFuture;

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

  /// The content value at [path], or `null`.
  String? content(String path) => document.content(path);

  /// The form [field] value at [path], or `null`.
  String? formField(String path, String field) =>
      document.formField(path, field);

  /// Sets the content at [path], notifying listeners.
  void setContent(String path, String value) {
    document.setContent(path, value);
    notifyListeners();
  }

  /// Sets the form [field] at [path], notifying listeners.
  void setFormField(String path, String field, String value) {
    document.setFormField(path, field, value);
    notifyListeners();
  }

  /// Appends a list item at [listPath] and returns its new path.
  String addListItem(String listPath) {
    final itemPath = document.addListItem(listPath);
    notifyListeners();
    return itemPath;
  }

  /// Removes the list item at [itemPath]; returns whether one was removed.
  bool removeListItem(String itemPath) {
    final removed = document.removeListItem(itemPath);
    if (removed) notifyListeners();
    return removed;
  }

  /// Applies a structural-review decision at [path], routed through the shared
  /// [ReviewStore] (which persists immediately).
  void setReview(String path, void Function(ReviewEntry) mutate) {
    review.update(path, mutate);
    notifyListeners();
  }
}

import 'dart:io';
import 'dart:typed_data';

import 'package:tom_som_dart_runtime/tom_som_dart_runtime.dart'
    show SpecNodeProjection, SpecQueryEngine;
import 'package:tom_spec_engine/memory.dart';
import 'package:tom_spec_engine/scripting.dart' show ScriptScope;

import '../document/spec_document_controller.dart';

/// The editor's **embeddable memory plane** (followup item 6, plan 20 / D102).
///
/// Binds the engine's profile-isolated Tom Brain memory surface — re-exported
/// through `package:tom_spec_engine/memory.dart` — to the live
/// [SpecDocumentController] so the `memory` script scope and the §9 fused
/// two-tier recall are live **in the editor**, in-process, with no IPC:
///
///   * **tier 1** — the always-available [StructuralLexicalIndex] (BM25 +
///     structural facets), rebuilt directly from the object model on every
///     [ensureWarm]; zero embedding calls;
///   * **tier 2** — the section-level vector store: a profile-isolated
///     [SpecDocumentMemory] over [SpecMemory] (the embeddable
///     `SqliteTomBrainMemory` + bundled `vec0`), opened lazily on first warm and
///     kept warm across recalls;
///   * the fused [recall] ([SpecRecall]) that RRF-fuses the two tiers, exposed
///     both as the read-only `memory` script [scriptScope] ([memoryScope]) and
///     behind the `mem_*` [tools] ([MemoryTools]).
///
/// **Graceful degradation.** The vector tier needs the platform-tupled `vec0`
/// binary under `tom_binaries/sqlite_vec`; if it is absent (resolved by walking
/// up from the workspace root) the plane runs **tier-1-only** — [available] is
/// `false`, [tools] still recall lexically/structurally, and `mem_refresh`
/// reports `refreshed: false`. The store would otherwise refuse to boot.
///
/// The embedder is a deterministic local hash (768-dim, the bootstrap
/// nomic-embed-text dimensionality): same text → identical vector, so a
/// self-recall is an exact vector hit without an Ollama/OpenAI backend. Swapping
/// in the provider-backed Tom Brain embedding API is a separate followup (F6).
class SpecMemoryPlane {
  /// Builds the plane over the live [controller], resolving the `vec0` binaries
  /// by walking up from [workspaceRoot] and rooting the profile store under
  /// `<workspaceRoot>/agent/memory`.
  SpecMemoryPlane({
    required this.controller,
    required String workspaceRoot,
  }) : _vecRoot = _findSqliteVecRoot(workspaceRoot) {
    final vecRoot = _vecRoot;
    _memory = vecRoot == null
        ? null
        : SpecMemory(
            memoryRoot: '$workspaceRoot/agent/memory',
            sqliteVecBinariesRoot: vecRoot,
            embedder: _embed,
          );
    recall = SpecRecall(index: _index, vectorRecall: _vectorRecall, graph: null);
    tools = MemoryTools(recall: recall, onRefresh: _refresh);
    scriptScope = memoryScope(recall);
  }

  /// The live document controller tier-1 is projected from and tier-2 indexes.
  final SpecDocumentController controller;

  /// The resolved `tom_binaries/sqlite_vec` root, or `null` when none was found
  /// (tier-1-only / degraded mode).
  final String? _vecRoot;

  /// Whether the tier-2 vector store is **effectively** live: the `vec0` binary
  /// resolved *and* the store actually opened. When `false` the plane runs
  /// tier-1-only and `mem_refresh` is a no-op. Tier 2 is disabled either because
  /// no binary was found or because the first open failed (e.g. a runtime that
  /// cannot resolve the bootstrap manifest); see [tier2Error].
  bool get available => _memory != null && !_tier2Disabled;

  /// The error that disabled the tier-2 store on first open, if any. `null`
  /// while tier 2 is healthy or was never configured.
  Object? get tier2Error => _tier2Error;

  /// The embeddable Tom Brain store backing tier 2, or `null` in degraded mode
  /// (no `vec0` binary). The live mode-(b) [SpecBrainSessionEnvelope] (followup
  /// item 8) persists its run trail through this same store, addressed by
  /// [scope], so an agent run and the document's section index share one named
  /// memory.
  SpecMemory? get memory => _memory;

  /// The single workspace profile this editor session indexes (and records
  /// agent runs) under. Sharing it between the section index and the brain run
  /// trail keeps both in one document-named memory.
  MemoryScope get scope => _scope;

  /// The fused two-tier recall — the `memory` scope and the `mem_*` tools both
  /// recall through this.
  late final SpecRecall recall;

  /// The `mem_recall` / `mem_refresh` toolset over [recall], bound to the
  /// change-tracking [_refresh] re-index.
  late final MemoryTools tools;

  /// The read-only `memory` script scope bound to [recall].
  late final ScriptScope scriptScope;

  /// The tier-1 index, rebuilt from the object model on every [ensureWarm].
  final StructuralLexicalIndex _index = StructuralLexicalIndex();

  /// The profile store, or `null` in degraded mode.
  SpecMemory? _memory;

  /// The opened tier-2 document handle (lazily, on first warm), or `null` while
  /// cold / degraded.
  SpecDocumentMemory? _document;

  /// The section paths last indexed into tier 2, to derive removals on refresh.
  Set<String> _indexedPaths = <String>{};

  /// Set once the tier-2 store fails to open, so the plane stops retrying and
  /// runs tier-1-only thereafter.
  bool _tier2Disabled = false;

  /// The error that disabled tier 2, retained for diagnostics.
  Object? _tier2Error;

  /// The single workspace profile this editor session indexes under.
  static final MemoryScope _scope = MemoryScope(
    application: 'tomspecs',
    session: 'editor',
    document: 'workspace',
  );

  /// Warms the plane: (re)builds the always-fresh tier-1 index from the current
  /// document projection and, when [available], opens and indexes the tier-2
  /// vector store on first call. Idempotent for tier 2 (the open + initial
  /// embed run once); tier 1 is rebuilt every call so recall is never stale.
  Future<void> ensureWarm() async {
    await controller.ensureLoaded();
    final projections = _projectNodes();
    _index.rebuild(projections);
    final memory = _memory;
    if (memory != null && _document == null && !_tier2Disabled) {
      // The vector tier is best-effort: a missing/incompatible runtime
      // (e.g. one that cannot resolve the bootstrap manifest) must degrade to
      // tier-1-only rather than break recall. Disable on first failure so we
      // do not re-attempt the open on every recall.
      try {
        final document = await memory.openDocument(_scope);
        final graph = SpecRagGraph.fromProjections(projections);
        await document.indexDocument(graph);
        _indexedPaths = {for (final node in graph.nodes) node.path};
        _document = document;
      } catch (error) {
        _tier2Disabled = true;
        _tier2Error = error;
      }
    }
  }

  /// Tier-2 recall delegate for [SpecRecall]. Returns nothing while tier 2 is
  /// cold / unavailable, degrading the fused recall to tier 1.
  Future<List<SpecRagHit>> _vectorRecall(String query, {int k = 10}) async {
    final document = _document;
    if (document == null) return const <SpecRagHit>[];
    return document.recallSections(query, k: k);
  }

  /// The `mem_refresh` re-index: rebuilds tier 1 and, when tier 2 is open,
  /// re-embeds only the sections whose content moved (the engine's
  /// embed-changed-only path), forgetting sections that disappeared.
  Future<MemRefreshResult> _refresh() async {
    await ensureWarm();
    final document = _document;
    if (document == null) return const MemRefreshResult(refreshed: false);
    final projections = _projectNodes();
    _index.rebuild(projections);
    final graph = SpecRagGraph.fromProjections(projections);
    final current = {for (final node in graph.nodes) node.path};
    final removed = _indexedPaths.difference(current);
    final result = await document.indexChangedSections(
      graph,
      changedPaths: current,
      removedPaths: removed,
    );
    _indexedPaths = current;
    return MemRefreshResult(
      refreshed: true,
      embedded: result.embedded,
      unchanged: result.unchanged,
      edges: result.edgeCount,
      removed: result.removed,
    );
  }

  /// Closes the profile store. Idempotent.
  Future<void> dispose() async {
    await _memory?.close();
  }

  List<SpecNodeProjection> _projectNodes() => SpecQueryEngine(
        model: controller.model,
        document: controller.document,
      ).projectNodes().toList(growable: false);

  /// The deterministic 768-dim local embedder (see the class doc). Same text →
  /// identical vector, so the embed→vector-recall pipeline is exact and
  /// backend-free. F6 swaps in the provider-backed embedding API.
  static Future<Vec> _embed(String text) async {
    const dims = 768;
    final values = Float32List(dims);
    var hash = 0x811c9dc5;
    for (final unit in text.codeUnits) {
      hash = (hash ^ unit) * 0x01000193 & 0x7fffffff;
    }
    for (var i = 0; i < dims; i++) {
      values[i] = (((hash + i * 2654435761) & 0x7fffffff) % 1000) / 1000.0;
    }
    return Vec(values);
  }

  /// Walks up from [start] (and the current directory as a fallback) for a
  /// `tom_binaries/sqlite_vec` directory holding the platform `vec0` binary.
  static String? _findSqliteVecRoot(String start) {
    for (final origin in {start, Directory.current.path}) {
      var dir = Directory(origin).absolute;
      for (var i = 0; i < 12; i++) {
        final candidate = Directory(
          '${dir.path}${Platform.pathSeparator}tom_binaries'
          '${Platform.pathSeparator}sqlite_vec',
        );
        if (candidate.existsSync()) return candidate.path;
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    }
    return null;
  }
}

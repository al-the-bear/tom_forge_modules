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
/// [SpecDocumentController] so the `memory` script scope and the
/// `llm_and_d4rt_tools.md` §9 fused two-tier recall are live **in the editor**,
/// in-process, with no IPC:
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
/// **Embedder selection (step 15 / plan 11).** Tier 2 embeds through one of two
/// surfaces, chosen **once** when the store is first built ([ensureWarm]):
///
///   * the **provider-backed** Tom Brain embedding API ([SpecProviderEmbedder],
///     Ollama `nomic-embed-text`, 768-dim, L2-normalised) when
///     `enableProviderEmbeddings` is set and the boot [SpecProviderEmbedder.probe]
///     succeeds — a full-document index then batch-embeds in one fan-out;
///   * the **deterministic local hash** ([_embed], 768-dim) otherwise — same
///     text → identical vector, so a self-recall is an exact hit with no
///     backend. This is the default and the fallback when the provider is
///     unreachable (no Ollama daemon) or reports a dimension mismatch.
///
/// The choice is per-store and permanent: provider vectors and hash vectors
/// carry different identities and must never share one store (cosine math across
/// identities is meaningless — `memory_specification.md` § 7.4). The plane never
/// falls back per call; a failed probe degrades the *whole store* to the hash.
class SpecMemoryPlane {
  /// Builds the plane over the live [controller], resolving the `vec0` binaries
  /// by walking up from [workspaceRoot] and rooting the profile store under
  /// `<workspaceRoot>/agent/memory`.
  ///
  /// When [enableProviderEmbeddings] is `true`, tier 2 attempts the
  /// provider-backed embedder ([SpecProviderEmbedder.ollama] by default, or the
  /// injected [providerEmbedder]) and falls back to the hash if its boot probe
  /// fails. When `false` (the default) the hash embedder is used directly and no
  /// provider is constructed — keeping headless/test hosts free of the
  /// platform HTTP client the Ollama provider builds.
  SpecMemoryPlane({
    required this.controller,
    required String workspaceRoot,
    bool enableProviderEmbeddings = false,
    SpecProviderEmbedder? providerEmbedder,
  })  : _workspaceRoot = workspaceRoot,
        _vecRoot = _findSqliteVecRoot(workspaceRoot) {
    _providerEmbedder = providerEmbedder ??
        (enableProviderEmbeddings ? SpecProviderEmbedder.ollama() : null);
    recall = SpecRecall(index: _index, vectorRecall: _vectorRecall, graph: null);
    tools = MemoryTools(recall: recall, onRefresh: _refresh);
    scriptScope = memoryScope(recall);
    indexer = SpecIncrementalIndexer(
      index: _index,
      projections: _projectNodes,
      // No tier-2 callback in degraded mode (no `vec0`): the indexer then runs
      // tier-1-only and reports a `null` tier-2 result. Gated on the binary
      // root, not on `_memory` — the store is now built lazily on first warm.
      tier2: _vecRoot == null ? null : _reindexTier2,
    );
    controller.changeLog.addListener(_onChangeLog);
  }

  /// The live document controller tier-1 is projected from and tier-2 indexes.
  final SpecDocumentController controller;

  /// The workspace root the profile store is rooted under (`<root>/agent/memory`).
  final String _workspaceRoot;

  /// The resolved `tom_binaries/sqlite_vec` root, or `null` when none was found
  /// (tier-1-only / degraded mode).
  final String? _vecRoot;

  /// The provider-backed embedder candidate, or `null` when provider embeddings
  /// are disabled. Built at construction (no network); its [SpecProviderEmbedder.probe]
  /// runs once when the store is first built ([_buildMemory]).
  late final SpecProviderEmbedder? _providerEmbedder;

  /// Whether the tier-2 store was built on the provider-backed embedder. `false`
  /// before the store is built, when provider embeddings are disabled, or when
  /// the boot probe failed and the plane fell back to the hash.
  bool _usingProviderEmbeddings = false;

  /// The error that made the plane fall back from the provider embedder to the
  /// hash on store build, if any. `null` when the provider was used or never
  /// attempted.
  Object? _embedderError;

  /// Whether tier 2 embeds through the provider-backed Tom Brain embedding API
  /// (vs. the deterministic hash). Meaningful only after [ensureWarm] has built
  /// the store.
  bool get usingProviderEmbeddings => _usingProviderEmbeddings;

  /// The error that disabled the provider embedder on store build (and forced
  /// the hash fallback), if any.
  Object? get embedderError => _embedderError;

  /// Whether the tier-2 vector store is **effectively** live: the `vec0` binary
  /// resolved *and* the store has not been disabled by an open failure. When
  /// `false` the plane runs tier-1-only and `mem_refresh` is a no-op. Tier 2 is
  /// disabled either because no binary was found or because the first open
  /// failed (e.g. a runtime that cannot resolve the bootstrap manifest); see
  /// [tier2Error]. Keyed on the binary root (not the lazily-built [_memory]) so
  /// it is stable before and after the first warm.
  bool get available => _vecRoot != null && !_tier2Disabled;

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

  /// The change-log-driven incremental re-indexer (followup item 14, closing
  /// D53). An edit's section paths are derived from [controller]'s change log
  /// (`[_onChangeLog]`) and [SpecIncrementalIndexer.touch]ed here; the indexer
  /// debounces a burst and re-indexes **both tiers off the edit path** — tier-1
  /// in place, tier-2 embed-changed-only — so typing never blocks on a re-embed.
  /// Exposed so a host can drain it ([SpecIncrementalIndexer.flush]) or observe
  /// a refresh.
  late final SpecIncrementalIndexer indexer;

  /// How far through [controller]'s change log [_onChangeLog] has consumed, so
  /// each notify enqueues only the **newly**-recorded entries' section paths.
  int _changeCursor = 0;

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
    final vecRoot = _vecRoot;
    if (vecRoot != null && _memory == null && !_tier2Disabled) {
      // Build the store on first warm — this is where the one-time embedder
      // choice (provider probe vs. hash) is made, before any section is
      // embedded into the store.
      _memory = await _buildMemory(vecRoot);
    }
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

  /// Builds the tier-2 store under [vecRoot], picking the embedder **once**.
  ///
  /// When a provider embedder is configured, its boot [SpecProviderEmbedder.probe]
  /// runs first: on success the store embeds through the provider (per-text +
  /// batch); on failure (no daemon / dimension mismatch) the plane catches the
  /// error and falls back to the deterministic hash for this fresh store —
  /// never mixing the two identities. With no provider configured the hash is
  /// used directly.
  Future<SpecMemory> _buildMemory(String vecRoot) async {
    SpecEmbedder embedder = _embed;
    SpecBatchEmbedder? batchEmbedder;
    final provider = _providerEmbedder;
    if (provider != null) {
      try {
        await provider.probe();
        embedder = provider.embedder;
        batchEmbedder = provider.batchEmbedder;
        _usingProviderEmbeddings = true;
        _embedderError = null;
      } catch (error) {
        // Provider unreachable or mismatched: this fresh store uses the hash.
        _usingProviderEmbeddings = false;
        _embedderError = error;
      }
    }
    return SpecMemory(
      memoryRoot: '$_workspaceRoot/agent/memory',
      sqliteVecBinariesRoot: vecRoot,
      embedder: embedder,
      batchEmbedder: batchEmbedder,
    );
  }

  /// Tier-2 recall delegate for [SpecRecall]. Returns nothing while tier 2 is
  /// cold / unavailable, degrading the fused recall to tier 1.
  Future<List<SpecRagHit>> _vectorRecall(String query, {int k = 10}) async {
    final document = _document;
    if (document == null) return const <SpecRagHit>[];
    return document.recallSections(query, k: k);
  }

  /// The `mem_refresh` re-index (item 16): a full current-state reconcile routed
  /// through the **same serialized [indexer]** the change-log path uses, so a
  /// manual refresh can never race an in-flight debounced flush and both paths
  /// drive the one engine `indexChangedSections` entrypoint (no parallel full
  /// rebuild). It reconciles the union of the document's current sections and
  /// everything previously indexed — tier-1 updated in place, tier-2 re-embedded
  /// only where the content hash moved, sections that disappeared dropped from
  /// both tiers. Reports `refreshed: false` in tier-1-only / degraded mode (no
  /// open tier-2 store), matching the no-`vec0` contract.
  Future<MemRefreshResult> _refresh() async {
    await ensureWarm();
    final current = {for (final node in _projectNodes()) node.path};
    final result = await indexer.reindexAll(current.union(_indexedPaths));
    // `_reindexTier2` (the indexer's tier-2 callback) has already refreshed
    // `_indexedPaths` to the current node set when tier 2 is live.
    final document = _document;
    final tier2 = result.tier2;
    if (document == null || tier2 == null) {
      return const MemRefreshResult(refreshed: false);
    }
    return MemRefreshResult(
      refreshed: true,
      embedded: tier2.embedded,
      unchanged: tier2.unchanged,
      edges: tier2.edgeCount,
      removed: tier2.removed,
    );
  }

  /// Change-log listener: derives the section paths of the **newly**-recorded
  /// entries (since [_changeCursor]) and [SpecIncrementalIndexer.touch]es them,
  /// so the debounced re-index runs off the edit path. A log reset (on save,
  /// when [ChangeLog.entries] shrinks below the cursor) rebases the cursor
  /// without touching anything. No-op while the model is not yet loaded.
  void _onChangeLog() {
    final entries = controller.changeLog.entries;
    if (entries.length < _changeCursor) {
      // The log was reset (e.g. on save) — rebase the cursor and wait for the
      // next edit rather than re-touching the whole document.
      _changeCursor = entries.length;
      return;
    }
    if (entries.length == _changeCursor) return;
    final fresh = entries.sublist(_changeCursor);
    _changeCursor = entries.length;
    if (!controller.isModelLoaded) return;
    indexer.touch([for (final entry in fresh) entry.sectionId]);
  }

  /// Tier-2 re-embed callback handed to [indexer]. Re-embeds only the changed
  /// sections of [graph] into the open document (the engine's
  /// embed-changed-only path) and refreshes [_indexedPaths] to the current node
  /// set. A no-op refresh result while tier 2 is cold (the indexer still drove
  /// tier 1 in place).
  Future<SpecRagRefreshResult> _reindexTier2(
    SpecRagGraph graph, {
    required Set<String> changedPaths,
    required Set<String> removedPaths,
  }) async {
    final document = _document;
    if (document == null) {
      return const SpecRagRefreshResult(
        embedded: 0,
        unchanged: 0,
        edgeCount: 0,
        removed: 0,
      );
    }
    final result = await document.indexChangedSections(
      graph,
      changedPaths: changedPaths,
      removedPaths: removedPaths,
    );
    _indexedPaths = {for (final node in graph.nodes) node.path};
    return result;
  }

  /// Detaches the change-log listener, stops the indexer, and closes the
  /// profile store and the provider embedder (if any). Idempotent.
  Future<void> dispose() async {
    controller.changeLog.removeListener(_onChangeLog);
    indexer.dispose();
    await _memory?.close();
    await _providerEmbedder?.close();
  }

  List<SpecNodeProjection> _projectNodes() => SpecQueryEngine(
        model: controller.model,
        document: controller.document,
      ).projectNodes().toList(growable: false);

  /// The deterministic 768-dim local embedder (see the class doc). Same text →
  /// identical vector, so the embed→vector-recall pipeline is exact and
  /// backend-free. The default embedder and the fallback when the provider-backed
  /// embedder (step 15) is disabled or its boot probe fails.
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

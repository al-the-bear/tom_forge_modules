// Tests for the editor's provider-backed embedder selection (followup step 15):
// the SpecMemoryPlane picks its tier-2 embedder ONCE when the store is first
// built — the provider-backed Tom Brain embedding API when its boot probe
// succeeds, otherwise the deterministic hash. The choice is per-store and
// permanent: provider and hash vectors carry different identities and must
// never share one store.
//
// These bind against an injected FAKE SpecProviderEmbedder (over a fake
// EmbeddingService re-exported from the engine) so they need no Ollama daemon
// and no platform HTTP client. They are gated on the tier-2 store actually
// being available (the packaged `vec0` binary) via `plane.available`; when it
// is absent the store is never built, so there is no embedder choice to assert.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:tom_specs_editor/src/agent/spec_memory_plane.dart';
import 'package:tom_specs_editor/src/document/spec_document_controller.dart';
import 'package:tom_specs_editor/src/structure/spec_model.dart';

import 'package:tom_spec_engine/memory.dart'
    show
        EmbeddingModelIdentity,
        EmbeddingProbeResult,
        EmbeddingResult,
        EmbeddingService,
        SpecProviderEmbedder,
        Vec;
import 'support/review_store_support.dart';

const _identity = EmbeddingModelIdentity(
  providerId: 'fake:provider',
  modelId: 'fake-embed',
  dims: 8,
  normalized: true,
);

/// A deterministic fake [EmbeddingService]: each text maps to a fixed-width
/// vector seeded by its code units, so embed and recall agree. Its probe
/// succeeds, so the plane should select the provider embedder.
final class _OkService implements EmbeddingService {
  Vec _vecFor(String text) {
    final values = Float32List(_identity.dims);
    var hash = 0x811c9dc5;
    for (final unit in text.codeUnits) {
      hash = (hash ^ unit) * 0x01000193 & 0x7fffffff;
    }
    for (var i = 0; i < values.length; i++) {
      values[i] = (((hash + i * 2654435761) & 0x7fffffff) % 1000) / 1000.0;
    }
    return Vec(values);
  }

  @override
  EmbeddingModelIdentity get currentModelIdentity => _identity;

  @override
  Future<EmbeddingResult> embed(String text) async =>
      EmbeddingResult(vec: _vecFor(text), modelIdentity: _identity);

  @override
  Future<List<EmbeddingResult>> embedBatch(List<String> texts) async => [
    for (final t in texts)
      EmbeddingResult(vec: _vecFor(t), modelIdentity: _identity),
  ];

  @override
  Future<EmbeddingProbeResult> probeIdentity({
    EmbeddingModelIdentity? previousIdentity,
    String probeText = 'tom-brain embedding probe',
  }) async => EmbeddingProbeResult(
    currentIdentity: _identity,
    probeResult: EmbeddingResult(
      vec: _vecFor(probeText),
      modelIdentity: _identity,
    ),
  );

  @override
  Future<void> close() async {}
}

/// A fake whose probe throws — the "Ollama absent / dimension mismatch" case.
/// The plane must catch it and fall back to the hash for a fresh store.
final class _FailingProbeService implements EmbeddingService {
  @override
  EmbeddingModelIdentity get currentModelIdentity => _identity;

  @override
  Future<EmbeddingResult> embed(String text) async =>
      throw StateError('embed should never be reached after a failed probe');

  @override
  Future<List<EmbeddingResult>> embedBatch(List<String> texts) async =>
      throw StateError(
        'embedBatch should never be reached after a failed probe',
      );

  @override
  Future<EmbeddingProbeResult> probeIdentity({
    EmbeddingModelIdentity? previousIdentity,
    String probeText = 'tom-brain embedding probe',
  }) async => throw const SocketException('embedding backend unreachable');

  @override
  Future<void> close() async {}
}

SpecModel _sampleModel() => SpecModel.fromJson({
  'roots': [
    {'type': 'DemoDoc', 'title': 'Demo Document', 'sectionId': 'D00'},
  ],
  'classes': {
    'DemoDoc': {
      'name': 'DemoDoc',
      'sectionId': 'D00',
      'doc': 'A demo document.',
      'fields': [
        {'name': 'overview', 'kind': 'content', 'sectionId': 'D00-OVR'},
      ],
    },
  },
});

void main() {
  late Directory dir;
  late SpecDocumentController controller;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('specs_plane_embedder_');
    controller = SpecDocumentController(
      modelFuture: Future<SpecModel>.value(_sampleModel()),
      review: memoryReviewStore(),
    );
  });
  tearDown(() {
    dir.deleteSync(recursive: true);
  });

  test('a succeeding provider probe selects the provider embedder', () async {
    final plane = SpecMemoryPlane(
      controller: controller,
      workspaceRoot: dir.path,
      providerEmbedder: SpecProviderEmbedder(_OkService()),
    );
    addTearDown(plane.dispose);

    controller.setContent('D00/D00-OVR', 'a staged rollout needle here');
    await plane.ensureWarm();

    if (!plane.available) return; // no vec0 here — no store, no choice to make.
    expect(plane.usingProviderEmbeddings, isTrue);
    expect(plane.embedderError, isNull);

    // The provider's vectors are real postings: recall still finds the section.
    final hits = await plane.tools.recallQuery('needle');
    expect(hits.hits.map((h) => h.path), contains('D00/D00-OVR'));
  });

  test('a failing provider probe falls back to the hash embedder', () async {
    final plane = SpecMemoryPlane(
      controller: controller,
      workspaceRoot: dir.path,
      providerEmbedder: SpecProviderEmbedder(_FailingProbeService()),
    );
    addTearDown(plane.dispose);

    controller.setContent('D00/D00-OVR', 'a staged rollout needle here');
    await plane.ensureWarm();

    if (!plane.available) return; // no vec0 here — probe never attempted.
    // The store was built on the hash, not the provider, and the error is
    // retained for observability. Tier 2 stays available.
    expect(plane.usingProviderEmbeddings, isFalse);
    expect(plane.embedderError, isA<SocketException>());

    // The hash fallback still indexes and recalls — degradation is graceful.
    final hits = await plane.tools.recallQuery('needle');
    expect(hits.hits.map((h) => h.path), contains('D00/D00-OVR'));
  });
}

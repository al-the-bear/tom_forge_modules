// Tests for the editor's embeddable memory plane (followup item 6): the
// SpecMemoryPlane that binds the engine's profile-isolated Tom Brain memory to
// the live document, making the `memory` script scope and the `mem_*` tools
// live in-editor.
//
// Tier 1 (lexical/structural) is always available, so its recall is asserted
// unconditionally. Tier-2 (vector) assertions are gated on the packaged `vec0`
// binary being resolvable (SpecMemoryPlane.available) — when it is absent the
// plane degrades to tier-1-only and `mem_refresh` is a no-op, which is itself
// asserted.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tom_specs_editor/src/agent/agent_tools_module.dart';
import 'package:tom_specs_editor/src/structure/review_store.dart';
import 'package:tom_specs_editor/src/structure/spec_model.dart';

/// A minimal class graph with one content section to recall.
Map<String, dynamic> _sampleJson() => {
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
        {'name': 'summary', 'kind': 'content', 'sectionId': 'D00-SUM'},
      ],
    },
  },
};

AgentToolsModule _module(Directory dir) {
  final model = SpecModel.fromJson(_sampleJson());
  final review = ReviewStore(File('${dir.path}/review.yaml'));
  return AgentToolsModule(
    modelFuture: Future<SpecModel>.value(model),
    review: review,
    scriptWorkspaceRoot: dir.path,
  );
}

void main() {
  late Directory dir;
  late AgentToolsModule module;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('specs_memory_plane_');
    module = _module(dir);
  });
  tearDown(() async {
    await module.memoryPlane.dispose();
    dir.deleteSync(recursive: true);
  });

  test('the plane is wired with a memory scope and the mem_* tools', () {
    expect(module.memoryPlane.scriptScope.name, 'memory');
    expect(module.memoryPlane.tools, isNotNull);
  });

  test(
    'mem_recall surfaces a tier-1 lexical hit (no vector tier needed)',
    () async {
      module.controller.setContent(
        'D00/D00-OVR',
        'a staged rollout needle here',
      );
      await module.memoryPlane.ensureWarm();
      final result = await module.memoryPlane.tools.recallQuery('needle');
      expect(result.hits.map((h) => h.path), contains('D00/D00-OVR'));
    },
  );

  test('the memory script scope recalls paths read-only', () async {
    module.controller.setContent('D00/D00-OVR', 'a staged rollout needle here');
    await module.memoryPlane.ensureWarm();
    final run = await module.scriptRunner.run(
      "import 'package:tom_spec_engine/memory.dart';\n"
      "main() => memory.recallPaths('needle');",
      scopes: const ['memory'],
    );
    expect(run.error, isNull, reason: run.error?.toString());
    expect(run.result, contains('D00/D00-OVR'));
  });

  test(
    'mem_refresh reports refreshed matching the vector tier availability',
    () async {
      module.controller.setContent(
        'D00/D00-OVR',
        'a staged rollout needle here',
      );
      await module.memoryPlane.ensureWarm();
      final refresh = await module.memoryPlane.tools.refresh();
      expect(refresh.refreshed, module.memoryPlane.available);
    },
  );

  test('mem_refresh routes through the one indexer: it drains a pending edit '
      'and reconciles tier 1 (item 16)', () async {
    module.controller.setContent('D00/D00-OVR', 'original baseline text');
    await module.memoryPlane.ensureWarm();

    // An edit leaves a pending touch on the shared indexer (debounced).
    module.controller.setContent('D00/D00-OVR', 'kubernetes operator needle');
    expect(module.memoryPlane.indexer.hasPending, isTrue);

    // mem_refresh now flushes through the SAME indexer rather than a parallel
    // rebuild: the pending touch is folded in and cleared, and tier 1 reflects
    // the edit (new term findable, stale term gone).
    await module.memoryPlane.tools.refresh();
    expect(module.memoryPlane.indexer.hasPending, isFalse);

    final hit = await module.memoryPlane.tools.recallQuery('kubernetes');
    expect(hit.hits.map((h) => h.path), contains('D00/D00-OVR'));
    final stale = await module.memoryPlane.tools.recallQuery('baseline');
    expect(stale.hits.map((h) => h.path), isNot(contains('D00/D00-OVR')));
  });

  group('change-log-driven incremental re-index (followup item 14, D53)', () {
    test(
      'a post-warm edit is touched into the indexer off the edit path',
      () async {
        module.controller.setContent('D00/D00-OVR', 'original baseline text');
        await module.memoryPlane.ensureWarm();

        // The edit records a fresh change-log entry; the plane's listener derives
        // its path and touches the indexer synchronously (the flush is debounced).
        module.controller.setContent(
          'D00/D00-OVR',
          'kubernetes operator needle',
        );

        expect(module.memoryPlane.indexer.hasPending, isTrue);
        expect(
          module.memoryPlane.indexer.pendingPaths,
          contains('D00/D00-OVR'),
        );
      },
    );

    test(
      'flushing the indexer re-indexes the changed section into tier 1',
      () async {
        module.controller.setContent('D00/D00-OVR', 'original baseline text');
        await module.memoryPlane.ensureWarm();
        // Baseline term is findable before the edit.
        final before = await module.memoryPlane.tools.recallQuery('baseline');
        expect(before.hits.map((h) => h.path), contains('D00/D00-OVR'));

        module.controller.setContent(
          'D00/D00-OVR',
          'kubernetes operator needle',
        );
        // Drain the debounced refresh deterministically.
        await module.memoryPlane.indexer.flush();

        // The new term is now findable, and the stale one is gone from tier 1.
        final hit = await module.memoryPlane.tools.recallQuery('kubernetes');
        expect(hit.hits.map((h) => h.path), contains('D00/D00-OVR'));
        final stale = await module.memoryPlane.tools.recallQuery('baseline');
        expect(stale.hits.map((h) => h.path), isNot(contains('D00/D00-OVR')));
        expect(module.memoryPlane.indexer.hasPending, isFalse);
      },
    );

    test(
      'an untouched section keeps its postings after a neighbour edit',
      () async {
        module.controller.setContent('D00/D00-OVR', 'overview baseline text');
        module.controller.setContent('D00/D00-SUM', 'summary anchor token');
        await module.memoryPlane.ensureWarm();

        module.controller.setContent(
          'D00/D00-OVR',
          'kubernetes operator needle',
        );
        await module.memoryPlane.indexer.flush();

        // SUM was never touched, so its original token survives.
        final summary = await module.memoryPlane.tools.recallQuery('anchor');
        expect(summary.hits.map((h) => h.path), contains('D00/D00-SUM'));
      },
    );
  });
}

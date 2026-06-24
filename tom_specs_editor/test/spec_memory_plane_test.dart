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

  test('mem_recall surfaces a tier-1 lexical hit (no vector tier needed)',
      () async {
    module.controller.setContent('D00/D00-OVR', 'a staged rollout needle here');
    await module.memoryPlane.ensureWarm();
    final result = await module.memoryPlane.tools.recallQuery('needle');
    expect(
      result.hits.map((h) => h.path),
      contains('D00/D00-OVR'),
    );
  });

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

  test('mem_refresh reports refreshed matching the vector tier availability',
      () async {
    module.controller.setContent('D00/D00-OVR', 'a staged rollout needle here');
    await module.memoryPlane.ensureWarm();
    final refresh = await module.memoryPlane.tools.refresh();
    expect(refresh.refreshed, module.memoryPlane.available);
  });
}

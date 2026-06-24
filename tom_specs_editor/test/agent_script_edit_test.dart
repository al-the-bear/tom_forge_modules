// Step 18 done-criterion: a D4rt script run through the in-process engine
// scripting surface edits the *live* document, and the change log + undo reflect
// it exactly like a §8 tool edit (§3, §5).
//
// `AgentToolsModule.scriptRunner` binds the engine's `spec` scope to the shared
// `SpecDocumentController` via `EngineSpecController`. Running a script that
// calls `spec.setContent(...)` must therefore mutate the same document the tools
// mutate — one change-log entry, one undoable step — proving the in-process
// integration (no IPC, one change log).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_specs_editor/src/agent/agent_tools_module.dart';
import 'package:tom_specs_editor/src/structure/review_store.dart';
import 'package:tom_specs_editor/src/structure/spec_model.dart';

/// A trivial single-content-field model (mirrors agent_turn_undo_test.dart): the
/// scripting/change-log machinery operates on section-ID paths, so the schema
/// shape is irrelevant.
Map<String, dynamic> _model() => {
      'roots': [
        {'type': 'DemoDoc', 'title': 'Demo', 'sectionId': 'D00'},
      ],
      'classes': {
        'DemoDoc': {
          'name': 'DemoDoc',
          'sectionId': 'D00',
          'fields': [
            {'name': 'overview', 'kind': 'content', 'sectionId': 'D00-OVR'},
          ],
        },
      },
    };

void main() {
  late Directory dir;

  AgentToolsModule makeModule() => AgentToolsModule(
        modelFuture: Future<SpecModel>.value(SpecModel.fromJson(_model())),
        review: ReviewStore(File('${dir.path}/review.yaml')),
        scriptWorkspaceRoot: dir.path,
      );

  setUp(() => dir = Directory.systemTemp.createTempSync('specs_script_edit_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('a D4rt script edits the live document; change log + undo reflect it',
      () async {
    final module = makeModule();
    final c = module.controller;

    final result = await module.scriptRunner.run('''
import 'package:tom_spec_engine/spec_api.dart';

void main() {
  spec.setContent('D00-OVR', 'from script');
}
''');

    // The script ran cleanly...
    expect(result.ok, isTrue, reason: result.error ?? '');
    // ...and its mutation landed on the shared controller.
    expect(c.content('D00-OVR'), 'from script');
    // It is recorded as one change-log entry, exactly like a tool edit (§5).
    expect(c.changeLog.length, 1);

    // And it is on the one undo stack — a single undo reverts the script edit.
    expect(c.canUndo, isTrue);
    await c.undo();
    expect(c.content('D00-OVR'), isNull);
    expect(c.canUndo, isFalse);
  });

  test('a D4rt script reflects the live model through the `model` global',
      () async {
    // Followup item 11: the `spec` scope injects a read-only reflection facade
    // as the `model` global, bound to the live controller's SpecModel. A script
    // can therefore ask meta-model questions over the same model the §8 tools
    // see — and the run resolves it because `run` awaits the model load first.
    final module = makeModule();

    final result = await module.scriptRunner.run('''
import 'package:tom_spec_engine/spec_model_api.dart';

List main() => [
  model.resolves('D00'),
  model.classOf('D00'),
  model.kindOf('D00/D00-OVR'),
  model.sectionId('D00/D00-OVR'),
];
''');

    expect(result.ok, isTrue, reason: result.error ?? '');
    expect(result.result, [true, 'DemoDoc', 'content', 'D00-OVR']);
  });
}

// Tests for the editor's live mode-(b) agent runtime and its MCP wrapping
// (followup item 8): SpecBrainRuntime drives the complex agent procedure through
// the Tom Brain session envelope over the memory plane's store, recording each
// run (with effort metrics) into the document's named memory; SpecBrainTools
// exposes that as the `agent_run` / `agent_trail` MCP tools.
//
// The deterministic path injects a host-independent RecordingBrainEnvelope, so
// the wrapping is exercised without a live vector store (which cannot open under
// `flutter test`). One tolerant test asserts the graceful-degradation contract
// (`available:false`) when no envelope can be resolved.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_spec_engine/agent.dart' show AgentToolGroup;
import 'package:tom_spec_engine/agent_runtime.dart' show RecordingBrainEnvelope;
import 'package:tom_spec_engine/scripting.dart' show SpecFileFacade;
import 'package:tom_vscode_scripting_api/tom_vscode_scripting_api.dart';

import 'package:tom_specs_editor/src/agent/agent_tools_module.dart';
import 'package:tom_specs_editor/src/agent/spec_brain_runtime.dart';
import 'package:tom_specs_editor/src/agent/spec_brain_tools.dart';
import 'package:tom_specs_editor/src/structure/review_store.dart';
import 'package:tom_specs_editor/src/structure/spec_model.dart';

/// A class graph with a list of complex items — enough for the default
/// search→recall→edit→verify procedure's constrained add.
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
        {
          'name': 'items',
          'kind': 'list',
          'elementType': 'DemoItem',
          'elementIsComplex': true,
          'sectionId': 'D00-ITM',
        },
      ],
    },
    'DemoItem': {
      'name': 'DemoItem',
      'fields': [
        {'name': 'label', 'kind': 'content', 'sectionId': 'D01-LBL'},
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

/// Invokes a tool handler and returns its single decoded JSON payload, asserting
/// the compact-JSON contract the other editor MCP servers also keep.
Future<Map<String, dynamic>> _invoke(
  SdkMcpTool tool,
  Map<String, dynamic> args,
) async {
  final result = await tool.handler!(args);
  expect(result.content, hasLength(1));
  final item = result.content.single;
  expect(item['type'], 'text');
  final text = item['text'] as String;
  expect(text.contains('\n'), isFalse, reason: 'must be compact JSON');
  return jsonDecode(text) as Map<String, dynamic>;
}

void main() {
  late Directory dir;
  late AgentToolsModule module;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('specs_brain_runtime_');
    module = _module(dir);
  });
  tearDown(() async {
    await module.memoryPlane.dispose();
    dir.deleteSync(recursive: true);
  });

  /// A runtime over the module's live controller + memory plane, but with a
  /// host-independent recording envelope injected so the run trail records
  /// without a live store (the store cannot open under `flutter test`).
  ({SpecBrainRuntime runtime, RecordingBrainEnvelope envelope})
  recordingRuntime() {
    final envelope = RecordingBrainEnvelope();
    final runtime = SpecBrainRuntime(
      controller: module.controller,
      memoryPlane: module.memoryPlane,
      facade: SpecFileFacade(workspaceRoot: dir.path),
      envelope: envelope,
    );
    return (runtime: runtime, envelope: envelope);
  }

  test('the module exposes the tomspecs-brain server with the run tools', () {
    final server = module.servers['tomspecs-brain'] as McpSdkServerConfig;
    expect(
      {for (final t in server.tools) t.name},
      {'agent_run', 'agent_trail'},
    );
    // The coarse server touches every plane a run uses, so it carries the full
    // tool-group set.
    expect(module.serverToolGroups['tomspecs-brain'], {
      AgentToolGroup.doc,
      AgentToolGroup.file,
      AgentToolGroup.script,
      AgentToolGroup.memory,
    });
  });

  test(
    'an injected envelope makes the runtime available and records the run',
    () async {
      final h = recordingRuntime();
      expect(h.runtime.available, isTrue);

      final result = await h.runtime.run(
        goal: 'append a demo item',
        inputs: const {'parentPath': 'D00', 'childSegment': 'D00-ITM'},
      );

      expect(result['available'], isTrue);
      expect(result['mode'], 'tom_brain');
      expect(result['trailLength'], 1);
      expect(
        (result['result'] as Map)['ok'],
        isTrue,
        reason: (result['result'] as Map)['error']?.toString(),
      );
      // The agent's edit landed on the one shared document (one change log).
      expect(module.controller.document.listItems('D00/D00-ITM'), [
        'D00/D00-ITM-1',
      ]);
      expect(module.controller.changeLog.length, 1);

      // The recorded run carries its effort metrics.
      expect(h.envelope.runs, hasLength(1));
      expect(h.envelope.runs.single.effort.ok, isTrue);
      expect(result['effort'], isNotNull);

      // The trail reads back the run polymorphically (newest last).
      final trail = h.runtime.trail();
      expect(trail, hasLength(1));
      expect(trail.single['goal'], 'append a demo item');
      expect(trail.single['effort'], isNotNull);
    },
  );

  test('agent_run / agent_trail MCP tools wrap the runtime', () async {
    final h = recordingRuntime();
    final server = SpecBrainTools(h.runtime).buildServer();
    expect(server.name, 'tomspecs-brain');
    final tools = {for (final t in server.tools) t.name: t};

    final run = await _invoke(tools['agent_run']!, {
      'goal': 'append a demo item',
      'inputs': {'parentPath': 'D00', 'childSegment': 'D00-ITM'},
    });
    expect(run['available'], isTrue);
    expect(run['mode'], 'tom_brain');
    expect(run['trailLength'], 1);

    final trail = await _invoke(tools['agent_trail']!, {});
    final runs = (trail['runs'] as List).cast<Map>();
    expect(runs, hasLength(1));
    expect(runs.single['goal'], 'append a demo item');
    expect(runs.single['effort'], isNotNull);
  });

  test('agent_run rejects a missing goal as a coded error', () async {
    final h = recordingRuntime();
    final tools = {
      for (final t in SpecBrainTools(h.runtime).buildServer().tools) t.name: t,
    };
    final result = await tools['agent_run']!.handler!({'goal': ''});
    expect(result.isError, isTrue);
  });

  test(
    'the runtime degrades gracefully when no live envelope resolves',
    () async {
      // The module's own runtime has no injected envelope; under `flutter test`
      // the tier-2 store cannot open, so the live envelope is unresolvable and a
      // run reports unavailable rather than running a loop it cannot persist.
      final result = await module.brainRuntime.run(
        goal: 'append a demo item',
        inputs: const {'parentPath': 'D00', 'childSegment': 'D00-ITM'},
      );
      if (module.brainRuntime.available) {
        expect(result['available'], isTrue);
      } else {
        expect(result['available'], isFalse);
        expect(result['reason'], isNotNull);
        // Nothing was recorded and the document was left untouched.
        expect(module.brainRuntime.trail(), isEmpty);
      }
    },
  );
}

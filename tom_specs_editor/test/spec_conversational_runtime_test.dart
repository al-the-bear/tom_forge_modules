// Tests for the editor's live mode-(a) conversational runtime and its MCP
// wrapping (followup item 9): SpecConversationalRuntime drives the complex
// agent procedure across multiple turns chosen by an injected
// ConversationalDriver, recalling the RAG memory before each turn; every edit
// lands on the one shared controller. SpecConversationalTools exposes that as
// the `converse_run` / `converse_trail` MCP tools.
//
// The deterministic path injects a host-independent RecordingConversationalDriver
// (a scripted decision list), so the multi-turn wrapping is exercised without a
// live bridge/LLM. One tolerant test asserts the graceful-degradation contract
// (`available:false`) when no driver is bound (the module's own runtime).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_spec_engine/agent.dart' show AgentToolGroup;
import 'package:tom_spec_engine/agent_runtime.dart'
    show ConversationalDecision, RecordingConversationalDriver;
import 'package:tom_spec_engine/scripting.dart' show SpecFileFacade;
import 'package:tom_vscode_scripting_api/tom_vscode_scripting_api.dart';

import 'package:tom_specs_editor/src/agent/agent_tools_module.dart';
import 'package:tom_specs_editor/src/agent/spec_conversational_runtime.dart';
import 'package:tom_specs_editor/src/agent/spec_conversational_tools.dart';
import 'package:tom_specs_editor/src/structure/spec_model.dart';
import 'support/review_store_support.dart';

/// A class graph with a list of complex items — enough for the multi-turn add.
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
  final review = memoryReviewStore();
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
    dir = Directory.systemTemp.createTempSync('specs_converse_runtime_');
    module = _module(dir);
  });
  tearDown(() async {
    await module.memoryPlane.dispose();
    dir.deleteSync(recursive: true);
  });

  /// A runtime over the module's shared controller + memory plane, with a
  /// host-independent recording driver that scripts two add-turns then stops.
  SpecConversationalRuntime recordingRuntime() => SpecConversationalRuntime(
    controller: module.controller,
    memoryPlane: module.memoryPlane,
    facade: SpecFileFacade(workspaceRoot: dir.path),
    driver: RecordingConversationalDriver(const [
      ConversationalDecision.run(
        inputs: {'parentPath': 'D00', 'childSegment': 'D00-ITM'},
      ),
      ConversationalDecision.run(
        inputs: {'parentPath': 'D00', 'childSegment': 'D00-ITM'},
      ),
      ConversationalDecision.stop(reason: 'done'),
    ]),
  );

  test(
    'the module exposes the tomspecs-converse server with the converse tools',
    () {
      final server = module.servers['tomspecs-converse'] as McpSdkServerConfig;
      expect(
        {for (final t in server.tools) t.name},
        {'converse_run', 'converse_trail'},
      );
      // A conversational run touches every plane, so the coarse server carries the
      // full tool-group set.
      expect(module.serverToolGroups['tomspecs-converse'], {
        AgentToolGroup.doc,
        AgentToolGroup.file,
        AgentToolGroup.script,
        AgentToolGroup.memory,
      });
    },
  );

  test('an injected driver makes the runtime available and drives a multi-turn '
      'run', () async {
    final runtime = recordingRuntime();
    expect(runtime.available, isTrue);

    final result = await runtime.run(goal: 'append demo items');

    expect(result['available'], isTrue);
    expect(result['mode'], 'conversational');
    expect(result['baseMode'], 'direct');
    expect(result['turnCount'], 2);
    expect(
      (result['result'] as Map)['ok'],
      isTrue,
      reason: (result['result'] as Map)['error']?.toString(),
    );

    // Two turns added two list items on the one shared document.
    expect(module.controller.document.listItems('D00/D00-ITM'), [
      'D00/D00-ITM-1',
      'D00/D00-ITM-2',
    ]);
    expect(module.controller.changeLog.length, 2);

    // The per-turn trail reads back, oldest first.
    final trail = runtime.trail();
    expect(trail, hasLength(2));
    expect(trail.first['index'], 0);
    expect(trail.last['index'], 1);
  });

  test('converse_run / converse_trail MCP tools wrap the runtime', () async {
    final runtime = recordingRuntime();
    final server = SpecConversationalTools(runtime).buildServer();
    expect(server.name, 'tomspecs-converse');
    final tools = {for (final t in server.tools) t.name: t};

    final run = await _invoke(tools['converse_run']!, {
      'goal': 'append demo items',
    });
    expect(run['available'], isTrue);
    expect(run['mode'], 'conversational');
    expect(run['turnCount'], 2);

    final trail = await _invoke(tools['converse_trail']!, {});
    final turns = (trail['turns'] as List).cast<Map>();
    expect(turns, hasLength(2));
    expect(turns.first['goal'], 'append demo items');
  });

  test('converse_run rejects a missing goal as a coded error', () async {
    final runtime = recordingRuntime();
    final tools = {
      for (final t in SpecConversationalTools(runtime).buildServer().tools)
        t.name: t,
    };
    final result = await tools['converse_run']!.handler!({'goal': ''});
    expect(result.isError, isTrue);
  });

  test('the runtime degrades gracefully when no driver is bound', () async {
    // The module's own conversational runtime has no driver bound (the live
    // driver is late-bound by the app once the chat send controller exists), so
    // a run reports unavailable rather than looping with no decision-maker.
    expect(module.conversationalRuntime.available, isFalse);
    final result = await module.conversationalRuntime.run(
      goal: 'append demo items',
    );
    expect(result['available'], isFalse);
    expect(result['reason'], isNotNull);
    // Nothing was recorded and the document was left untouched.
    expect(module.conversationalRuntime.trail(), isEmpty);
    expect(module.controller.changeLog.length, 0);
  });

  test('bindConversationalDriver late-binds the live decision-maker', () async {
    // The module starts degraded; binding a (recording) driver makes the
    // module's own runtime available — the seam the app uses for the live driver.
    expect(module.conversationalRuntime.available, isFalse);
    module.bindConversationalDriver(
      RecordingConversationalDriver(const [
        ConversationalDecision.run(
          inputs: {'parentPath': 'D00', 'childSegment': 'D00-ITM'},
        ),
        ConversationalDecision.stop(),
      ]),
    );
    expect(module.conversationalRuntime.available, isTrue);

    final result = await module.conversationalRuntime.run(
      goal: 'append demo items',
    );
    expect(result['available'], isTrue);
    expect(result['turnCount'], 1);
    expect(module.controller.document.listItems('D00/D00-ITM'), [
      'D00/D00-ITM-1',
    ]);
  });
}

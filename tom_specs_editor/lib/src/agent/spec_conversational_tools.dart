import 'dart:convert';

import 'package:tom_vscode_scripting_api/tom_vscode_scripting_api.dart';

import 'spec_conversational_runtime.dart';

/// The **MCP wrapping** of the live mode-(a) conversational runtime (followup
/// item 9).
///
/// Exposes the editor's [SpecConversationalRuntime] as two in-process MCP tools,
/// mirroring [SpecBrainTools]' result discipline (compact JSON, `isError` +
/// `{"error": …}` on failure):
///
///   * `converse_run` — run the multi-turn conversational loop for a goal: each
///     turn recalls the RAG memory, the live conversational driver decides the
///     turn, and the complex procedure runs through the base substrate, every
///     edit landing in the one change log. Reports `available:false` when no
///     conversational driver is bound (no live bridge to decide turns);
///   * `converse_trail` — read back the per-turn trail of the last run (each
///     turn's goal, inputs, result, and the recalled paths that informed it).
///
/// Coarse-grained, like the other editor servers: a conversational run touches
/// doc + memory + file + script, so the server carries the full tool-group set.
class SpecConversationalTools {
  /// Binds the tools to the live [runtime].
  SpecConversationalTools(this.runtime);

  /// The live mode-(a) conversational runtime the tools drive.
  final SpecConversationalRuntime runtime;

  /// Assembles the `McpSdkServerConfig` registered alongside the editor's other
  /// servers into `Options.mcpServers`.
  McpSdkServerConfig buildServer({String name = 'tomspecs-converse'}) =>
      McpSdkServerConfig(name: name, tools: [_converseRun(), _converseTrail()]);

  CallToolResult _ok(Object? payload) =>
      CallToolResult.text(jsonEncode(payload));

  CallToolResult _err(String message) =>
      CallToolResult.text(jsonEncode({'error': message}), isError: true);

  SdkMcpTool _converseRun() => SdkMcpTool(
    name: 'converse_run',
    description:
        'Run the multi-turn conversational loop (llm_and_d4rt_tools.md §10 '
        'mode a) for a goal: '
        'each turn recalls the RAG memory, the live conversational driver '
        'decides the turn, and the complex procedure runs through the base '
        'substrate. Edits land in the one change log. Reports '
        'available:false when no conversational driver is bound.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'goal': {'type': 'string', 'description': 'The conversation goal.'},
        'inputs': {
          'type': 'object',
          'description':
              'Optional task seed inputs; the driver chooses each turn\'s '
              'concrete inputs.',
        },
      },
      'required': ['goal'],
    },
    handler: (args) async {
      final goal = args['goal']?.toString();
      if (goal == null || goal.isEmpty) return _err('Missing "goal".');
      final rawInputs = args['inputs'];
      final inputs = rawInputs is Map
          ? rawInputs.map((k, v) => MapEntry(k.toString(), v))
          : const <String, Object?>{};
      try {
        return _ok(await runtime.run(goal: goal, inputs: inputs));
      } catch (e) {
        return _err('conversational run failed: $e');
      }
    },
  );

  SdkMcpTool _converseTrail() => SdkMcpTool(
    name: 'converse_trail',
    description:
        'The per-turn trail of the last conversational run — each turn\'s '
        'goal, inputs, result, and the recalled paths that informed it, '
        'oldest first. Empty before the first run or while degraded.',
    inputSchema: const {'type': 'object', 'properties': {}},
    handler: (args) async => _ok({'turns': runtime.trail()}),
  );
}

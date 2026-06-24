import 'dart:convert';

import 'package:tom_vscode_scripting_api/tom_vscode_scripting_api.dart';

import 'spec_brain_runtime.dart';

/// The **MCP wrapping** of the live mode-(b) agent runtime (followup item 8).
///
/// Exposes the editor's [SpecBrainRuntime] as two in-process MCP tools the Agent
/// SDK can call mid-turn, mirroring [SpecEngineTools]' result discipline (compact
/// JSON, `isError` + `{"error": …}` on failure):
///
///   * `agent_run` — drive the complex agent procedure for a goal through the
///     live Tom Brain session envelope, recording the run (with its effort
///     metrics) into the document's named memory. Reports `available:false` when
///     the store is degraded (no live trail to record into);
///   * `agent_trail` — read back the recorded run trail (per-run effort
///     metrics), newest last.
///
/// Coarse-grained, like the other editor servers: this server's tool group is
/// the full set (a run touches doc + memory + file + script). Per-tool gating
/// stays deferred; the engine's **toolset ⊆ scopes** invariant is the real
/// capability guarantee.
class SpecBrainTools {
  /// Binds the tools to the live [runtime].
  SpecBrainTools(this.runtime);

  /// The live mode-(b) runtime the tools drive.
  final SpecBrainRuntime runtime;

  /// Assembles the `McpSdkServerConfig` registered alongside the editor's other
  /// servers into `Options.mcpServers`.
  McpSdkServerConfig buildServer({String name = 'tomspecs-brain'}) =>
      McpSdkServerConfig(
        name: name,
        tools: [_agentRun(), _agentTrail()],
      );

  CallToolResult _ok(Object? payload) =>
      CallToolResult.text(jsonEncode(payload));

  CallToolResult _err(String message) =>
      CallToolResult.text(jsonEncode({'error': message}), isError: true);

  SdkMcpTool _agentRun() => SdkMcpTool(
        name: 'agent_run',
        description:
            'Drive the complex agent procedure (search → recall → edit → '
            'verify) for a goal through the live Tom Brain session envelope, '
            'recording the run (with effort metrics) into the document\'s named '
            'memory. Edits land in the one change log. Reports available:false '
            'when the memory store is degraded.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'goal': {'type': 'string', 'description': 'The run goal.'},
            'inputs': {
              'type': 'object',
              'description':
                  'Structured task inputs (e.g. parentPath / childSegment for '
                  'the default add procedure).',
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
            return _err('agent run failed: $e');
          }
        },
      );

  SdkMcpTool _agentTrail() => SdkMcpTool(
        name: 'agent_trail',
        description:
            'The recorded run trail for this session — each run\'s document, '
            'goal, and effort metrics (wall-clock, transcript size, outcome), '
            'newest last. Empty before the first run or while degraded.',
        inputSchema: const {'type': 'object', 'properties': {}},
        handler: (args) async => _ok({'runs': runtime.trail()}),
      );
}

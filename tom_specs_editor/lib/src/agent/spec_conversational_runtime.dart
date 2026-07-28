import 'package:tom_som_dart_runtime/tom_som_dart_runtime.dart'
    show SpecQueryEngine;
import 'package:tom_spec_engine/agent_runtime.dart';
import 'package:tom_spec_engine/scripting.dart'
    show DocTools, FileTools, SpecFileFacade;

import '../document/spec_document_controller.dart';
import 'engine_spec_controller.dart';
import 'spec_memory_plane.dart';

/// The editor's **live mode-(a) conversational runtime** (followup item 9,
/// `llm_and_d4rt_tools.md` §10).
///
/// Where [SpecBrainRuntime] binds `llm_and_d4rt_tools.md` §10 mode (b) (the Tom
/// Brain session envelope), this binds `llm_and_d4rt_tools.md` §10 **mode
/// (a)**: the *conversational* substrate driven across **multiple turns**. It
/// wraps a [DirectAgentSubstrate] (the headless complex procedure over the live
/// tools) in a [ConversationalAgentSubstrate], so each turn it recalls the RAG
/// memory for the goal, lets the injected [ConversationalDriver] decide the
/// next turn, and runs the procedure for that turn — every edit landing on the
/// shared [SpecDocumentController] (the one change log, `llm_and_d4rt_tools.md`
/// §5).
///
/// The conversational substrate is the live Agent SDK / LLM; the pure-Dart
/// engine cannot host it, so the runtime takes a [ConversationalDriver] port. In
/// production that is the [SendControllerConversationalDriver] over the editor's
/// live `AgentSendController`; a test injects a [RecordingConversationalDriver].
///
/// **Graceful degradation.** Unlike mode (b), mode (a) needs *no* live store —
/// but it does need a live conversational substrate. With no [ConversationalDriver]
/// bound (no live bridge/LLM) [run] reports `{available: false, reason}` rather
/// than running a loop that has no decision-maker.
class SpecConversationalRuntime {
  /// Binds the runtime to the shared [controller], the [memoryPlane] whose
  /// recall augments each turn, the audited [facade] for the agent's `file_*`
  /// surface, and the conversational [driver] (the live decision-maker; `null`
  /// degrades).
  SpecConversationalRuntime({
    required this.controller,
    required this.memoryPlane,
    required SpecFileFacade facade,
    ConversationalDriver? driver,
    int maxTurns = 8,
  })  : _facade = facade,
        _driver = driver,
        _maxTurns = maxTurns;

  /// The live document controller the agent's edits land on (one change log).
  final SpecDocumentController controller;

  /// The embeddable memory plane whose recall augments each conversational turn.
  final SpecMemoryPlane memoryPlane;

  final SpecFileFacade _facade;
  ConversationalDriver? _driver;
  final int _maxTurns;

  /// The turns of the most recent [run], oldest first.
  List<ConversationalTurn> _lastTurns = const <ConversationalTurn>[];

  /// Whether a conversational driver is bound — the live decision-maker mode (a)
  /// needs. `false` degrades [run] to a no-op.
  bool get available => _driver != null;

  /// Late-binds the live conversational [driver].
  ///
  /// The live driver wraps the editor's `AgentSendController`, which is built
  /// *after* this module (its send config folds in the module's MCP servers), so
  /// the live decision-maker cannot be passed at construction without a cycle.
  /// The app binds it here once the chat send controller exists; tests inject the
  /// driver at construction instead.
  void bindDriver(ConversationalDriver driver) => _driver = driver;

  /// Runs the multi-turn conversational loop for [goal] (the optional [inputs]
  /// seed the task; the driver chooses each turn's concrete inputs). Returns a
  /// JSON-able result: `{available, mode, baseMode, result, turnCount, turns}`,
  /// or `{available:false, reason}` when no driver is bound.
  Future<Map<String, Object?>> run({
    required String goal,
    Map<String, Object?> inputs = const <String, Object?>{},
  }) async {
    final driver = _driver;
    if (driver == null) {
      return <String, Object?>{
        'available': false,
        'reason': 'no conversational driver bound — no live Agent SDK / bridge '
            'to decide the turns (mode a needs the conversational substrate)',
      };
    }

    await controller.ensureLoaded();
    // Warm the plane so each turn's recall sees the indexed sections.
    await memoryPlane.ensureWarm();

    final tools = _buildTools();
    final substrate = ConversationalAgentSubstrate(
      base: DirectAgentSubstrate(tools: tools),
      tools: tools,
      driver: driver,
      maxTurns: _maxTurns,
    );
    final result = await substrate.run(AgentTask(goal: goal, inputs: inputs));
    _lastTurns = substrate.turns;

    return <String, Object?>{
      'available': true,
      'mode': substrate.mode,
      'baseMode': substrate.baseMode,
      'result': result.toJson(),
      'turnCount': _lastTurns.length,
      'turns': [for (final turn in _lastTurns) turn.toJson()],
    };
  }

  /// The turns of the most recent run as JSON-able rows, oldest first. Empty
  /// before the first run or while degraded.
  List<Map<String, Object?>> trail() =>
      [for (final turn in _lastTurns) turn.toJson()];

  /// Builds the unified agent tool surface over the live document, the shared
  /// memory tools, and the audited file facade.
  AgentToolsApi _buildTools() {
    final docTools = DocTools(
      engine: SpecQueryEngine(
        model: controller.model,
        document: controller.document,
      ),
      controller: EngineSpecController(controller),
    );
    return AgentToolsApi(
      doc: docTools,
      memory: memoryPlane.tools,
      files: FileTools(_facade),
    );
  }
}

import 'package:tom_som_dart_runtime/tom_som_dart_runtime.dart'
    show SpecQueryEngine;
import 'package:tom_spec_engine/agent_runtime.dart';
import 'package:tom_spec_engine/memory.dart' show MemoryScope;
import 'package:tom_spec_engine/scripting.dart'
    show DocTools, FileTools, SpecFileFacade;

import '../document/spec_document_controller.dart';
import 'engine_spec_controller.dart';
import 'spec_memory_plane.dart';

/// The editor's **live mode-(b) agent runtime** (followup item 8,
/// `llm_and_d4rt_tools.md` §10).
///
/// Where [SpecMemoryPlane] makes the `llm_and_d4rt_tools.md` §9 *recall* live
/// in the editor, this binds the `llm_and_d4rt_tools.md` §10 *run* surface: it
/// drives the complex agent procedure through a [BrainAgentSubstrate] whose Tom
/// Brain session envelope is the live [SpecBrainSessionEnvelope] over the
/// plane's in-process store — so each run is recorded as a node (with its
/// [RunEffort]) in the *same* document-named memory the section index uses
/// ([SpecMemoryPlane.scope]). The agent's edits land on the shared
/// [SpecDocumentController], so they join the one change log exactly as a
/// tool/script edit does (`llm_and_d4rt_tools.md` §5).
///
/// **Graceful degradation.** The live envelope needs the tier-2 store; when the
/// plane is degraded ([SpecMemoryPlane.available] is `false`, e.g. no `vec0`
/// binary or a runtime that cannot open the store) there is no place to record
/// the run trail, so [run] reports `{available: false}` rather than running a
/// mode-(b) loop it cannot persist. A test may inject its own [envelope] to
/// exercise the wrapping without a live store.
class SpecBrainRuntime {
  /// Binds the runtime to the shared [controller], the [memoryPlane] whose store
  /// (and [SpecMemoryPlane.scope]) the run trail records under, and the audited
  /// [facade] the agent's `file_*` surface reads/writes through.
  ///
  /// [scope] overrides the recording scope (defaults to the plane's). [envelope]
  /// injects a session envelope (for tests); production resolves the live
  /// [SpecBrainSessionEnvelope] from the plane's store.
  SpecBrainRuntime({
    required this.controller,
    required this.memoryPlane,
    required SpecFileFacade facade,
    MemoryScope? scope,
    BrainSessionEnvelope? envelope,
  }) : _facade = facade,
       _scope = scope ?? memoryPlane.scope,
       _injectedEnvelope = envelope;

  /// The live document controller the agent edits land on (one change log).
  final SpecDocumentController controller;

  /// The embeddable memory plane whose store the run trail records under.
  final SpecMemoryPlane memoryPlane;

  final SpecFileFacade _facade;
  final MemoryScope _scope;
  final BrainSessionEnvelope? _injectedEnvelope;

  /// Lazily resolved live envelope (cached so the trail accumulates across runs).
  SpecBrainSessionEnvelope? _liveEnvelope;

  /// The Tom Brain addressing each run records under.
  MemoryScope get scope => _scope;

  /// Whether a session envelope can be resolved — an injected one, or the live
  /// store once it is available. Warm the plane first for an accurate read.
  bool get available => _resolveEnvelope() != null;

  /// Runs the agent procedure for [goal] (+ structured [inputs]) through the
  /// live mode-(b) substrate, recording the run into the document's named
  /// memory. Returns a JSON-able result: `{available, mode, result, effort,
  /// trailLength}`, or `{available:false, reason}` when the store is degraded.
  Future<Map<String, Object?>> run({
    required String goal,
    Map<String, Object?> inputs = const <String, Object?>{},
  }) async {
    await controller.ensureLoaded();
    // Warm the plane so the agent's recall sees the indexed sections and the
    // store is open before the envelope records into it.
    await memoryPlane.ensureWarm();

    final envelope = _resolveEnvelope();
    if (envelope == null) {
      return <String, Object?>{
        'available': false,
        'reason':
            'memory plane unavailable — no live store to record the '
            'run trail (tier-2 degraded)',
      };
    }

    final substrate = buildAgentSubstrate(
      mode: AgentSubstrateMode.tomBrain,
      tools: _buildTools(),
      envelope: envelope,
      scope: _scope,
    );
    final result = await substrate.run(AgentTask(goal: goal, inputs: inputs));

    final runs = envelope.recordedRuns;
    return <String, Object?>{
      'available': true,
      'mode': substrate.mode,
      'result': result.toJson(),
      if (runs.isNotEmpty) 'effort': runs.last.effort.toJson(),
      'trailLength': runs.length,
    };
  }

  /// The recorded run trail as JSON-able rows (`document`, `goal`, `effort`),
  /// newest last. Empty before the first run or while degraded.
  List<Map<String, Object?>> trail() {
    final envelope = _resolveEnvelope();
    if (envelope == null) return const <Map<String, Object?>>[];
    return [
      for (final record in envelope.recordedRuns)
        <String, Object?>{
          'document': record.scope.document,
          'goal': record.task.goal,
          'effort': record.effort.toJson(),
        },
    ];
  }

  /// Resolves the session envelope: the injected one, else the live store-backed
  /// envelope once the plane is available. `null` while degraded.
  BrainSessionEnvelope? _resolveEnvelope() {
    if (_injectedEnvelope != null) return _injectedEnvelope;
    final store = memoryPlane.memory;
    if (store == null || !memoryPlane.available) return null;
    return _liveEnvelope ??= SpecBrainSessionEnvelope(store);
  }

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

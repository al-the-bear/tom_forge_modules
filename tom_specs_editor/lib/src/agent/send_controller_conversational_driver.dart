import 'dart:convert';

import 'package:tom_forge_agentic/tom_forge_agentic.dart';
import 'package:tom_spec_engine/agent_runtime.dart'
    show ConversationContext, ConversationalDecision, ConversationalDriver;

/// The **live conversational substrate** driver (followup item 9, §10 mode a).
///
/// Binds the engine's [ConversationalDriver] port to the editor's live
/// [AgentSendController] — the Agent SDK / Claude Code loop over the VS Code
/// bridge. Each turn it renders the running [ConversationContext] (the goal, the
/// per-turn RAG recall, and the prior turns) into a prompt that asks the model
/// to reply with a single JSON **decision** object, streams it through the
/// controller, and parses the reply back into a [ConversationalDecision].
///
/// The model is asked to answer with exactly:
/// `{"stop": bool, "reason"?: str, "goal"?: str, "inputs"?: { … }}` — `stop`
/// ends the conversation; otherwise `inputs` (e.g. `parentPath` / `childSegment`)
/// drives one run of the complex procedure. A reply with no parseable decision
/// is treated as a **stop** (the safe default — never invent an edit), so a
/// confused turn ends the conversation rather than looping.
///
/// This is the genuinely live path: it needs a bound bridge, so it cannot run
/// under `flutter test` (the headless multi-turn loop is covered by injecting a
/// `RecordingConversationalDriver`). The exact prompt wording here is a
/// deliberately small, tunable contract — the protocol, not the phrasing, is what
/// matters.
class SendControllerConversationalDriver implements ConversationalDriver {
  /// Binds the driver to the live [controller].
  SendControllerConversationalDriver(this.controller);

  /// The live send controller each turn streams its decision prompt through.
  final AgentSendController controller;

  @override
  Future<ConversationalDecision> nextTurn(ConversationContext context) async {
    await controller.send(_promptFor(context));
    if (controller.error != null) {
      return ConversationalDecision.stop(
        reason: 'driver send failed: ${controller.error}',
      );
    }
    return _parseDecision(controller.output);
  }

  /// Renders the running context into the decision prompt.
  String _promptFor(ConversationContext context) {
    final prior = [
      for (final turn in context.priorTurns)
        '  - turn ${turn.index}: ${jsonEncode(turn.task.inputs)} '
            '→ ${turn.result.ok ? 'ok' : 'failed'}',
    ].join('\n');
    return [
      'You are the TomSpecs conversational editor agent deciding the next edit '
          'turn.',
      'Goal: ${context.goal}',
      'Turn index: ${context.turnIndex}',
      if (context.recalledPaths.isNotEmpty)
        'Recalled sections: ${context.recalledPaths.join(', ')}',
      if (prior.isNotEmpty) 'Prior turns:\n$prior',
      'Reply with ONE JSON object and nothing else: '
          '{"stop": <bool>, "reason"?: <string>, "goal"?: <string>, '
          '"inputs"?: {"parentPath": <string>, "childSegment"?: <string>}}. '
          'Set "stop": true when the goal is satisfied.',
    ].join('\n');
  }

  /// Parses the model's reply into a decision; an unparseable reply stops.
  ConversationalDecision _parseDecision(String reply) {
    final json = _firstJsonObject(reply);
    if (json == null) {
      return const ConversationalDecision.stop(
        reason: 'no JSON decision in the driver reply',
      );
    }
    if (json['stop'] == true) {
      return ConversationalDecision.stop(reason: json['reason']?.toString());
    }
    final rawInputs = json['inputs'];
    final inputs = rawInputs is Map
        ? rawInputs.map((k, v) => MapEntry(k.toString(), v))
        : const <String, Object?>{};
    return ConversationalDecision.run(
      inputs: inputs,
      goal: json['goal']?.toString(),
    );
  }

  /// Extracts and decodes the first balanced `{ … }` JSON object in [text], or
  /// `null` when none parses (the model may wrap the object in prose).
  Map<String, Object?>? _firstJsonObject(String text) {
    final start = text.indexOf('{');
    if (start < 0) return null;
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < text.length; i++) {
      final ch = text[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == r'\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
      } else if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) {
          final slice = text.substring(start, i + 1);
          try {
            final decoded = jsonDecode(slice);
            if (decoded is Map) {
              return decoded.map((k, v) => MapEntry(k.toString(), v));
            }
          } catch (_) {
            return null;
          }
          return null;
        }
      }
    }
    return null;
  }
}

import '../send/agent_send_controller.dart';
import '../trail/prompt_trail_controller.dart';

/// Sends a prompt through the bridge and records the exchange in the trail.
///
/// The composer's "Send now" (§11.1) and the queue's send-next (§11.2) both
/// need the same two-step behaviour: open a trail pair for the request, stream
/// the answer through the [AgentSendController], then close the pair with the
/// streamed answer (or the failure). Factoring it here keeps that single
/// responsibility in one place rather than duplicated across the composer and
/// the queue controller.
///
/// Stateless: it holds no mutable state of its own — the send state lives on
/// [send] and the pairs on [trail].
class ChatSendCoordinator {
  ChatSendCoordinator({
    required this.send,
    required this.trail,
    String Function(String raw)? compose,
  }) : _compose = compose ?? _identity;

  /// The transport that streams the answer (§7).
  final AgentSendController send;

  /// The trail the request/answer pair is recorded into (§11.3).
  final PromptTrailController trail;

  /// Expands the raw prompt's placeholders just before send (§11.5). Supplied
  /// by the host (the TomSpecs editor wires its `SpecPromptComposer.compose`);
  /// defaults to identity so a host without a placeholder context sends the
  /// prompt verbatim. A `${{ … }}` expression form makes this throw, which
  /// [sendNow] surfaces as a failed trail pair rather than a crash.
  final String Function(String raw) _compose;

  static String _identity(String raw) => raw;

  /// Composes [prompt] (placeholder expansion, §11.5), streams the result
  /// through the bound bridge, and records the request/answer pair. Resolves
  /// after the turn completes; the trail pair reflects the final streamed
  /// answer, or the failure (a send error, or a placeholder-resolution error
  /// such as the disabled `${{ … }}` form).
  Future<void> sendNow(String prompt) async {
    final String composed;
    try {
      composed = _compose(prompt);
    } catch (error) {
      // A placeholder-resolution failure (e.g. the disabled `${{ … }}` form):
      // record the raw prompt with the error instead of sending anything.
      final pairId = trail.recordRequest(prompt);
      trail.failAnswer(pairId, '$error');
      return;
    }

    final pairId = trail.recordRequest(composed);
    await send.send(composed);
    final error = send.error;
    if (error != null) {
      trail.failAnswer(pairId, '$error');
    } else {
      trail.completeAnswer(pairId, send.output);
    }
  }
}

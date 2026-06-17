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
  ChatSendCoordinator({required this.send, required this.trail});

  /// The transport that streams the answer (§7).
  final AgentSendController send;

  /// The trail the request/answer pair is recorded into (§11.3).
  final PromptTrailController trail;

  /// Streams [prompt] through the bound bridge and records the request/answer
  /// pair. Resolves after the turn completes; the trail pair reflects the final
  /// streamed answer, or the send error when one occurred.
  Future<void> sendNow(String prompt) async {
    final pairId = trail.recordRequest(prompt);
    await send.send(prompt);
    final error = send.error;
    if (error != null) {
      trail.failAnswer(pairId, '$error');
    } else {
      trail.completeAnswer(pairId, send.output);
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:tom_core_agentic/tom_core_agentic.dart';

import '../connection/agent_connection_controller.dart';

/// Drives a single prompt through the bridge-backed Agent SDK and exposes the
/// streamed answer as observable UI state (§7).
///
/// Thin Flutter wrapper over the pure-Dart [AgentSendEngine]: it resolves the
/// bound bridge from the shared [AgentConnectionController], builds an
/// [AgentSdkClient] for that host/port via the injectable [clientFactory]
/// (defaulting to [connectAgentSdkClient]), then folds the engine's
/// [AgentSendEvent] stream into [output] / [sending] / [error] / [sessionId].
///
/// The factory seam keeps this layer transport-agnostic (N7) and lets tests run
/// the whole pipeline over a fake `AgentSdkTransport` without opening a socket.
class AgentSendController extends ChangeNotifier {
  AgentSendController({
    required this.connection,
    this.config = const AgentSendConfig(),
    SpecSessionStore? sessionStore,
    AgentSdkClientFactory? clientFactory,
  })  : _sessionStore = sessionStore ?? SpecSessionStore.resolveDefault(),
        _clientFactory = clientFactory ?? connectAgentSdkClient;

  /// The shared connection controller; its bound choice supplies the bridge
  /// host/port the send connects to.
  final AgentConnectionController connection;

  /// The assembled `Options` inputs (profile + global settings + MCP tools).
  /// Step 12 sends the editor default; later steps (14/18) populate the profile
  /// and the MCP tool server.
  final AgentSendConfig config;

  final SpecSessionStore _sessionStore;
  final AgentSdkClientFactory _clientFactory;

  final StringBuffer _output = StringBuffer();
  bool _sending = false;
  Object? _error;
  String? _sessionId;
  bool _sessionRefreshed = false;

  /// The accumulated assistant answer text streamed so far.
  String get output => _output.toString();

  /// Whether a send is currently in flight.
  bool get sending => _sending;

  /// The last failure (engine [AgentSendFailed] message, a connect error, or a
  /// "no bridge bound" guard), or `null`.
  Object? get error => _error;

  /// The Claude-Code session id of the last completed turn, or `null`.
  String? get sessionId => _sessionId;

  /// Whether the last send had to refresh a stale session id (§7.2).
  bool get sessionRefreshed => _sessionRefreshed;

  /// Whether a prompt can be sent right now: nothing in flight and a bridge is
  /// bound.
  bool get canSend => !_sending && connection.boundChoice != null;

  /// Streams [prompt] through the bound bridge, accumulating the answer into
  /// [output]. A second call while [sending] is a no-op.
  Future<void> send(String prompt) async {
    if (_sending) return;
    final bound = connection.boundChoice;
    if (bound == null) {
      _error = StateError('No bridge bound — pick a connection first.');
      notifyListeners();
      return;
    }

    _sending = true;
    _error = null;
    _sessionRefreshed = false;
    _output.clear();
    notifyListeners();

    try {
      final client =
          await _clientFactory(host: bound.host, port: bound.port);
      final engine = AgentSendEngine(
        client: client,
        sessionStore: _sessionStore,
        config: config,
      );
      await for (final event in engine.send(prompt)) {
        switch (event) {
          case AgentSendStarted():
            break;
          case AgentSendChunk(:final text):
            _output.write(text);
            notifyListeners();
          case AgentSendSessionRefreshed():
            _sessionRefreshed = true;
            notifyListeners();
          case AgentSendCompleted(:final sessionId):
            _sessionId = sessionId;
          case AgentSendFailed(:final message):
            _error = message;
        }
      }
    } catch (e) {
      // A connect failure (or any unexpected throw) surfaces as the panel error
      // rather than crashing the send.
      _error = e;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:tom_core_agentic/tom_core_agentic.dart';

/// Drives the agent connection picker (§6, Q4, C1).
///
/// Wraps the non-UI [BridgeConnectionService] (port scan + workspace-identify
/// handshake) and [BridgeChoiceStore] (persisted binding) and exposes them as
/// observable UI state: the discovered [servers], whether a [scan] is in
/// flight, any [error], and the currently [bound] server. The bound choice is
/// persisted on [bind] and restored by [loadPersisted], so the picker shows
/// the previously selected server across launches.
class AgentConnectionController extends ChangeNotifier {
  AgentConnectionController({
    BridgeConnectionService? service,
    BridgeChoiceStore? store,
  })  : _service = service ?? BridgeConnectionService(),
        _store = store ?? BridgeChoiceStore.resolveDefault();

  final BridgeConnectionService _service;
  final BridgeChoiceStore _store;

  /// The scan service, exposed so the reconnect protocol (§6.1) can rescan the
  /// bridge range through the same service the picker uses.
  BridgeConnectionService get service => _service;

  List<BridgeServer> _servers = const [];
  bool _scanning = false;
  Object? _error;
  BridgeChoice? _boundChoice;
  String? _boundWorkspace;

  /// The servers found by the last [scan], each tagged `bound` if it matches
  /// the persisted choice.
  List<BridgeServer> get servers => _servers;

  /// Whether a scan is currently running.
  bool get scanning => _scanning;

  /// The error from the last failed scan, or `null`.
  Object? get error => _error;

  /// The persisted binding target (may not be among [servers] if that window
  /// is not currently running).
  BridgeChoice? get boundChoice => _boundChoice;

  /// The workspace name of the bound window, captured at [bind] time so the
  /// reconnect protocol (§6.1 step 5) can tell when the bound port comes back
  /// serving a *different* workspace. `null` when the binding was restored from
  /// persistence (only host+port are stored) and no live [bind] has run since —
  /// the reconnect coordinator then treats any server on the port as the same.
  String? get boundWorkspace => _boundWorkspace;

  /// The discovered server the editor is bound to, or `null` if the bound
  /// window is not currently among [servers].
  BridgeServer? get bound {
    for (final s in _servers) {
      if (s.status == BridgeServerStatus.bound) return s;
    }
    return null;
  }

  /// Whether [server] is the bound one.
  bool isBound(BridgeServer server) =>
      _boundChoice != null &&
      server.port == _boundChoice!.port &&
      server.host == _boundChoice!.host;

  /// Loads the persisted choice without scanning. Safe to call once at
  /// startup before [scan].
  void loadPersisted() {
    _boundChoice = _store.load();
    _retag();
    notifyListeners();
  }

  /// Scans the bridge port range and refreshes [servers].
  ///
  /// A failed scan clears the server list and records [error]; it never
  /// throws to the caller.
  Future<void> scan() async {
    _scanning = true;
    _error = null;
    notifyListeners();
    try {
      _servers = await _service.scan();
      _retag();
    } catch (e) {
      _error = e;
      _servers = const [];
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  /// Binds [server] and persists the choice.
  void bind(BridgeServer server) {
    _boundChoice = BridgeChoice(host: server.host, port: server.port);
    _boundWorkspace = server.workspace;
    _store.save(_boundChoice!);
    _retag();
    notifyListeners();
  }

  /// Clears the binding and removes the persisted choice.
  void unbind() {
    _boundChoice = null;
    _boundWorkspace = null;
    _store.clear();
    _retag();
    notifyListeners();
  }

  /// Recomputes each server's [BridgeServerStatus] from the current binding.
  void _retag() {
    _servers = [
      for (final s in _servers)
        s.copyWith(
          status: isBound(s)
              ? BridgeServerStatus.bound
              : BridgeServerStatus.available,
        ),
    ];
  }
}

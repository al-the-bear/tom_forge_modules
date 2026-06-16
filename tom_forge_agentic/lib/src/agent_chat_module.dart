import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'agent_chat_view.dart';
import 'connection/agent_connection_controller.dart';
import 'send/agent_send_controller.dart';

/// Reusable agent chat module (§4.2, §6).
///
/// Contributed by any agent/chat-enabled Forge tool. It owns the
/// [AgentConnectionController] and exposes the [chatView] for the bottom panel.
/// On [activate] it restores the persisted binding and kicks off a port scan
/// (19900–19909) so the picker is populated as soon as the shell is shown.
///
/// Both controllers are injectable so tests (and hosts that want to share one
/// connection across modules) can supply their own — e.g. a [sendController]
/// built over a fake transport so no socket is opened.
class AgentChatModule extends ForgeModule {
  AgentChatModule({
    AgentConnectionController? controller,
    AgentSendController? sendController,
  }) : controller = controller ?? AgentConnectionController() {
    this.sendController =
        sendController ?? AgentSendController(connection: this.controller);
    _view = AgentChatView(
      controller: this.controller,
      sendController: this.sendController,
    );
    _views = [_view];
  }

  /// The shared connection controller (scan + binding state).
  final AgentConnectionController controller;

  /// The send controller streaming agent answers (§7).
  late final AgentSendController sendController;

  late final AgentChatView _view;
  late final List<ForgeView> _views;

  /// The chat view, for hosting in the bottom panel.
  AgentChatView get chatView => _view;

  @override
  String get displayName => 'Agent Chat';

  @override
  void activate(ForgeShellApi shell) {
    // Restore the persisted binding, then scan for live servers. The scan runs
    // asynchronously; the picker reflects progress via the controller.
    controller.loadPersisted();
    controller.scan();
  }

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => _views;

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
}

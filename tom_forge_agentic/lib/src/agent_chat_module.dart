import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'agent_chat_view.dart';
import 'chat/chat_composer_panel.dart';
import 'chat/chat_send_coordinator.dart';
import 'connection/agent_connection_controller.dart';
import 'queue/prompt_queue_controller.dart';
import 'queue/prompt_queue_editor.dart';
import 'send/agent_send_controller.dart';
import 'trail/prompt_trail_controller.dart';
import 'trail/prompt_trail_editor.dart';

/// Reusable agent chat module (§4.2, §6, §11).
///
/// Contributed by any agent/chat-enabled Forge tool. It owns the connection,
/// send, prompt-trail and prompt-queue controllers and exposes the three §5
/// placement-ready surfaces: the [chatView] (connection picker + composer) for
/// the bottom panel, plus the [queueEditor] (Col 2) and [trailEditor] (Col 3)
/// for the middle splits. On [activate] it restores the persisted binding and
/// queue/trail state, then kicks off a port scan (19900–19909) so the picker is
/// populated as soon as the shell is shown.
///
/// All controllers are injectable so tests (and hosts that want to share one
/// connection across modules) can supply their own — e.g. a [sendController]
/// built over a fake transport so no socket is opened.
class AgentChatModule extends ForgeModule {
  AgentChatModule({
    AgentConnectionController? controller,
    AgentSendController? sendController,
    PromptTrailController? trailController,
    PromptQueueController? queueController,
    String Function(String raw)? compose,
    String Function(String source)? composePreview,
    List<ChatComposerProfile> profiles = const <ChatComposerProfile>[],
    String? selectedProfileId,
    void Function(String? profileId)? onProfileSelected,
    void Function(String turnId)? onTurnBegin,
    void Function()? onTurnEnd,
  }) : controller = controller ?? AgentConnectionController() {
    this.sendController =
        sendController ?? AgentSendController(connection: this.controller);
    this.trailController = trailController ?? PromptTrailController();
    coordinator = ChatSendCoordinator(
      send: this.sendController,
      trail: this.trailController,
      compose: compose,
      onTurnBegin: onTurnBegin,
      onTurnEnd: onTurnEnd,
    );
    this.queueController =
        queueController ?? PromptQueueController(coordinator: coordinator);
    _view = AgentChatView(
      controller: this.controller,
      sendController: this.sendController,
      queueController: this.queueController,
      coordinator: coordinator,
      composePreview: composePreview,
      profiles: profiles,
      selectedProfileId: selectedProfileId,
      onProfileSelected: onProfileSelected,
    );
    _views = [_view];
    _queueEditor = PromptQueueEditor(controller: this.queueController);
    _trailEditor = PromptTrailEditor(controller: this.trailController);
    _editors = [_queueEditor, _trailEditor];
  }

  /// The shared connection controller (scan + binding state).
  final AgentConnectionController controller;

  /// The send controller streaming agent answers (§7).
  late final AgentSendController sendController;

  /// The prompt trail of request/answer pairs (§11.3).
  late final PromptTrailController trailController;

  /// The prompt queue (§11.2).
  late final PromptQueueController queueController;

  /// Sends a composed prompt and records the exchange in the trail (§11.1).
  late final ChatSendCoordinator coordinator;

  late final AgentChatView _view;
  late final List<ForgeView> _views;
  late final PromptQueueEditor _queueEditor;
  late final PromptTrailEditor _trailEditor;
  late final List<ForgeEditor> _editors;

  /// The chat view (connection picker + composer), for the bottom panel.
  AgentChatView get chatView => _view;

  /// The prompt-queue editor, for the §5 Col 2 middle split.
  PromptQueueEditor get queueEditor => _queueEditor;

  /// The prompt-trail editor, for the §5 Col 3 middle split.
  PromptTrailEditor get trailEditor => _trailEditor;

  @override
  String get displayName => 'Agent Chat';

  @override
  void activate(ForgeShellApi shell) {
    // Restore the persisted binding + queue/trail, then scan for live servers.
    // The scan runs asynchronously; the picker reflects progress via the
    // controller.
    controller.loadPersisted();
    trailController.load();
    queueController.load();
    controller.scan();
  }

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => _editors;

  @override
  List<ForgeView> get views => _views;

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
}

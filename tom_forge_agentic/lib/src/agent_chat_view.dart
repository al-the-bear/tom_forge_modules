import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'chat/chat_composer_panel.dart';
import 'chat/chat_send_coordinator.dart';
import 'connection/agent_connection_controller.dart';
import 'connection/agent_connection_picker.dart';
import 'queue/prompt_queue_controller.dart';
import 'queue/prompt_queue_view.dart';
import 'send/agent_send_controller.dart';
import 'trail/prompt_trail_controller.dart';
import 'trail/prompt_trail_view.dart';

/// The bottom-panel agent chat view (§5, §11).
///
/// Lays out the full chat suite: the connection picker on top (accessible for
/// rebinding), the prompt **queue** (Col 2) and **trail** (Col 3) side by side
/// in the middle, and the chat **composer** + streamed answer at the bottom.
/// "Send now" routes through the [ChatSendCoordinator] (recording the trail
/// pair); "Add to queue" defers onto the [PromptQueueController].
class AgentChatView extends ForgeView {
  AgentChatView({
    required this.controller,
    required this.sendController,
    required this.trailController,
    required this.queueController,
    required this.coordinator,
  })  : _title = ValueNotifier<String>('Chat'),
        _titleExtension = ValueNotifier<String?>(null);

  /// The connection controller driving the picker.
  final AgentConnectionController controller;

  /// The send controller streaming the answer into the output view.
  final AgentSendController sendController;

  /// The prompt trail (Col 3).
  final PromptTrailController trailController;

  /// The prompt queue (Col 2).
  final PromptQueueController queueController;

  /// Sends "Send now" prompts and records them in the trail.
  final ChatSendCoordinator coordinator;

  final ValueNotifier<String> _title;
  final ValueNotifier<String?> _titleExtension;

  @override
  IconData get icon => Icons.chat_bubble_outline;

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  /// The minimum height the stacked chat regions (picker · queue/trail ·
  /// composer) need before their fixed section headers start to clip. The
  /// bottom panel is often far shorter than this, so the view scrolls below it.
  static const double _minStackHeight = 560;

  @override
  Widget buildMain(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          // The bottom panel is frequently only a few dozen pixels tall. Give
          // the three stacked regions a sensible minimum and let the whole view
          // scroll when the panel is shorter, so the headers never overflow.
          final available = constraints.maxHeight;
          final height = available.isFinite && available > _minStackHeight
              ? available
              : _minStackHeight;
          return SingleChildScrollView(
            child: SizedBox(height: height, child: _stack()),
          );
        },
      );

  Widget _stack() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: AgentConnectionPicker(controller: controller),
          ),
          const Divider(height: 1),
          // Queue (Col 2) + trail (Col 3) side by side.
          Expanded(
            flex: 3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: PromptQueueView(controller: queueController)),
                const VerticalDivider(width: 1),
                Expanded(child: PromptTrailView(controller: trailController)),
              ],
            ),
          ),
          const Divider(height: 1),
          // Composer + streamed answer (bottom).
          Expanded(
            flex: 4,
            child: ChatComposerPanel(
              controller: sendController,
              onSendNow: coordinator.sendNow,
              onAddToQueue: queueController.addPrompt,
            ),
          ),
        ],
      );

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

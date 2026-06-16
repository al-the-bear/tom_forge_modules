import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'connection/agent_connection_controller.dart';
import 'connection/agent_connection_picker.dart';
import 'send/agent_send_controller.dart';
import 'send/agent_send_panel.dart';

/// The bottom-panel agent chat view (§5).
///
/// Step 11 hosted the **connection picker** only; step 12 adds the minimal §7
/// **send panel** (streaming output + composer) below it. The picker stays
/// accessible at the top so the user can rebind without leaving the view; the
/// full composer, queue and trail arrive in step 16.
class AgentChatView extends ForgeView {
  AgentChatView({required this.controller, required this.sendController})
      : _title = ValueNotifier<String>('Chat'),
        _titleExtension = ValueNotifier<String?>(null);

  /// The connection controller driving the picker.
  final AgentConnectionController controller;

  /// The send controller streaming the answer into the output view.
  final AgentSendController sendController;

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

  @override
  Widget buildMain(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Picker on top (accessible for rebinding), send panel below it with
          // the larger share of the space for the streamed answer.
          Expanded(flex: 2, child: AgentConnectionPicker(controller: controller)),
          const Divider(height: 1),
          Expanded(flex: 3, child: AgentSendPanel(controller: sendController)),
        ],
      );

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

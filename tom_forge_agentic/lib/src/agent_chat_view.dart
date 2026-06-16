import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'connection/agent_connection_controller.dart';
import 'connection/agent_connection_picker.dart';

/// The bottom-panel agent chat view (§5).
///
/// In Stage C step 11 this view hosts the **connection picker** only — the
/// chat composer, streaming output, queue and trail arrive in Stages C/D. It
/// renders the [AgentConnectionPicker] over the shared
/// [AgentConnectionController].
class AgentChatView extends ForgeView {
  AgentChatView({required this.controller})
      : _title = ValueNotifier<String>('Chat'),
        _titleExtension = ValueNotifier<String?>(null);

  /// The connection controller driving the picker.
  final AgentConnectionController controller;

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
  Widget buildMain(BuildContext context) =>
      AgentConnectionPicker(controller: controller);

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

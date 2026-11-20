import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_agentic_ui/tom_agentic_ui.dart';


/// The bottom-panel agent chat view (§5, §11.1).
///
/// Hosts the **chat composer** half of the suite: the connection picker on top
/// (accessible for rebinding) and the placeholder-aware composer + streamed
/// answer below. The prompt **queue** (Col 2) and **trail** (Col 3) are *not*
/// stacked here — they are their own middle-panel editors
/// ([PromptQueueEditor] / [PromptTrailEditor], hosted by [AgentChatModule]).
/// "Send now" routes through the [ChatSendCoordinator] (recording the trail
/// pair); "Add to queue" defers onto the [PromptQueueController].
class AgentChatView extends ForgeView {
  AgentChatView({
    required this.controller,
    required this.sendController,
    required this.queueController,
    required this.coordinator,
    this.composePreview,
    this.profiles = const <ChatComposerProfile>[],
    this.selectedProfileId,
    this.onProfileSelected,
  })  : _title = ValueNotifier<String>('Chat'),
        _titleExtension = ValueNotifier<String?>(null);

  /// The connection controller driving the picker.
  final AgentConnectionController controller;

  /// The send controller streaming the answer into the output view.
  final AgentSendController sendController;

  /// The prompt queue, fed by the composer's "Add to queue" action (Col 2 is
  /// rendered separately by [PromptQueueEditor]).
  final PromptQueueController queueController;

  /// Sends "Send now" prompts and records them in the trail.
  final ChatSendCoordinator coordinator;

  /// Expands the composer input's placeholders for the live preview (§11.5,
  /// OE-14); null hides the preview.
  final PromptCompose? composePreview;

  /// Profiles offered in the composer's profile picker (§11.1); empty hides it.
  final List<ChatComposerProfile> profiles;

  /// The currently selected profile id, or null for "no profile".
  final String? selectedProfileId;

  /// Routes a profile selection back to the host (null = cleared).
  final ValueChanged<String?>? onProfileSelected;

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

  /// The minimum height the stacked chat regions (picker · composer) need
  /// before their fixed section headers start to clip. The bottom panel is
  /// often far shorter than this, so the view scrolls below it.
  static const double _minStackHeight = 420;

  @override
  Widget buildMain(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          // The bottom panel is frequently only a few dozen pixels tall. Give
          // the two stacked regions a sensible minimum and let the whole view
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
          // Composer + streamed answer.
          Expanded(
            flex: 5,
            child: ChatComposerPanel(
              controller: sendController,
              onSendNow: coordinator.sendNow,
              onAddToQueue: queueController.addPrompt,
              composePreview: composePreview,
              profiles: profiles,
              selectedProfileId: selectedProfileId,
              onProfileSelected: onProfileSelected,
            ),
          ),
        ],
      );

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

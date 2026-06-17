import 'package:flutter/material.dart';

import '../send/agent_reconnect_banner.dart';
import '../send/agent_send_controller.dart';

/// The bottom chat composer (§11.1): the streamed answer above a multiline
/// input with two actions — **Send now** (stream immediately) and **Add to
/// queue** (defer for §11.2 dispatch).
///
/// The streaming output + reconnect surface come from the shared
/// [AgentSendController]; the two actions are delegated to the host via
/// [onSendNow] / [onAddToQueue] so the composer stays transport-agnostic — the
/// host wires "Send now" through the trail-recording coordinator and "Add to
/// queue" through the queue controller.
///
/// (The profile picker and placeholder-aware expansion of §11.1/§11.5 arrive in
/// step 17; this step delivers the composer shell and the two actions.)
class ChatComposerPanel extends StatefulWidget {
  const ChatComposerPanel({
    super.key,
    required this.controller,
    required this.onSendNow,
    required this.onAddToQueue,
  });

  /// The send controller supplying the streamed answer and busy/reconnect state.
  final AgentSendController controller;

  /// Streams the composed prompt immediately (records the trail pair).
  final ValueChanged<String> onSendNow;

  /// Defers the composed prompt onto the queue.
  final ValueChanged<String> onAddToQueue;

  @override
  State<ChatComposerPanel> createState() => _ChatComposerPanelState();
}

class _ChatComposerPanelState extends State<ChatComposerPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_autoScroll);
    _input.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_autoScroll);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onInputChanged() => setState(() {});

  void _autoScroll() {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  String get _text => _input.text.trim();

  void _sendNow() {
    final prompt = _text;
    if (prompt.isEmpty || !widget.controller.canSend) return;
    _input.clear();
    widget.onSendNow(prompt);
  }

  void _addToQueue() {
    final prompt = _text;
    if (prompt.isEmpty) return;
    _input.clear();
    widget.onAddToQueue(prompt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AgentReconnectBanner(controller: controller),
            Expanded(child: _output(theme, controller)),
            const Divider(height: 1),
            _composer(theme, controller),
          ],
        );
      },
    );
  }

  Widget _output(ThemeData theme, AgentSendController controller) {
    if (controller.error != null) {
      return _centered(theme, Icons.error_outline, '${controller.error}',
          theme.colorScheme.error);
    }
    if (controller.output.isEmpty) {
      return _centered(
        theme,
        controller.sending ? Icons.hourglass_top : Icons.bolt_outlined,
        controller.sending
            ? 'Sending…'
            : 'Send a prompt to the bound VS Code agent.',
        theme.colorScheme.onSurfaceVariant,
      );
    }
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.all(12),
      child: SelectableText(controller.output, style: theme.textTheme.bodyMedium),
    );
  }

  Widget _composer(ThemeData theme, AgentSendController controller) {
    final hasText = _text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _input,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Ask the agent…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: hasText ? _addToQueue : null,
                icon: const Icon(Icons.playlist_add, size: 18),
                label: const Text('Add to queue'),
              ),
              const SizedBox(width: 8),
              controller.sending
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed:
                          hasText && controller.canSend ? _sendNow : null,
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('Send now'),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _centered(ThemeData theme, IconData icon, String text, Color color) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 8),
              Text(
                text,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

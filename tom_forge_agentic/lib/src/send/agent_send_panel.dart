import 'package:flutter/material.dart';

import 'agent_send_controller.dart';

/// The minimal §7 send surface: a read-only streaming output area above a
/// one-line composer (text field + Send button).
///
/// Step 12's "minimal output view" — the full chat composer, queue and trail
/// arrive in step 16. The output area auto-scrolls to the tail as chunks stream
/// in; Send is disabled while a turn is in flight or no bridge is bound.
class AgentSendPanel extends StatefulWidget {
  const AgentSendPanel({super.key, required this.controller});

  /// The send controller streaming the answer.
  final AgentSendController controller;

  @override
  State<AgentSendPanel> createState() => _AgentSendPanelState();
}

class _AgentSendPanelState extends State<AgentSendPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Auto-scroll the output to the tail as new chunks arrive.
    widget.controller.addListener(_autoScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_autoScroll);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _autoScroll() {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _send() {
    final prompt = _input.text.trim();
    if (prompt.isEmpty || !widget.controller.canSend) return;
    _input.clear();
    widget.controller.send(prompt);
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
            if (controller.reconnectPhase != ReconnectPhase.idle)
              _reconnectBanner(theme, controller),
            Expanded(child: _output(theme, controller)),
            const Divider(height: 1),
            _composer(theme, controller),
          ],
        );
      },
    );
  }

  /// The §6.1 reconnect surface: a non-blocking info strip while probing, and
  /// the modal/confirm actions when the protocol pauses for a user decision.
  Widget _reconnectBanner(ThemeData theme, AgentSendController controller) {
    final scheme = theme.colorScheme;
    switch (controller.reconnectPhase) {
      case ReconnectPhase.idle:
        return const SizedBox.shrink();
      case ReconnectPhase.probing:
        return _banner(
          theme,
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
          'Lost connection to the VS Code server — retrying…',
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case ReconnectPhase.awaitingDifferentWorkspace:
        final ws = controller.differentWorkspaceServer?.workspace ?? 'another';
        return _banner(
          theme,
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          'The server on this port now serves "$ws". Reconnect to it and '
          're-send the interrupted prompt?',
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: controller.resendPending,
                child: const Text('Dismiss'),
              ),
              FilledButton(
                onPressed: controller.confirmDifferentWorkspace,
                child: const Text('Reconnect'),
              ),
            ],
          ),
        );
      case ReconnectPhase.awaitingStillGone:
        return _banner(
          theme,
          scheme.errorContainer,
          scheme.onErrorContainer,
          'Still no VS Code server on this port. Your prompt is preserved — '
          'retry when the window is back, or abort.',
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: controller.abortReconnect,
                child: const Text('Abort'),
              ),
              FilledButton(
                onPressed: controller.resendPending,
                child: const Text('Retry'),
              ),
            ],
          ),
        );
    }
  }

  Widget _banner(
    ThemeData theme,
    Color background,
    Color foreground,
    String text,
    Widget trailing,
  ) {
    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }

  Widget _output(ThemeData theme, AgentSendController controller) {
    if (controller.error != null) {
      return _centered(
        theme,
        Icons.error_outline,
        '${controller.error}',
        theme.colorScheme.error,
      );
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
      child: SelectableText(
        controller.output,
        style: theme.textTheme.bodyMedium,
      ),
    );
  }

  Widget _composer(ThemeData theme, AgentSendController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Ask the agent…',
                border: OutlineInputBorder(),
              ),
            ),
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
              : IconButton.filled(
                  tooltip: controller.canSend
                      ? 'Send'
                      : 'Bind a VS Code bridge first',
                  icon: const Icon(Icons.send, size: 18),
                  onPressed: controller.canSend ? _send : null,
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

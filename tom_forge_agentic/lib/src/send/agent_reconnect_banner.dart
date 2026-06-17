import 'package:flutter/material.dart';

import 'agent_send_controller.dart';

/// The §6.1 reconnect surface, shared by the minimal send panel and the full
/// chat composer: a non-blocking info strip while probing, and the
/// modal/confirm actions when the protocol pauses for a user decision.
///
/// Renders nothing while [AgentSendController.reconnectPhase] is
/// [ReconnectPhase.idle].
class AgentReconnectBanner extends StatelessWidget {
  const AgentReconnectBanner({super.key, required this.controller});

  /// The send controller whose reconnect phase drives the banner.
  final AgentSendController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
}

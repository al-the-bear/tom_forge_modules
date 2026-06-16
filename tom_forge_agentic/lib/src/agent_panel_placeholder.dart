import 'package:flutter/material.dart';
import 'package:tom_core_agentic/tom_core_agentic.dart';

/// Placeholder for an agent/chat panel.
///
/// This is the scaffold stand-in for the real agent views (chat composer,
/// prompt queue, prompt trail, agent settings) that Stage C and Stage D of the
/// editor plan add to this package. It exists so the package has a concrete,
/// renderable export and so the wiring to `tom_core_agentic` is exercised at
/// compile time (it previews [status] via the shared [textPreview] helper).
class AgentPanelPlaceholder extends StatelessWidget {
  const AgentPanelPlaceholder({
    super.key,
    this.title = 'Agent',
    this.status = 'Agent UI is not wired yet.',
  });

  /// Short heading shown at the top of the panel.
  final String title;

  /// Status line shown beneath the heading; long text is truncated by the
  /// shared [textPreview] helper from `tom_core_agentic`.
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.smart_toy_outlined,
              size: 32, color: theme.disabledColor),
          const SizedBox(height: 8),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            textPreview(status, limit: 120),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.disabledColor),
          ),
        ],
      ),
    );
  }
}

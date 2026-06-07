import 'package:flutter/material.dart';
import 'package:tom_website_editor_core/tom_website_editor_core.dart';

import 'website_editor_controller.dart';

/// Settings-dialog panel for the website editor module (§9.2).
///
/// Lets the developer pick the active website (which drives every other view)
/// and reload `tom.website-editor.yaml` after editing it. Validation issues
/// from the most recent load/reload are listed so an invalid config is visible
/// without leaving the panel.
class WebsiteConfigPanel extends StatelessWidget {
  const WebsiteConfigPanel({super.key, required this.controller});

  /// Owns the registry and active-website selection.
  final WebsiteEditorController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Websites', style: theme.textTheme.titleMedium),
            ),
            TextButton.icon(
              onPressed: controller.isLoading ? null : controller.reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Reload configuration'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (controller.isLoading)
          const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          ),
        if (!controller.isLoaded && !controller.isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No valid configuration loaded.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        _buildWebsiteList(),
        if (controller.issues.isNotEmpty) ...[
          const SizedBox(height: 12),
          _IssueList(issues: controller.issues),
        ],
      ],
    );
  }

  Widget _buildWebsiteList() {
    return RadioGroup<String>(
      groupValue: controller.activeWebsiteId,
      onChanged: (id) {
        if (id != null) controller.selectWebsite(id);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final website in controller.websites)
            RadioListTile<String>(
              value: website.id,
              title: Text(website.label ?? website.id),
              subtitle: website.label == null ? null : Text(website.id),
              dense: true,
            ),
        ],
      ),
    );
  }
}

/// Lists configuration issues with severity-coloured icons.
class _IssueList extends StatelessWidget {
  const _IssueList({required this.issues});

  final List<ConfigIssue> issues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Issues', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        for (final issue in issues)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  issue.severity == ConfigSeverity.error
                      ? Icons.error_outline
                      : Icons.warning_amber_outlined,
                  size: 16,
                  color: issue.severity == ConfigSeverity.error
                      ? theme.colorScheme.error
                      : Colors.orange,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${issue.path}: ${issue.message}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

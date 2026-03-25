import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import '../components/forge_component.dart';
import '../components/forge_view.dart';
import '../shell/forge_layout_controller.dart';

/// Problems panel showing diagnostics grouped by file.
///
/// Severity icon, message, and source location. Clicking a diagnostic
/// navigates to the file at the diagnostic position.
class ForgeProblemsView extends ForgeView {
  final ForgeDiagnosticManager diagnosticManager;
  final ForgeLayoutController layoutController;

  final _title = ValueNotifier<String>('Problems');
  final _titleExtension = ValueNotifier<String?>(null);

  ForgeProblemsView({
    required this.diagnosticManager,
    required this.layoutController,
  });

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => Icons.error_outline;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints(
        preferredSize: Size(400, 200),
      );

  @override
  Widget buildMain(BuildContext context) {
    return _ProblemsContent(
      diagnosticManager: diagnosticManager,
      layoutController: layoutController,
    );
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

class _ProblemsContent extends StatelessWidget {
  final ForgeDiagnosticManager diagnosticManager;
  final ForgeLayoutController layoutController;

  const _ProblemsContent({
    required this.diagnosticManager,
    required this.layoutController,
  });

  @override
  Widget build(BuildContext context) {
    final allDiags = diagnosticManager.all;

    if (allDiags.isEmpty) {
      return Center(
        child: Text(
          'No problems detected',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
        ),
      );
    }

    // Group by URI.
    final grouped = <Uri, List<ForgeDiagnostic>>{};
    for (final diag in allDiags) {
      grouped.putIfAbsent(diag.uri, () => []).add(diag);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 2),
      children: [
        for (final entry in grouped.entries) ...[
          _buildFileHeader(context, entry.key),
          for (final diag in entry.value) _buildDiagnostic(context, diag),
        ],
      ],
    );
  }

  Widget _buildFileHeader(BuildContext context, Uri uri) {
    final name = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : uri.path;
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 6, bottom: 2),
      child: Text(
        name,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildDiagnostic(BuildContext context, ForgeDiagnostic diag) {
    final theme = Theme.of(context);
    final iconData = switch (diag.severity) {
      ForgeSeverity.error => Icons.error,
      ForgeSeverity.warning => Icons.warning_amber,
      ForgeSeverity.info => Icons.info_outline,
      ForgeSeverity.hint => Icons.lightbulb_outline,
    };
    final iconColor = switch (diag.severity) {
      ForgeSeverity.error => theme.colorScheme.error,
      ForgeSeverity.warning => Colors.orange,
      ForgeSeverity.info => theme.colorScheme.primary,
      ForgeSeverity.hint => Colors.grey,
    };

    return InkWell(
      onTap: () => layoutController.openFile(diag.uri),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Row(
          children: [
            Icon(iconData, size: 14, color: iconColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                diag.message,
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${diag.range.start.line + 1}:${diag.range.start.column + 1}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

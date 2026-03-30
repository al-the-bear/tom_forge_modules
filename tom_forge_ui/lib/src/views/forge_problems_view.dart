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
  }) {
    // Keep the title extension in sync with diagnostic count.
    if (diagnosticManager is DefaultDiagnosticManager) {
      final dm = diagnosticManager as DefaultDiagnosticManager;
      dm.allNotifier.addListener(_updateTitleExtension);
      _updateTitleExtension();
    }
  }

  void _updateTitleExtension() {
    final count = diagnosticManager.all.length;
    _titleExtension.value = count > 0 ? '($count)' : null;
  }

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

/// Filter mode for the problems panel.
enum _SeverityFilter { all, errors, warnings }

class _ProblemsContent extends StatefulWidget {
  final ForgeDiagnosticManager diagnosticManager;
  final ForgeLayoutController layoutController;

  const _ProblemsContent({
    required this.diagnosticManager,
    required this.layoutController,
  });

  @override
  State<_ProblemsContent> createState() => _ProblemsContentState();
}

class _ProblemsContentState extends State<_ProblemsContent> {
  _SeverityFilter _filter = _SeverityFilter.all;

  @override
  void initState() {
    super.initState();
    if (widget.diagnosticManager is DefaultDiagnosticManager) {
      final dm = widget.diagnosticManager as DefaultDiagnosticManager;
      dm.allNotifier.addListener(_onDiagnosticsChanged);
    }
  }

  @override
  void dispose() {
    if (widget.diagnosticManager is DefaultDiagnosticManager) {
      final dm = widget.diagnosticManager as DefaultDiagnosticManager;
      dm.allNotifier.removeListener(_onDiagnosticsChanged);
    }
    super.dispose();
  }

  void _onDiagnosticsChanged() {
    if (mounted) setState(() {});
  }

  List<ForgeDiagnostic> get _filteredDiags {
    final all = widget.diagnosticManager.all;
    return switch (_filter) {
      _SeverityFilter.all => all,
      _SeverityFilter.errors =>
        all.where((d) => d.severity == ForgeSeverity.error).toList(),
      _SeverityFilter.warnings => all
          .where((d) =>
              d.severity == ForgeSeverity.error ||
              d.severity == ForgeSeverity.warning)
          .toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final allDiags = _filteredDiags;

    return Column(
      children: [
        _buildFilterBar(context),
        Expanded(
          child: allDiags.isEmpty
              ? Center(
                  child: Text(
                    'No problems detected',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                        ),
                  ),
                )
              : _buildDiagnosticList(context, allDiags),
        ),
      ],
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final theme = Theme.of(context);
    final all = widget.diagnosticManager.all;
    final errorCount =
        all.where((d) => d.severity == ForgeSeverity.error).length;
    final warningCount =
        all.where((d) => d.severity == ForgeSeverity.warning).length;
    final infoCount =
        all.where((d) => d.severity == ForgeSeverity.info).length;

    Widget chip(
        _SeverityFilter f, IconData icon, Color color, String label) {
      final selected = _filter == f;
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => setState(() => _filter = f),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          chip(_SeverityFilter.all, Icons.list, theme.colorScheme.onSurface,
              'All (${all.length})'),
          chip(_SeverityFilter.errors, Icons.error, theme.colorScheme.error,
              'Errors ($errorCount)'),
          chip(_SeverityFilter.warnings, Icons.warning_amber, Colors.orange,
              'Warnings ($warningCount)'),
          const Spacer(),
          Text(
            '$infoCount info',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticList(
      BuildContext context, List<ForgeDiagnostic> diags) {
    // Group by URI.
    final grouped = <Uri, List<ForgeDiagnostic>>{};
    for (final diag in diags) {
      grouped.putIfAbsent(diag.uri, () => []).add(diag);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 2),
      children: [
        for (final entry in grouped.entries) ...[
          _buildFileHeader(context, entry.key, entry.value.length),
          for (final diag in entry.value) _buildDiagnostic(context, diag),
        ],
      ],
    );
  }

  Widget _buildFileHeader(BuildContext context, Uri uri, int count) {
    final name = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : uri.path;
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 6, bottom: 2),
      child: Row(
        children: [
          Text(
            name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
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
      onTap: () => widget.layoutController.openFile(
        diag.uri,
        line: diag.range.start.line,
        column: diag.range.start.column,
      ),
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
            if (diag.source.isNotEmpty) ...[
              Text(
                diag.source,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: 8),
            ],
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

import 'package:flutter/material.dart';

import '../theme/md_editor_theme.dart';
import '../widgets/overlays/md_table_overlay.dart';
import 'md_content_plugin.dart';

/// Built-in plugin for rendering and editing markdown tables.
///
/// Tables are detected via regex preprocessing (they're not fenced code blocks)
/// and rendered as interactive Flutter [Table] widgets with hover edit buttons.
class MdTablePlugin extends MdContentPlugin {
  @override
  String get id => 'table';

  @override
  String get displayName => 'Table';

  @override
  IconData get icon => Icons.table_chart;

  @override
  String get insertTemplate =>
      '| Column 1 | Column 2 | Column 3 |\n'
      '| --- | --- | --- |\n'
      '| Cell 1 | Cell 2 | Cell 3 |\n';

  @override
  List<String> get languages => [];

  @override
  bool matchesLanguage(String language) => language.startsWith('table-edit-');

  @override
  MdPreprocessor get preprocessor => MdPreprocessor(
        pattern: _tableRegex,
        tagPrefix: 'table-edit',
      );

  static final _tableRegex = RegExp(
    r'^\|.+\|[ \t]*\n\|[\s\-:|]+\|[ \t]*\n(\|.+\|[ \t]*\n?)+',
    multiLine: true,
  );

  @override
  Widget? buildPreview(
    String content,
    MdBasicTheme theme, {
    required VoidCallback onEdit,
  }) {
    return _TablePreviewWidget(
      tableMarkdown: content,
      theme: theme,
      onEdit: onEdit,
    );
  }

  @override
  Future<String?> openEditor(
    BuildContext context,
    String currentContent,
    MdEditorTheme theme,
  ) async {
    String? result;
    await showDialog<void>(
      context: context,
      builder: (_) => MdTableOverlay(
        markdownTable: currentContent,
        theme: theme,
        onSave: (newTable) => result = newTable,
      ),
    );
    return result;
  }

  @override
  String wrapForMarkdown(String content) => content;
}

// ── Table preview widget ──

class _TablePreviewWidget extends StatefulWidget {
  const _TablePreviewWidget({
    required this.tableMarkdown,
    required this.theme,
    required this.onEdit,
  });

  final String tableMarkdown;
  final MdBasicTheme theme;
  final VoidCallback onEdit;

  @override
  State<_TablePreviewWidget> createState() => _TablePreviewWidgetState();
}

class _TablePreviewWidgetState extends State<_TablePreviewWidget> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final rows = _parseRows(widget.tableMarkdown);
    if (rows.isEmpty) return const SizedBox.shrink();

    final alignments = _parseAlignments(widget.tableMarkdown);
    final theme = widget.theme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: theme.border),
              borderRadius: BorderRadius.circular(theme.borderRadius),
            ),
            child: Table(
              border: TableBorder.all(color: theme.border, width: 0.5),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: List.generate(rows.length, (r) {
                final isHeader = r == 0;
                return TableRow(
                  decoration: BoxDecoration(
                    color:
                        isHeader ? theme.surfaceVariant : Colors.transparent,
                  ),
                  children: List.generate(rows[r].length, (c) {
                    final align = c < alignments.length
                        ? alignments[c]
                        : TextAlign.start;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        rows[r][c],
                        textAlign: align,
                        style: TextStyle(
                          color: theme.text,
                          fontSize: theme.baseFontSize * 0.9,
                          fontWeight:
                              isHeader ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    );
                  }),
                );
              }),
            ),
          ),
          if (_hovering)
            Positioned(
              top: 4,
              right: 4,
              child: MdOverlayButton(
                icon: Icons.edit,
                tooltip: 'Edit table',
                onTap: widget.onEdit,
                theme: theme,
              ),
            ),
        ],
      ),
    );
  }

  List<List<String>> _parseRows(String table) {
    final lines =
        table.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final result = <List<String>>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (RegExp(r'^[\|\s\-:]+$').hasMatch(trimmed)) continue;
      final cells = trimmed
          .split('|')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList();
      if (cells.isNotEmpty) result.add(cells);
    }
    if (result.isNotEmpty) {
      final maxCols =
          result.fold<int>(0, (m, row) => row.length > m ? row.length : m);
      for (final row in result) {
        while (row.length < maxCols) {
          row.add('');
        }
      }
    }
    return result;
  }

  List<TextAlign> _parseAlignments(String table) {
    final lines =
        table.split('\n').where((l) => l.trim().isNotEmpty).toList();
    for (final line in lines) {
      final trimmed = line.trim();
      if (RegExp(r'^[\|\s\-:]+$').hasMatch(trimmed)) {
        final parts = trimmed
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
        return parts.map((p) {
          final left = p.startsWith(':');
          final right = p.endsWith(':');
          if (left && right) return TextAlign.center;
          if (right) return TextAlign.end;
          return TextAlign.start;
        }).toList();
      }
    }
    return [];
  }
}

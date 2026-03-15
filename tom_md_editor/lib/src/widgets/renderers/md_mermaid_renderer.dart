import 'package:flutter/material.dart';
import 'package:flutter_mermaid/flutter_mermaid.dart';

import '../../debug/md_editor_debug.dart';
import '../../theme/md_editor_theme.dart';

/// Regex to detect ` ```mermaid ` code blocks.
final mermaidBlockPattern = RegExp(
  r'```mermaid\s*\n([\s\S]*?)```',
  multiLine: true,
);

/// List of supported Mermaid diagram types.
const kMermaidDiagramTypes = [
  'flowchart',
  'sequenceDiagram',
  'classDiagram',
  'stateDiagram',
  'erDiagram',
  'journey',
  'gantt',
  'pie',
  'mindmap',
  'timeline',
  'quadrantChart',
  'gitGraph',
];

/// Renders Mermaid diagrams using the `flutter_mermaid` package.
///
/// Renders the diagram visually via [MermaidDiagram] and optionally
/// displays the source in a collapsible panel for editing.
class MdMermaidRenderer extends StatefulWidget {
  const MdMermaidRenderer({
    super.key,
    required this.source,
    required this.theme,
    this.onEdit,
  });

  final String source;
  final MdEditorTheme theme;
  final VoidCallback? onEdit;

  @override
  State<MdMermaidRenderer> createState() => _MdMermaidRendererState();
}

class _MdMermaidRendererState extends State<MdMermaidRenderer> {
  bool _showSource = false;
  final bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    final basic = widget.theme.basic;
    try {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: basic.surfaceVariant,
          borderRadius: BorderRadius.circular(basic.borderRadius),
          border: Border.all(color: basic.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(basic),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _hasError
                  ? _buildFallback(basic)
                  : _buildDiagram(basic),
            ),
            if (_showSource) _buildSourcePanel(basic),
          ],
        ),
      );
    } catch (e, st) {
      MdEditorDebug.logger.error('Error rendering mermaid', e, st);
      return Text(
        'Mermaid render error',
        style: TextStyle(color: basic.error),
      );
    }
  }

  Widget _buildHeader(MdBasicTheme basic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: basic.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.schema, size: 16, color: basic.accent),
          const SizedBox(width: 8),
          Text(
            'Mermaid Diagram',
            style: TextStyle(
              color: basic.text,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: () => setState(() => _showSource = !_showSource),
            child: Tooltip(
              message: _showSource ? 'Hide source' : 'Show source',
              child: Icon(
                _showSource ? Icons.code_off : Icons.code,
                size: 16,
                color: basic.textMuted,
              ),
            ),
          ),
          if (widget.onEdit != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: widget.onEdit,
              child: Tooltip(
                message: 'Edit diagram source',
                child: Icon(Icons.edit, size: 16, color: basic.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiagram(MdBasicTheme basic) {
    return MermaidDiagram(code: widget.source);
  }

  Widget _buildFallback(MdBasicTheme basic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.warning_amber_rounded, size: 20, color: basic.warning),
        const SizedBox(height: 8),
        Text(
          'Diagram rendering failed. Source shown below.',
          style: TextStyle(color: basic.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: basic.codeBackground,
            borderRadius: BorderRadius.circular(4),
          ),
          child: SelectableText(
            widget.source,
            style: TextStyle(
              fontFamily: basic.monoFontFamily,
              fontSize: basic.baseFontSize * 0.85,
              color: basic.textSecondary,
              height: basic.lineHeight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSourcePanel(MdBasicTheme basic) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: basic.codeBackground,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: basic.codeBorder),
      ),
      child: SelectableText(
        widget.source,
        style: TextStyle(
          fontFamily: basic.monoFontFamily,
          fontSize: basic.baseFontSize * 0.85,
          color: basic.textSecondary,
          height: basic.lineHeight,
        ),
      ),
    );
  }
}

/// Checks if text contains a Mermaid code block.
bool containsMermaid(String text) => mermaidBlockPattern.hasMatch(text);

/// Extracts Mermaid diagram source from code blocks.
List<String> extractMermaidSources(String text) {
  return mermaidBlockPattern
      .allMatches(text)
      .map((m) => m.group(1)!.trim())
      .toList();
}

import 'package:flutter/material.dart';
import 'package:tom_mermaid_view/tom_mermaid_view.dart';

import '../theme/md_editor_theme.dart';
import '../widgets/overlays/md_mermaid_overlay.dart';
import 'md_content_plugin.dart';

/// Interface for custom graphical editors for specific Mermaid diagram types.
///
/// Implement this to provide a visual editor for a particular diagram type
/// (e.g., a node-and-edge editor for flowcharts, a timeline editor for gantt
/// charts). Register instances with [MdMermaidPlugin.registerDiagramEditor].
///
/// Example:
/// ```dart
/// class FlowchartEditor implements MdMermaidDiagramEditor {
///   @override String get diagramType => 'flowchart';
///   @override String get displayName => 'Flowchart Editor';
///
///   @override
///   Future<String?> openEditor(
///       BuildContext context, String source, MdEditorTheme theme) {
///     return showDialog<String>(
///       context: context,
///       builder: (_) => MyFlowchartEditorDialog(source: source),
///     );
///   }
/// }
/// ```
abstract class MdMermaidDiagramEditor {
  /// The diagram type this editor handles (e.g., `'flowchart'`, `'sequence'`).
  String get diagramType;

  /// Display name for the editor.
  String get displayName;

  /// Open the graphical editor. Returns the edited Mermaid source, or `null`
  /// if the user cancelled.
  Future<String?> openEditor(
    BuildContext context,
    String currentSource,
    MdEditorTheme theme,
  );
}

/// Built-in plugin for rendering and editing Mermaid diagrams.
///
/// Mermaid diagrams are native fenced code blocks (` ```mermaid `), so no
/// preprocessing is needed. The plugin renders diagrams using
/// [MermaidWebView] and provides a text-based overlay editor by default.
///
/// Custom graphical editors can be registered per diagram type via
/// [registerDiagramEditor]. When editing a diagram, the plugin detects the
/// diagram type from the source and delegates to the matching custom editor
/// if one is registered, otherwise falls back to the text overlay.
class MdMermaidPlugin extends MdContentPlugin {
  MdMermaidPlugin({
    List<MdMermaidDiagramEditor>? diagramEditors,
  }) : _diagramEditors = {
          for (final e in diagramEditors ?? <MdMermaidDiagramEditor>[])
            e.diagramType: e,
        };

  final Map<String, MdMermaidDiagramEditor> _diagramEditors;

  /// Register an additional graphical editor for a diagram type.
  ///
  /// If an editor for the same [MdMermaidDiagramEditor.diagramType] already
  /// exists, it is replaced.
  void registerDiagramEditor(MdMermaidDiagramEditor editor) {
    _diagramEditors[editor.diagramType] = editor;
  }

  /// All registered diagram editors, keyed by diagram type.
  Map<String, MdMermaidDiagramEditor> get diagramEditors =>
      Map.unmodifiable(_diagramEditors);

  @override
  String get id => 'mermaid';

  @override
  String get displayName => 'Mermaid Diagram';

  @override
  IconData get icon => Icons.schema;

  @override
  String get insertTemplate =>
      '```mermaid\ngraph TD\n  A[Start] --> B[End]\n```';

  @override
  List<String> get languages => ['mermaid'];

  @override
  Widget? buildPreview(
    String content,
    MdBasicTheme theme, {
    required VoidCallback onEdit,
  }) {
    return _MermaidPreviewWidget(
      code: content,
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
    // Check for custom graphical editor for this diagram type.
    final type = _detectDiagramType(currentContent);
    final customEditor = type != null ? _diagramEditors[type] : null;

    if (customEditor != null) {
      return customEditor.openEditor(context, currentContent, theme);
    }

    // Fall back to text-based overlay.
    return MdMermaidOverlay.show(
      context: context,
      theme: theme,
      initialSource: currentContent,
    );
  }

  @override
  String wrapForMarkdown(String content) => '```mermaid\n$content\n```';

  /// Detect the Mermaid diagram type from source content.
  String? _detectDiagramType(String content) {
    final trimmed = content.trimLeft();
    if (trimmed.startsWith('graph ') || trimmed.startsWith('graph\n')) {
      return 'flowchart';
    }
    if (trimmed.startsWith('flowchart ') ||
        trimmed.startsWith('flowchart\n')) {
      return 'flowchart';
    }
    if (trimmed.startsWith('sequenceDiagram')) return 'sequence';
    if (trimmed.startsWith('classDiagram')) return 'class';
    if (trimmed.startsWith('stateDiagram')) return 'state';
    if (trimmed.startsWith('erDiagram')) return 'er';
    if (trimmed.startsWith('pie')) return 'pie';
    if (trimmed.startsWith('gantt')) return 'gantt';
    if (trimmed.startsWith('timeline')) return 'timeline';
    if (trimmed.startsWith('kanban')) return 'kanban';
    if (trimmed.startsWith('mindmap')) return 'mindmap';
    if (trimmed.startsWith('xychart-beta')) return 'xychart';
    if (trimmed.startsWith('radar-beta')) return 'radar';
    if (trimmed.startsWith('gitGraph')) return 'git';
    if (trimmed.startsWith('journey')) return 'journey';
    if (trimmed.startsWith('quadrantChart')) return 'quadrant';
    return null;
  }
}

// ── Mermaid preview widget with hover edit button ──

class _MermaidPreviewWidget extends StatefulWidget {
  const _MermaidPreviewWidget({
    required this.code,
    required this.theme,
    required this.onEdit,
  });

  final String code;
  final MdBasicTheme theme;
  final VoidCallback onEdit;

  @override
  State<_MermaidPreviewWidget> createState() => _MermaidPreviewWidgetState();
}

class _MermaidPreviewWidgetState extends State<_MermaidPreviewWidget> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(widget.theme.blockPadding),
            decoration: BoxDecoration(
              color: widget.theme.surfaceVariant,
              borderRadius:
                  BorderRadius.circular(widget.theme.borderRadius),
              border: Border.all(color: widget.theme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'mermaid',
                    style: TextStyle(
                      color: widget.theme.textMuted,
                      fontSize: 11,
                      fontFamily: widget.theme.monoFontFamily,
                    ),
                  ),
                ),
                MermaidWebView(
                  source: widget.code,
                  theme: widget.theme.background.computeLuminance() < 0.5
                      ? MermaidTheme.dark
                      : MermaidTheme.light,
                  backgroundColor: widget.theme.surfaceVariant,
                ),
              ],
            ),
          ),
          if (_hovering)
            Positioned(
              top: 4,
              right: 4,
              child: MdOverlayButton(
                icon: Icons.edit,
                tooltip: 'Edit diagram',
                onTap: widget.onEdit,
                theme: widget.theme,
              ),
            ),
        ],
      ),
    );
  }
}

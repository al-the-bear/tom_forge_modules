import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../theme/md_editor_theme.dart';
import '../widgets/overlays/md_math_overlay.dart';
import 'md_content_plugin.dart';

/// Built-in plugin for rendering and editing LaTeX math blocks (`$$..$$`).
///
/// Display math is detected via preprocessing (`$$..$$` → `math-display-N`
/// fenced blocks). Inline math (`$...$`) is handled separately by the
/// preview panel's inline syntax extension.
class MdMathPlugin extends MdContentPlugin {
  @override
  String get id => 'math';

  @override
  String get displayName => 'Math (LaTeX)';

  @override
  IconData get icon => Icons.functions;

  @override
  String get insertTemplate => '\$\$\nE = mc^2\n\$\$';

  @override
  List<String> get languages => ['math-display'];

  @override
  bool matchesLanguage(String language) =>
      language == 'math-display' || language.startsWith('math-display-');

  @override
  MdPreprocessor get preprocessor => MdPreprocessor(
        pattern: RegExp(r'\$\$([\s\S]*?)\$\$'),
        tagPrefix: 'math-display',
        contentExtractor: (m) => m.group(1)!.trim(),
      );

  @override
  Widget? buildPreview(
    String content,
    MdBasicTheme theme, {
    required VoidCallback onEdit,
  }) {
    return _MathPreviewWidget(
      expression: content,
      theme: theme,
      onEdit: onEdit,
    );
  }

  @override
  Future<String?> openEditor(
    BuildContext context,
    String currentContent,
    MdEditorTheme theme,
  ) {
    return MdMathOverlay.show(
      context: context,
      theme: theme,
      initialLatex: currentContent,
      isBlock: true,
    );
  }

  @override
  String wrapForMarkdown(String content) => '\$\$\n${content.trim()}\n\$\$';
}

// ── Math preview widget with hover edit button ──

class _MathPreviewWidget extends StatefulWidget {
  const _MathPreviewWidget({
    required this.expression,
    required this.theme,
    required this.onEdit,
  });

  final String expression;
  final MdBasicTheme theme;
  final VoidCallback onEdit;

  @override
  State<_MathPreviewWidget> createState() => _MathPreviewWidgetState();
}

class _MathPreviewWidgetState extends State<_MathPreviewWidget> {
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
            padding: EdgeInsets.symmetric(
              vertical: widget.theme.paragraphSpacing,
              horizontal: widget.theme.blockPadding,
            ),
            alignment: Alignment.center,
            child: Math.tex(
              widget.expression.trim(),
              mathStyle: MathStyle.display,
              textStyle: TextStyle(
                fontSize: widget.theme.baseFontSize * 1.2,
                color: widget.theme.text,
              ),
              onErrorFallback: (err) => Text(
                widget.expression.trim(),
                style: TextStyle(
                  color: widget.theme.error,
                  fontFamily: widget.theme.monoFontFamily,
                  fontSize: widget.theme.baseFontSize,
                ),
              ),
            ),
          ),
          if (_hovering)
            Positioned(
              top: 4,
              right: 4,
              child: MdOverlayButton(
                icon: Icons.edit,
                tooltip: 'Edit math',
                onTap: widget.onEdit,
                theme: widget.theme,
              ),
            ),
        ],
      ),
    );
  }
}

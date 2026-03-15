import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

import '../../debug/md_editor_debug.dart';
import '../../theme/md_editor_theme.dart';

/// Regex for inline math: $...$ (not $$)
final _inlineMathPattern = RegExp(r'(?<!\$)\$(?!\$)(.+?)(?<!\$)\$(?!\$)');

/// Regex for block math: $$...$$
final _blockMathPattern = RegExp(r'\$\$([\s\S]+?)\$\$');

/// Custom MarkdownElementBuilder that renders LaTeX math expressions
/// using flutter_math_fork.
///
/// Detects both inline `$...$` and block `$$...$$` math syntax.
class MdMathBuilder extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^\$\$');

  @override
  md.Node? parse(md.BlockParser parser) {
    final buffer = StringBuffer();
    // Skip opening $$
    parser.advance();

    while (!parser.isDone) {
      final line = parser.current.content;
      if (line.trimRight() == r'$$') {
        parser.advance();
        break;
      }
      buffer.writeln(line);
      parser.advance();
    }

    final element = md.Element('math-block', [md.Text(buffer.toString().trimRight())]);
    return element;
  }
}

/// Widget builder for rendering math blocks in the preview panel.
class MdMathBlockBuilder extends StatelessWidget {
  const MdMathBlockBuilder({
    super.key,
    required this.latex,
    required this.theme,
    this.isBlock = false,
    this.onTap,
  });

  final String latex;
  final MdEditorTheme theme;
  final bool isBlock;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    try {
      final basic = theme.basic;
      final mathWidget = Math.tex(
        latex,
        textStyle: TextStyle(
          color: basic.text,
          fontSize: isBlock ? basic.baseFontSize * 1.2 : basic.baseFontSize,
        ),
        onErrorFallback: (err) => Text(
          'Math error: ${err.message}',
          style: TextStyle(color: basic.error, fontSize: 12),
        ),
      );

      if (!isBlock) {
        return GestureDetector(
          onTap: onTap,
          child: mathWidget,
        );
      }

      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: basic.blockPadding),
          alignment: Alignment.center,
          child: mathWidget,
        ),
      );
    } catch (e, st) {
      MdEditorDebug.logger.error('Error rendering math', e, st);
      return Text(
        'Math render error',
        style: TextStyle(color: theme.basic.error),
      );
    }
  }
}

/// Checks if text contains inline math expressions.
bool containsInlineMath(String text) => _inlineMathPattern.hasMatch(text);

/// Checks if text contains block math expressions.
bool containsBlockMath(String text) => _blockMathPattern.hasMatch(text);

/// Extracts all inline math expressions from text.
List<String> extractInlineMath(String text) {
  return _inlineMathPattern
      .allMatches(text)
      .map((m) => m.group(1)!)
      .toList();
}

/// Extracts all block math expressions from text.
List<String> extractBlockMath(String text) {
  return _blockMathPattern
      .allMatches(text)
      .map((m) => m.group(1)!.trim())
      .toList();
}

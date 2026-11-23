import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:tom_md_editor/tom_md_editor.dart';

/// Inline math: matches `$...$` but not `$$`, as a [tag] element.
class MdInlineMathSyntax extends md.InlineSyntax {
  MdInlineMathSyntax() : super(r'\$([^\$]+?)\$');

  /// The tag of the element the syntax produces.
  static const tag = 'math-inline';

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final expression = match.group(1)!;
    final el = md.Element.text(tag, expression);
    parser.addNode(el);
    return true;
  }
}

/// Renders an inline math element ([MdInlineMathSyntax]) with
/// `flutter_math_fork`; an expression it cannot read is shown as its source.
class MdInlineMathBuilder extends MarkdownElementBuilder {
  MdInlineMathBuilder({required this.theme});

  final MdBasicTheme theme;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final expression = element.textContent;
    return Math.tex(
      expression,
      mathStyle: MathStyle.text,
      textStyle: TextStyle(fontSize: theme.baseFontSize, color: theme.text),
      onErrorFallback: (err) => Text(
        '\$$expression\$',
        style: TextStyle(
          color: theme.error,
          fontFamily: theme.monoFontFamily,
          fontSize: theme.baseFontSize,
        ),
      ),
    );
  }
}

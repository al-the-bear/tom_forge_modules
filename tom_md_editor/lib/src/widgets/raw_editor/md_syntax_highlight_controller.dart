import 'package:flutter/material.dart';
import 'package:tom_text_highlight/tom_text_highlight.dart';

/// Custom [TextEditingController] that provides markdown syntax highlighting
/// by overriding [buildTextSpan], through the one highlighter interface
/// ([SyntaxHighlighter], `tom_text_highlight`).
///
/// By default it highlights headings, bold, italic, inline code, links, list
/// markers, and block indicators using colors derived from the provided theme
/// ([MdRawSyntaxHighlighter]); [highlighter] replaces that.
class MdSyntaxHighlightController extends TextEditingController {
  MdSyntaxHighlightController({
    super.text,
    required this.headingColor,
    required this.boldColor,
    required this.italicColor,
    required this.codeColor,
    required this.linkColor,
    required this.listMarkerColor,
    required this.defaultColor,
    required this.fontFamily,
    required this.fontSize,
    required this.lineHeight,
    SyntaxHighlighter? highlighter,
  }) {
    this.highlighter =
        highlighter ??
        MdRawSyntaxHighlighter(
          headingColor: headingColor,
          boldColor: boldColor,
          italicColor: italicColor,
          codeColor: codeColor,
          linkColor: linkColor,
          listMarkerColor: listMarkerColor,
          fontFamily: fontFamily,
        );
  }

  final Color headingColor;
  final Color boldColor;
  final Color italicColor;
  final Color codeColor;
  final Color linkColor;
  final Color listMarkerColor;
  final Color defaultColor;
  final String fontFamily;
  final double fontSize;
  final double lineHeight;

  /// The highlighting of the text.
  late final SyntaxHighlighter highlighter;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      color: defaultColor,
      height: lineHeight,
    );

    final source = text;
    if (source.isEmpty) {
      return TextSpan(style: baseStyle, text: '');
    }
    final spans = highlighter.highlight(source);
    if (spans.isEmpty) {
      return TextSpan(style: baseStyle, text: source);
    }
    return TextSpan(
      style: baseStyle,
      children: highlightedInlineSpans(source, spans),
    );
  }
}

/// The Markdown raw editor's own highlighting rules: headings, bold, italic,
/// inline code, links, list markers, code fences and block quote markers,
/// the first match winning where they overlap.
class MdRawSyntaxHighlighter extends SyntaxHighlighter {
  MdRawSyntaxHighlighter({
    required this.headingColor,
    required this.boldColor,
    required this.italicColor,
    required this.codeColor,
    required this.linkColor,
    required this.listMarkerColor,
    required this.fontFamily,
  });

  final Color headingColor;
  final Color boldColor;
  final Color italicColor;
  final Color codeColor;
  final Color linkColor;
  final Color listMarkerColor;
  final String fontFamily;

  /// Ordered list of syntax rules, matched from first to last.
  static final List<_SyntaxRule> _rules = [
    // Headings: lines starting with # markers
    _SyntaxRule(RegExp(r'^#{1,6}\s+.*$', multiLine: true), _RuleType.heading),
    // Bold: **text** or __text__
    _SyntaxRule(RegExp(r'(\*\*|__)(.+?)(\*\*|__)'), _RuleType.bold),
    // Italic: *text* or _text_ (not inside bold)
    _SyntaxRule(
      RegExp(
        r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)|(?<!_)_(?!_)(.+?)(?<!_)_(?!_)',
      ),
      _RuleType.italic,
    ),
    // Inline code: `code`
    _SyntaxRule(RegExp(r'`[^`]+`'), _RuleType.code),
    // Links: [text](url)
    _SyntaxRule(RegExp(r'\[([^\]]+)\]\([^)]+\)'), _RuleType.link),
    // List markers: -, *, +, or numbered (1.)
    _SyntaxRule(
      RegExp(r'^(\s*)([-*+]|\d+\.)\s', multiLine: true),
      _RuleType.listMarker,
    ),
    // Code block fences
    _SyntaxRule(RegExp(r'^```.*$', multiLine: true), _RuleType.code),
    // Blockquote markers
    _SyntaxRule(RegExp(r'^>\s', multiLine: true), _RuleType.listMarker),
  ];

  @override
  List<HighlightSpan> highlight(String source) {
    // Collect all matches with their style types
    final highlights = <_Highlight>[];
    for (final rule in _rules) {
      for (final match in rule.pattern.allMatches(source)) {
        highlights.add(
          _Highlight(start: match.start, end: match.end, type: rule.type),
        );
      }
    }

    // Sort by start position, then by length (longer matches first)
    highlights.sort((a, b) {
      final cmp = a.start.compareTo(b.start);
      return cmp != 0 ? cmp : b.end.compareTo(a.end);
    });

    // Remove overlapping highlights (first match wins)
    final spans = <HighlightSpan>[];
    var lastEnd = 0;
    for (final h in highlights) {
      if (h.start >= lastEnd) {
        spans.add(
          HighlightSpan(
            start: h.start,
            end: h.end,
            style: _styleFor(h.type),
            type: h.type.name,
          ),
        );
        lastEnd = h.end;
      }
    }
    return spans;
  }

  TextStyle _styleFor(_RuleType type) {
    return switch (type) {
      _RuleType.heading => TextStyle(
        color: headingColor,
        fontWeight: FontWeight.w700,
      ),
      _RuleType.bold => TextStyle(
        color: boldColor,
        fontWeight: FontWeight.w700,
      ),
      _RuleType.italic => TextStyle(
        color: italicColor,
        fontStyle: FontStyle.italic,
      ),
      _RuleType.code => TextStyle(color: codeColor, fontFamily: fontFamily),
      _RuleType.link => TextStyle(
        color: linkColor,
        decoration: TextDecoration.underline,
        decorationColor: linkColor,
      ),
      _RuleType.listMarker => TextStyle(color: listMarkerColor),
    };
  }
}

enum _RuleType { heading, bold, italic, code, link, listMarker }

class _SyntaxRule {
  const _SyntaxRule(this.pattern, this.type);
  final RegExp pattern;
  final _RuleType type;
}

class _Highlight {
  const _Highlight({
    required this.start,
    required this.end,
    required this.type,
  });
  final int start;
  final int end;
  final _RuleType type;
}

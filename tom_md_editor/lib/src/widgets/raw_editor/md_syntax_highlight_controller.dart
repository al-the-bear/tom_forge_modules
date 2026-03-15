import 'package:flutter/material.dart';

/// Custom [TextEditingController] that provides markdown syntax highlighting
/// by overriding [buildTextSpan].
///
/// Highlights headings, bold, italic, inline code, links, list markers,
/// and block indicators using colors derived from the provided theme.
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
  });

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

  /// Ordered list of syntax rules, matched from first to last.
  static final List<_SyntaxRule> _rules = [
    // Headings: lines starting with # markers
    _SyntaxRule(
      RegExp(r'^#{1,6}\s+.*$', multiLine: true),
      _RuleType.heading,
    ),
    // Bold: **text** or __text__
    _SyntaxRule(
      RegExp(r'(\*\*|__)(.+?)(\*\*|__)'),
      _RuleType.bold,
    ),
    // Italic: *text* or _text_ (not inside bold)
    _SyntaxRule(
      RegExp(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)|(?<!_)_(?!_)(.+?)(?<!_)_(?!_)'),
      _RuleType.italic,
    ),
    // Inline code: `code`
    _SyntaxRule(
      RegExp(r'`[^`]+`'),
      _RuleType.code,
    ),
    // Links: [text](url)
    _SyntaxRule(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      _RuleType.link,
    ),
    // List markers: -, *, +, or numbered (1.)
    _SyntaxRule(
      RegExp(r'^(\s*)([-*+]|\d+\.)\s', multiLine: true),
      _RuleType.listMarker,
    ),
    // Code block fences
    _SyntaxRule(
      RegExp(r'^```.*$', multiLine: true),
      _RuleType.code,
    ),
    // Blockquote markers
    _SyntaxRule(
      RegExp(r'^>\s', multiLine: true),
      _RuleType.listMarker,
    ),
  ];

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

    // Collect all matches with their style types
    final highlights = <_Highlight>[];
    for (final rule in _rules) {
      for (final match in rule.pattern.allMatches(source)) {
        highlights.add(_Highlight(
          start: match.start,
          end: match.end,
          type: rule.type,
        ));
      }
    }

    if (highlights.isEmpty) {
      return TextSpan(style: baseStyle, text: source);
    }

    // Sort by start position, then by length (longer matches first)
    highlights.sort((a, b) {
      final cmp = a.start.compareTo(b.start);
      return cmp != 0 ? cmp : b.end.compareTo(a.end);
    });

    // Remove overlapping highlights (first match wins)
    final filtered = <_Highlight>[];
    var lastEnd = 0;
    for (final h in highlights) {
      if (h.start >= lastEnd) {
        filtered.add(h);
        lastEnd = h.end;
      }
    }

    // Build spans
    final spans = <TextSpan>[];
    var pos = 0;
    for (final h in filtered) {
      if (h.start > pos) {
        spans.add(TextSpan(text: source.substring(pos, h.start)));
      }
      spans.add(TextSpan(
        text: source.substring(h.start, h.end),
        style: _styleFor(h.type),
      ));
      pos = h.end;
    }
    if (pos < source.length) {
      spans.add(TextSpan(text: source.substring(pos)));
    }

    return TextSpan(style: baseStyle, children: spans);
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
      _RuleType.code => TextStyle(
          color: codeColor,
          fontFamily: fontFamily,
        ),
      _RuleType.link => TextStyle(
          color: linkColor,
          decoration: TextDecoration.underline,
          decorationColor: linkColor,
        ),
      _RuleType.listMarker => TextStyle(
          color: listMarkerColor,
        ),
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

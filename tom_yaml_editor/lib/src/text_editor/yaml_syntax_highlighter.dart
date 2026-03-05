import 'package:flutter/painting.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

class YamlSyntaxHighlighter extends SyntaxHighlighter {
  final YamlHighlightColors colors;

  YamlSyntaxHighlighter({
    this.colors = const YamlHighlightColors(),
  });

  @override
  List<HighlightSpan> highlight(String source) {
    final spans = <HighlightSpan>[];
    final lines = source.split('\n');
    var offset = 0;

    for (final line in lines) {
      _highlightLine(line, offset, spans);
      offset += line.length + 1;
    }

    return spans;
  }

  void _highlightLine(String line, int lineOffset, List<HighlightSpan> spans) {
    var trimmed = line.trimLeft();
    if (trimmed.isEmpty) return;

    if (trimmed.startsWith('#')) {
      final commentStart = lineOffset + line.indexOf('#');
      spans.add(HighlightSpan(
        start: commentStart,
        end: lineOffset + line.length,
        style: TextStyle(color: colors.comment),
        type: 'comment',
      ));
      return;
    }

    if (trimmed == '---' || trimmed == '...') {
      final markerStart = lineOffset + line.indexOf(trimmed);
      spans.add(HighlightSpan(
        start: markerStart,
        end: markerStart + trimmed.length,
        style: TextStyle(color: colors.punctuation),
        type: 'document_marker',
      ));
      return;
    }

    // Account for leading whitespace so spans align with actual characters.
    final indent = line.length - trimmed.length;
    var contentStart = lineOffset + indent;
    if (trimmed.startsWith('- ')) {
      spans.add(HighlightSpan(
        start: contentStart,
        end: contentStart + 1,
        style: TextStyle(color: colors.dash),
        type: 'list_dash',
      ));
      contentStart += 2;
      trimmed = trimmed.substring(2);
    }

    final colonIndex = _findKeyColonIndex(trimmed);
    if (colonIndex > 0) {
      final key = trimmed.substring(0, colonIndex);

      spans.add(HighlightSpan(
        start: contentStart,
        end: contentStart + key.length,
        style: TextStyle(color: colors.key),
        type: 'key',
      ));

      spans.add(HighlightSpan(
        start: contentStart + colonIndex,
        end: contentStart + colonIndex + 1,
        style: TextStyle(color: colors.colon),
        type: 'colon',
      ));

      final afterColon = trimmed.substring(colonIndex + 1).trimLeft();
      if (afterColon.isNotEmpty) {
        final valueStart = contentStart + trimmed.indexOf(afterColon, colonIndex);
        final commentIdx = _findCommentIndex(afterColon);
        final valueText = commentIdx >= 0
            ? afterColon.substring(0, commentIdx).trimRight()
            : afterColon;

        if (valueText.isNotEmpty) {
          _highlightValue(valueText, valueStart, spans);
          _highlightBrackets(valueText, valueStart, spans);
        }

        if (commentIdx >= 0) {
          final commentStart = valueStart + commentIdx;
          spans.add(HighlightSpan(
            start: commentStart,
            end: contentStart + trimmed.length,
            style: TextStyle(color: colors.comment),
            type: 'comment',
          ));
        }
      }
      return;
    }

    _highlightValue(trimmed, contentStart, spans);
    _highlightBrackets(trimmed, contentStart, spans);
  }

  void _highlightValue(String value, int offset, List<HighlightSpan> spans) {
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      spans.add(HighlightSpan(
        start: offset,
        end: offset + value.length,
        style: TextStyle(color: colors.string),
        type: 'string',
      ));
      return;
    }

    if (value == '|' || value == '>' || value == '|-' || value == '>-') {
      spans.add(HighlightSpan(
        start: offset,
        end: offset + value.length,
        style: TextStyle(color: colors.punctuation),
        type: 'block_scalar',
      ));
      return;
    }

    final lower = value.toLowerCase();
    if (lower == 'true' ||
        lower == 'false' ||
        lower == 'yes' ||
        lower == 'no' ||
        lower == 'on' ||
        lower == 'off') {
      spans.add(HighlightSpan(
        start: offset,
        end: offset + value.length,
        style: TextStyle(color: colors.boolean),
        type: 'boolean',
      ));
      return;
    }

    if (lower == 'null' || lower == '~') {
      spans.add(HighlightSpan(
        start: offset,
        end: offset + value.length,
        style: TextStyle(color: colors.nullValue),
        type: 'null',
      ));
      return;
    }

    if (_isNumber(value)) {
      spans.add(HighlightSpan(
        start: offset,
        end: offset + value.length,
        style: TextStyle(color: colors.number),
        type: 'number',
      ));
      return;
    }

    spans.add(HighlightSpan(
      start: offset,
      end: offset + value.length,
      style: TextStyle(color: colors.string),
      type: 'string',
    ));
  }

  void _highlightBrackets(String text, int offset, List<HighlightSpan> spans) {
    var inSingleQuote = false;
    var inDoubleQuote = false;

    for (var index = 0; index < text.length; index++) {
      final ch = text[index];
      if (ch == "'" && !inDoubleQuote) {
        inSingleQuote = !inSingleQuote;
        continue;
      }
      if (ch == '"' && !inSingleQuote) {
        inDoubleQuote = !inDoubleQuote;
        continue;
      }
      if (inSingleQuote || inDoubleQuote) continue;

      if (ch == '[' || ch == ']' || ch == '{' || ch == '}') {
        spans.add(HighlightSpan(
          start: offset + index,
          end: offset + index + 1,
          style: TextStyle(color: colors.bracket),
          type: 'bracket',
        ));
      }
    }
  }

  int _findKeyColonIndex(String line) {
    var inSingleQuote = false;
    var inDoubleQuote = false;

    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == "'" && !inDoubleQuote) inSingleQuote = !inSingleQuote;
      if (ch == '"' && !inSingleQuote) inDoubleQuote = !inDoubleQuote;

      if (ch == ':' && !inSingleQuote && !inDoubleQuote) {
        if (i + 1 >= line.length || line[i + 1] == ' ' || line[i + 1] == '\t') {
          return i;
        }
      }
    }
    return -1;
  }

  int _findCommentIndex(String value) {
    var inSingleQuote = false;
    var inDoubleQuote = false;

    for (var i = 0; i < value.length; i++) {
      final ch = value[i];
      if (ch == "'" && !inDoubleQuote) inSingleQuote = !inSingleQuote;
      if (ch == '"' && !inSingleQuote) inDoubleQuote = !inDoubleQuote;

      if (ch == '#' &&
          !inSingleQuote &&
          !inDoubleQuote &&
          i > 0 &&
          value[i - 1] == ' ') {
        return i;
      }
    }

    return -1;
  }

  bool _isNumber(String value) {
    if (value.isEmpty) return false;
    return double.tryParse(value) != null || int.tryParse(value) != null;
  }
}

class YamlHighlightColors {
  final Color key;
  final Color string;
  final Color number;
  final Color boolean;
  final Color nullValue;
  final Color comment;
  final Color punctuation;
  final Color colon;
  final Color dash;
  final Color bracket;

  const YamlHighlightColors({
    this.key = const Color(0xFF9CDCFE),
    this.string = const Color(0xFFCE9178),
    this.number = const Color(0xFFB5CEA8),
    this.boolean = const Color(0xFF569CD6),
    this.nullValue = const Color(0xFF569CD6),
    this.comment = const Color(0xFF6A9955),
    this.punctuation = const Color(0xFF808080),
    this.colon = const Color(0xFFDCDCAA),
    this.dash = const Color(0xFF4EC9B0),
    this.bracket = const Color(0xFFC586C0),
  });
}

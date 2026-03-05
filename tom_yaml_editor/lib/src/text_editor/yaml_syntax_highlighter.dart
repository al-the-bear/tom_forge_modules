import 'package:flutter/painting.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

/// Syntax highlighter for YAML source text.
///
/// Implements [SyntaxHighlighter] from `tom_editors_shared` to tokenize
/// YAML and produce styled spans for keys, string values, numbers, booleans,
/// comments, and block scalars.
///
/// ```dart
/// final highlighter = YamlSyntaxHighlighter();
/// var spans = highlighter.highlight(yamlSource);
/// ```
class YamlSyntaxHighlighter extends SyntaxHighlighter {
  /// Colors for different YAML token types.
  final YamlHighlightColors colors;

  YamlSyntaxHighlighter({
    this.colors = const YamlHighlightColors(),
  });

  @override
  List<HighlightSpan> highlight(String source) {
    var spans = <HighlightSpan>[];
    var lines = source.split('\n');
    var offset = 0;

    for (var line in lines) {
      _highlightLine(line, offset, spans);
      offset += line.length + 1; // +1 for newline
    }

    return spans;
  }

  void _highlightLine(String line, int lineOffset, List<HighlightSpan> spans) {
    var trimmed = line.trimLeft();

    // Empty line
    if (trimmed.isEmpty) return;

    // Full-line comment
    if (trimmed.startsWith('#')) {
      var commentStart = lineOffset + line.indexOf('#');
      spans.add(HighlightSpan(
        start: commentStart,
        end: lineOffset + line.length,
        style: TextStyle(color: colors.comment),
        type: 'comment',
      ));
      return;
    }

    // Document markers
    if (trimmed == '---' || trimmed == '...') {
      spans.add(HighlightSpan(
        start: lineOffset + line.indexOf(trimmed),
        end: lineOffset + line.indexOf(trimmed) + 3,
        style: TextStyle(color: colors.punctuation),
        type: 'document_marker',
      ));
      return;
    }

    // List item prefix "- "
    var contentStart = lineOffset;
    if (trimmed.startsWith('- ')) {
      var dashPos = lineOffset + (line.length - trimmed.length);
      spans.add(HighlightSpan(
        start: dashPos,
        end: dashPos + 1,
        style: TextStyle(color: colors.punctuation),
        type: 'list_dash',
      ));
      // Continue to parse the rest after "- "
      contentStart = dashPos + 2;
      trimmed = trimmed.substring(2);
    }

    // Key: value pair
    var colonIndex = _findKeyColonIndex(trimmed);
    if (colonIndex > 0) {
      var keyStart =
          contentStart + (trimmed.length - trimmed.trimLeft().length);
      var key = trimmed.substring(0, colonIndex).trimLeft();

      // Key span
      spans.add(HighlightSpan(
        start: keyStart,
        end: keyStart + key.length,
        style: TextStyle(
          color: colors.key,
          fontWeight: FontWeight.w600,
        ),
        type: 'key',
      ));

      // Colon
      spans.add(HighlightSpan(
        start: contentStart + colonIndex,
        end: contentStart + colonIndex + 1,
        style: TextStyle(
          color: colors.punctuation,
          fontWeight: FontWeight.w600,
        ),
        type: 'colon',
      ));

      // Value (after colon + space)
      var afterColon = trimmed.substring(colonIndex + 1).trimLeft();
      if (afterColon.isNotEmpty) {
        var valueStart = contentStart + trimmed.indexOf(afterColon, colonIndex);

        // Check for inline comment
        var commentIdx = _findCommentIndex(afterColon);
        var valueText = commentIdx >= 0
            ? afterColon.substring(0, commentIdx).trimRight()
            : afterColon;

        if (valueText.isNotEmpty) {
          _highlightValue(valueText, valueStart, spans);
        }

        // Inline comment
        if (commentIdx >= 0) {
          var commentStart = valueStart + commentIdx;
          spans.add(HighlightSpan(
            start: commentStart,
            end: contentStart + trimmed.length,
            style: TextStyle(color: colors.comment),
            type: 'comment',
          ));
        }
      }
    } else {
      // Bare value (in a list or flow context)
      _highlightValue(trimmed, contentStart, spans);
    }
  }

  void _highlightValue(
    String value,
    int offset,
    List<HighlightSpan> spans,
  ) {
    // Quoted string
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

    // Block scalar indicators
    if (value == '|' || value == '>' || value == '|-' || value == '>-') {
      spans.add(HighlightSpan(
        start: offset,
        end: offset + value.length,
        style: TextStyle(color: colors.punctuation),
        type: 'block_scalar',
      ));
      return;
    }

    // Boolean
    var lower = value.toLowerCase();
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

    // Null
    if (lower == 'null' || lower == '~') {
      spans.add(HighlightSpan(
        start: offset,
        end: offset + value.length,
        style: TextStyle(color: colors.nullValue),
        type: 'null',
      ));
      return;
    }

    // Number
    if (_isNumber(value)) {
      spans.add(HighlightSpan(
        start: offset,
        end: offset + value.length,
        style: TextStyle(color: colors.number),
        type: 'number',
      ));
      return;
    }

    // Unquoted string value
    spans.add(HighlightSpan(
      start: offset,
      end: offset + value.length,
      style: TextStyle(color: colors.string),
      type: 'string',
    ));
  }

  /// Find the colon that separates key from value.
  /// Ignores colons inside quoted strings.
  int _findKeyColonIndex(String line) {
    var inSingleQuote = false;
    var inDoubleQuote = false;

    for (var i = 0; i < line.length; i++) {
      var ch = line[i];
      if (ch == "'" && !inDoubleQuote) inSingleQuote = !inSingleQuote;
      if (ch == '"' && !inSingleQuote) inDoubleQuote = !inDoubleQuote;

      if (ch == ':' && !inSingleQuote && !inDoubleQuote) {
        // Must be followed by space, end-of-line, or newline
        if (i + 1 >= line.length || line[i + 1] == ' ' || line[i + 1] == '\t') {
          return i;
        }
      }
    }
    return -1;
  }

  /// Find the start of an inline comment (# preceded by space).
  int _findCommentIndex(String value) {
    var inSingleQuote = false;
    var inDoubleQuote = false;

    for (var i = 0; i < value.length; i++) {
      var ch = value[i];
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

/// Colors used by [YamlSyntaxHighlighter].
class YamlHighlightColors {
  /// Color for mapping keys.
  final Color key;

  /// Color for string values.
  final Color string;

  /// Color for numeric values.
  final Color number;

  /// Color for boolean values.
  final Color boolean;

  /// Color for null/~ values.
  final Color nullValue;

  /// Color for comments.
  final Color comment;

  /// Color for structural punctuation (colons, dashes, block indicators).
  final Color punctuation;

  const YamlHighlightColors({
    this.key = const Color(0xFF9CDCFE),
    this.string = const Color(0xFFCE9178),
    this.number = const Color(0xFFB5CEA8),
    this.boolean = const Color(0xFF569CD6),
    this.nullValue = const Color(0xFF569CD6),
    this.comment = const Color(0xFF6A9955),
    this.punctuation = const Color(0xFF808080),
  });
}

// The YAML editor's source view looks as before: the shared YamlHighlighter
// in the editor's colours gives every visible character the colour the
// editor's own YamlSyntaxHighlighter gave it (spans applied in order, the
// later winning, as TextEditorCore applies them). The former highlighter is
// kept below, verbatim (renamed), as the reference.
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

List<TextStyle?> charStyles(String source, List<HighlightSpan> spans) {
  final styles = List<TextStyle?>.filled(source.length, null);
  for (final span in spans) {
    for (var i = span.start.clamp(0, source.length);
        i < span.end.clamp(0, source.length);
        i++) {
      styles[i] = span.style;
    }
  }
  return styles;
}

const sample = r'''
# Schema of a quest file
---
name: "quest"   # quoted
version: 1.2
enabled: true
legacy: Off
missing: null
tilde: ~
items:
  - first
  - "second"
  - key: value # trailing
    other: [a, b, {c: d}]
block: |
  literal text
folded: >-
  folded text
'quoted key': 'quoted value'
url: http://example.com:8080/x
count: -3
...
''';

void main() {
  for (final colors in const [
    YamlHighlightColors(),
    YamlHighlightColors(
      key: Color(0xFF000001),
      string: Color(0xFF000002),
      number: Color(0xFF000003),
      boolean: Color(0xFF000004),
      nullValue: Color(0xFF000005),
      comment: Color(0xFF000006),
      punctuation: Color(0xFF000007),
      colon: Color(0xFF000008),
      dash: Color(0xFF000009),
      bracket: Color(0xFF00000A),
    ),
  ]) {
    test(
        'YamlSyntaxHighlighter: every visible character in the colour of '
        'before (${colors.key})', () {
      final before = charStyles(sample,
          LegacyYamlSyntaxHighlighter(colors: colors).highlight(sample));
      final after = charStyles(
          sample, YamlSyntaxHighlighter(colors: colors).highlight(sample));
      expect(before.whereType<TextStyle>(), isNotEmpty);
      expect([
        for (var i = 0; i < sample.length; i++)
          if (sample[i].trim().isNotEmpty && before[i] != after[i])
            '$i ${sample[i]} ${before[i]?.color} ${after[i]?.color}',
      ], isEmpty);
    });
  }
}

// ---------------------------------------------------------------------------
// The former YamlSyntaxHighlighter, verbatim (renamed), as the reference.
// ---------------------------------------------------------------------------

class LegacyYamlSyntaxHighlighter extends SyntaxHighlighter {
  final YamlHighlightColors colors;

  LegacyYamlSyntaxHighlighter({
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
        final valueStart =
            contentStart + trimmed.indexOf(afterColon, colonIndex);
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

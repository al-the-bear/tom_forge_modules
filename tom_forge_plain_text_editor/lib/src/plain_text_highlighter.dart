import 'package:flutter/foundation.dart' show mergeSort;
import 'package:flutter/painting.dart';
import 'package:tom_file_editors/tom_file_editors.dart'
    show HighlightSpan, SyntaxHighlighter;

/// The light highlighting the plain-text editor gives the formats it opens
/// most often without an editor of their own: JSON, XML (also HTML, SVG and
/// XHTML), CSS and SQL, by the file's extension — through the one
/// highlighter interface (`SyntaxHighlighter`).
///
/// A rule's matches colour the text; where two overlap, the one that starts
/// first wins, and of two starting together the earlier rule. Every other
/// extension gets no highlighter.
class ForgePlainTextHighlighter extends SyntaxHighlighter {
  ForgePlainTextHighlighter._(this.language, this._rules, {required this.dark});

  /// The highlighter for a file with [extension] (without the dot, any
  /// case) in the dark or the light scheme, or null when the extension is
  /// none of the formats it knows.
  static ForgePlainTextHighlighter? forExtension(
    String extension, {
    required bool dark,
  }) {
    final language = languageOf(extension);
    if (language == null) return null;
    return ForgePlainTextHighlighter._(
      language,
      _rulesOf[language]!,
      dark: dark,
    );
  }

  /// The language the highlighter takes [extension] as (`json`, `xml`,
  /// `css`, `sql`), or null.
  static String? languageOf(String extension) =>
      switch (extension.toLowerCase()) {
        'json' => 'json',
        'xml' || 'html' || 'svg' || 'xhtml' => 'xml',
        'css' => 'css',
        'sql' => 'sql',
        _ => null,
      };

  /// The language highlighted (`json`, `xml`, `css`, `sql`).
  final String language;

  /// Whether the colours are the dark scheme's.
  final bool dark;

  final List<_Rule> _rules;

  @override
  List<HighlightSpan> highlight(String source) {
    final regions = <(int, int, Color)>[];
    for (final rule in _rules) {
      for (final match in rule.pattern.allMatches(source)) {
        if (match.end > match.start) {
          regions.add((match.start, match.end, dark ? rule.dark : rule.light));
        }
      }
    }
    // Stable: of two regions starting together the earlier rule's stays
    // first.
    mergeSort(regions, compare: (a, b) => a.$1.compareTo(b.$1));
    final spans = <HighlightSpan>[];
    var pos = 0;
    for (final (start, end, color) in regions) {
      if (start < pos) continue; // overlaps a region already taken
      spans.add(
        HighlightSpan(
          start: start,
          end: end,
          style: TextStyle(color: color),
          type: language,
        ),
      );
      pos = end;
    }
    return spans;
  }

  static final Map<String, List<_Rule>> _rulesOf = {
    'json': _json,
    'xml': _xml,
    'css': _css,
    'sql': _sql,
  };

  static const _comment = (Color(0xFF7F848E), Color(0xFF6A737D));
  static const _key = (Color(0xFF7DCFFF), Color(0xFF005CC5));
  static const _string = (Color(0xFF98C379), Color(0xFF116329));
  static const _keyword = (Color(0xFFC678DD), Color(0xFF6F42C1));
  static const _number = (Color(0xFFD19A66), Color(0xFF9A6700));

  static final _json = [
    _Rule(RegExp(r'//.*$', multiLine: true), _comment),
    _Rule(RegExp(r'"(?:[^"\\]|\\.)*"\s*(?=:)'), _key),
    _Rule(RegExp(r'"(?:[^"\\]|\\.)*"'), _string),
    _Rule(RegExp(r'\b(?:true|false|null)\b'), (
      const Color(0xFF56B6C2),
      const Color(0xFF1B7F83),
    )),
    _Rule(RegExp(r'-?\b\d+\.?\d*(?:[eE][+-]?\d+)?\b'), _number),
  ];

  static final _xml = [
    _Rule(RegExp(r'<!--[\s\S]*?-->'), _comment),
    _Rule(RegExp(r'</?[\w:-]+'), _keyword),
    _Rule(RegExp(r'\b[\w:-]+(?==)'), _key),
    _Rule(
      RegExp(
        r'"[^"]*"|'
        "'"
        r"[^']*'",
      ),
      _string,
    ),
    _Rule(RegExp(r'/?>'), _keyword),
  ];

  static final _css = [
    _Rule(RegExp(r'/\*[\s\S]*?\*/'), _comment),
    _Rule(RegExp(r'[.#][\w-]+'), _keyword),
    _Rule(RegExp(r'[\w-]+(?=\s*:)'), _key),
    _Rule(
      RegExp(
        r'"[^"]*"|'
        "'"
        r"[^']*'",
      ),
      _string,
    ),
    _Rule(RegExp(r'-?\b\d+\.?\d*(?:px|em|rem|%|vh|vw|s|ms)?\b'), _number),
  ];

  static final _sql = [
    _Rule(RegExp(r'--.*$', multiLine: true), _comment),
    _Rule(
      RegExp(
        r'\b(?:SELECT|FROM|WHERE|INSERT|INTO|UPDATE|SET|DELETE|CREATE|DROP|'
        r'ALTER|TABLE|INDEX|VIEW|JOIN|LEFT|RIGHT|INNER|OUTER|ON|AND|OR|NOT|'
        r'NULL|IS|IN|LIKE|ORDER|BY|GROUP|HAVING|LIMIT|OFFSET|AS|DISTINCT|'
        r'COUNT|SUM|AVG|MIN|MAX|VALUES|PRIMARY|KEY|FOREIGN|REFERENCES|'
        r'CONSTRAINT|EXISTS|UNION|ALL|CASE|WHEN|THEN|ELSE|END|BEGIN|'
        r'COMMIT|ROLLBACK)\b',
        caseSensitive: false,
      ),
      _keyword,
    ),
    _Rule(RegExp(r"'(?:[^'\\]|\\.)*'"), _string),
    _Rule(RegExp(r'-?\b\d+\.?\d*\b'), _number),
  ];
}

/// One rule: what it matches, and its colour in the dark and the light
/// scheme.
class _Rule {
  _Rule(this.pattern, (Color, Color) colors)
    : dark = colors.$1,
      light = colors.$2;

  final RegExp pattern;
  final Color dark;
  final Color light;
}

/// The plain-text editor's light highlighting: JSON, XML (HTML, SVG, XHTML),
/// CSS and SQL by extension, in the dark and the light scheme; the first
/// match that starts wins an overlap; other extensions get none.
library;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_plain_text_editor/tom_forge_plain_text_editor.dart';

/// The text each span covers, with its colour.
List<(String, Color?)> _runs(ForgePlainTextHighlighter h, String source) => [
  for (final span in h.highlight(source))
    (source.substring(span.start, span.end), span.style.color),
];

void main() {
  test('FPH-1: the languages by extension, any case; none for the rest', () {
    expect(ForgePlainTextHighlighter.languageOf('JSON'), 'json');
    for (final e in ['xml', 'html', 'svg', 'xhtml']) {
      expect(ForgePlainTextHighlighter.languageOf(e), 'xml');
    }
    expect(ForgePlainTextHighlighter.languageOf('css'), 'css');
    expect(ForgePlainTextHighlighter.languageOf('sql'), 'sql');
    expect(ForgePlainTextHighlighter.forExtension('txt', dark: true), isNull);
    expect(ForgePlainTextHighlighter.forExtension('', dark: true), isNull);
  });

  test('FPH-2: JSON keys, strings, literals, numbers and comments, in the '
      'light and the dark scheme', () {
    const source = '{"key": "value", "n": -1.5e3, "ok": true} // note';
    final light = ForgePlainTextHighlighter.forExtension('json', dark: false)!;
    final runs = _runs(light, source);
    expect(runs, contains(('"key"', const Color(0xFF005CC5))));
    expect(runs, contains(('"value"', const Color(0xFF116329))));
    expect(runs, contains(('true', const Color(0xFF1B7F83))));
    expect(runs, contains(('-1.5e3', const Color(0xFF9A6700))));
    expect(runs, contains(('// note', const Color(0xFF6A737D))));
    final dark = ForgePlainTextHighlighter.forExtension('json', dark: true)!;
    expect(_runs(dark, source), contains(('"key"', const Color(0xFF7DCFFF))));
  });

  test('FPH-3: an overlap goes to the match that starts first; spans never '
      'overlap', () {
    final h = ForgePlainTextHighlighter.forExtension('json', dark: false)!;
    // The comment holds a string: the comment, starting first, wins.
    final spans = h.highlight('// "quoted"');
    expect(spans, hasLength(1));
    expect(spans.single.end, 11);
    final all = h.highlight('{"a": "b", "c": [1, 2]}');
    for (var i = 1; i < all.length; i++) {
      expect(all[i].start, greaterThanOrEqualTo(all[i - 1].end));
    }
  });

  test('FPH-4: XML tags, attributes, values and comments', () {
    final h = ForgePlainTextHighlighter.forExtension('svg', dark: false)!;
    final runs = _runs(h, '<!-- c --><svg width="1"/>');
    expect(runs, contains(('<!-- c -->', const Color(0xFF6A737D))));
    expect(runs, contains(('<svg', const Color(0xFF6F42C1))));
    expect(runs, contains(('width', const Color(0xFF005CC5))));
    expect(runs, contains(('"1"', const Color(0xFF116329))));
    expect(runs, contains(('/>', const Color(0xFF6F42C1))));
  });

  test('FPH-5: CSS selectors, properties, numbers with units', () {
    final h = ForgePlainTextHighlighter.forExtension('css', dark: false)!;
    final runs = _runs(h, '.box { width: 10px; } /* c */');
    expect(runs, contains(('.box', const Color(0xFF6F42C1))));
    expect(runs, contains(('width', const Color(0xFF005CC5))));
    expect(runs, contains(('10px', const Color(0xFF9A6700))));
    expect(runs, contains(('/* c */', const Color(0xFF6A737D))));
  });

  test('FPH-6: SQL keywords in any case, strings, numbers, comments', () {
    final h = ForgePlainTextHighlighter.forExtension('sql', dark: false)!;
    final runs = _runs(h, "select * from t where a = 'x' and n > 2 -- c");
    expect(runs, contains(('select', const Color(0xFF6F42C1))));
    expect(runs, contains(('from', const Color(0xFF6F42C1))));
    expect(runs, contains(("'x'", const Color(0xFF116329))));
    expect(runs, contains(('2', const Color(0xFF9A6700))));
    expect(runs, contains(('-- c', const Color(0xFF6A737D))));
  });
}

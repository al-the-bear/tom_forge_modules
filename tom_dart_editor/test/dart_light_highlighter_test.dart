// The light, lexical Dart highlighter (forgerestruct9): its tokens on a
// sample, the editor highlighting with it when it is given no highlighter,
// and `highlighterForLanguage('dart')` answering it once registered.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart';
import 'package:tom_text_highlight/tom_text_highlight.dart'
    show highlighterForLanguage;

/// The tokens of [source] as `text: class`, in order.
List<String> _tokens(String source) => [
      for (final t in DartLightHighlighter().tokenize(source))
        '${source.substring(t.start, t.end)}: ${t.type}',
    ];

void main() {
  group('DLH the light highlighter\'s tokens', () {
    test('DLH-1: keywords by their class', () {
      expect(
        _tokens('final x = this; if (true) return null; import late'),
        containsAllInOrder([
          'final: keyword',
          'this: variable.language',
          'if: keyword.control',
          'true: literal.boolean',
          'return: keyword.control',
          'null: literal.null',
          'import: keyword.builtin',
          'late: keyword.builtin',
        ]),
      );
    });

    test(
        r'DLH-2: a string with $x and ${x}: the string parts, the '
        'interpolations as subst, the expression inside as code', () {
      const source = r"'a $x b ${x + 1} c'";
      expect(_tokens(source), [
        "'a : string",
        r'$x: subst',
        ' b : string',
        r'${: subst',
        '+: operator',
        '1: number',
        '}: subst',
        " c': string",
      ]);
    });

    test(
        r'DLH-3: a raw string has no interpolation; triple quotes span '
        'lines', () {
      expect(_tokens(r"r'no $x ${y}'"), [r"r'no $x ${y}': string"]);
      expect(_tokens('"""a\n\$b"""'), [
        '"""a\n: string',
        r'$b: subst',
        '""": string',
      ]);
    });

    test('DLH-4: numbers: integer, double, exponent, hexadecimal', () {
      expect(_tokens('1 2.5 1e3 0xFF'), [
        '1: number',
        '2.5: number',
        '1e3: number',
        '0xFF: number',
      ]);
    });

    test('DLH-5: line, block (nested) and doc comments', () {
      const source = '// line\n/* a /* b */ c */\n/// doc\n/** block doc */';
      expect(_tokens(source), [
        '// line: comment',
        '/* a /* b */ c */: comment',
        '/// doc: comment.doc',
        '/** block doc */: comment.doc',
      ]);
    });

    test('DLH-6: an annotation with its dotted name', () {
      expect(_tokens('@override @a.b(1)'), [
        '@override: meta',
        '@a.b: meta',
        '(: punctuation.bracket.0',
        '1: number',
        '): punctuation.bracket.0',
      ]);
    });

    test('DLH-7: brackets by their depth; types; punctuation', () {
      expect(_tokens('f([{}]);'), [
        '(: punctuation.bracket.0',
        '[: punctuation.bracket.1',
        '{: punctuation.bracket.2',
        '}: punctuation.bracket.2',
        ']: punctuation.bracket.1',
        '): punctuation.bracket.0',
        ';: punctuation',
      ]);
      expect(_tokens('String s; int n;'), [
        'String: type',
        ';: punctuation',
        'int: type',
        ';: punctuation',
      ]);
    });

    test('DLH-8: the tokens are in order and never overlap', () {
      const source = r'''
@immutable
class A<T> extends B with C {
  /// The value.
  final Map<String, List<int>> m = {'k': [1, 2.0, 0x3]};
  String get s => 'v=${m['k']?.length ?? 0} $m';
}
''';
      final tokens = DartLightHighlighter().tokenize(source);
      expect(tokens, isNotEmpty);
      for (var i = 1; i < tokens.length; i++) {
        expect(tokens[i].start, greaterThanOrEqualTo(tokens[i - 1].end),
            reason: '${tokens[i - 1]} then ${tokens[i]}');
      }
    });

    test('DLH-9: unterminated strings and comments end without a crash', () {
      expect(_tokens("'open\nx"), ["'open: string"]);
      expect(_tokens('/* open'), ['/* open: comment']);
      expect(_tokens(r"'${a"), [
        "': string",
        r'${: subst',
      ]);
    });
  });

  group('DLE the editor without tom_dart_analysis', () {
    testWidgets(
        'DLE-1: an editor given no highlighter highlights with the '
        'light one, in the theme\'s colours', (tester) async {
      final controller = DartCodeController(
        initialCode: "// c\nfinal s = 'x'; // done",
      );
      addTearDown(controller.dispose);
      final theme = DartEditorTheme.dark();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DartCodeEditor(
              controller: controller,
              theme: theme,
              settings: const DartEditorSettings(showToolbar: false),
            ),
          ),
        ),
      );
      final editable = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      final span = editable.controller.buildTextSpan(
        context: tester.element(find.byType(EditableText).first),
        withComposing: false,
      );
      final colours = <String, Color?>{};
      span.visitChildren((s) {
        if (s is TextSpan && s.text != null) colours[s.text!] = s.style?.color;
        return true;
      });
      expect(colours['// c'], theme.syntax.comment);
      expect(colours['final'], theme.syntax.keyword);
      expect(colours["'x'"], theme.syntax.string);
      expect(colours[';'], theme.syntax.punctuation);
    });

    testWidgets('DLE-2: a highlighter given to the editor is used', (
      tester,
    ) async {
      final controller = DartCodeController(initialCode: 'abc');
      addTearDown(controller.dispose);
      final theme = DartEditorTheme.dark();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DartCodeEditor(
              controller: controller,
              theme: theme,
              highlighter: _Whole('title.function'),
              settings: const DartEditorSettings(showToolbar: false),
            ),
          ),
        ),
      );
      final editable = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      final span = editable.controller.buildTextSpan(
        context: tester.element(find.byType(EditableText).first),
        withComposing: false,
      );
      Color? colour;
      span.visitChildren((s) {
        if (s is TextSpan && s.text == 'abc') colour = s.style?.color;
        return true;
      });
      expect(colour, theme.syntax.function);
    });
  });

  group('DLR code blocks', () {
    tearDown(unregisterDartCodeBlockHighlighting);

    test(
        'DLR-1: highlighterForLanguage(dart) answers the light highlighter '
        'once registered, and not before', () {
      expect(highlighterForLanguage('dart'), isNull);
      registerDartCodeBlockHighlighting();
      expect(highlighterForLanguage('Dart'), isA<DartLightHighlighter>());
      unregisterDartCodeBlockHighlighting();
      expect(highlighterForLanguage('dart'), isNull);
    });
  });
}

/// Highlights the whole text as one token of [type].
class _Whole extends TokenHighlighter {
  _Whole(this.type);

  final String type;

  @override
  List<HighlightToken> tokenize(String source) => [
        HighlightToken(0, source.length, type),
      ];
}

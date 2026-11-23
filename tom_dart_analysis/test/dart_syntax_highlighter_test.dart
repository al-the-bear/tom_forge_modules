// The analyzer-based highlighter plugged into the Dart editor
// (forgerestruct9): its tokens carry the semantic classes, and the editor
// shows every character in the colour its kind had before the highlighter
// became pluggable (kind -> the editor theme's colour).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_dart_analysis/tom_dart_analysis.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart';

const _sample = r'''
@override
class Greeter<T> extends Base {
  final String name;
  Greeter(this.name, {int count = 1});
  /// Says hello.
  void greet(List<T> items) {
    for (final item in items) {
      print('Hello $name ${item.toString()}');
      items.length;
    }
    if (true) return null;
  }
}
''';

/// The colour the editor gave a kind before the highlighter was pluggable.
Color _colourOf(HighlightType type, DartEditorTheme theme) => switch (type) {
      HighlightType.plain => theme.syntax.plain,
      HighlightType.keyword => theme.syntax.keyword,
      HighlightType.builtInKeyword => theme.syntax.builtInKeyword,
      HighlightType.controlKeyword => theme.syntax.controlKeyword,
      HighlightType.string => theme.syntax.string,
      HighlightType.number => theme.syntax.number,
      HighlightType.comment => theme.syntax.comment,
      HighlightType.operator => theme.syntax.operator,
      HighlightType.punctuation => theme.syntax.punctuation,
      HighlightType.type => theme.syntax.type,
      HighlightType.className => theme.syntax.className,
      HighlightType.function => theme.syntax.function,
      HighlightType.methodCall => theme.syntax.methodCall,
      HighlightType.variable => theme.syntax.variable,
      HighlightType.parameter => theme.syntax.parameter,
      HighlightType.property => theme.syntax.property,
      HighlightType.constant => theme.syntax.constant,
      HighlightType.annotation => theme.syntax.annotation,
      HighlightType.thisKeyword => theme.syntax.thisKeyword,
      HighlightType.boolLiteral => theme.syntax.boolLiteral,
      HighlightType.nullLiteral => theme.syntax.nullLiteral,
      HighlightType.bracket0 => theme.brackets.colorForDepth(0),
      HighlightType.bracket1 => theme.brackets.colorForDepth(1),
      HighlightType.bracket2 => theme.brackets.colorForDepth(2),
      HighlightType.bracket3 => theme.brackets.colorForDepth(3),
      HighlightType.bracket4 => theme.brackets.colorForDepth(4),
      HighlightType.bracket5 => theme.brackets.colorForDepth(5),
    };

void main() {
  test('DSH-1: the tokens carry the semantic classes', () {
    final tokens = {
      for (final t in DartSyntaxHighlighter().tokenize(_sample))
        '${_sample.substring(t.start, t.end)}@${t.start}': t.type,
    };
    String classOf(String text, [int from = 0]) =>
        tokens['$text@${_sample.indexOf(text, from)}']!;
    expect(classOf('Greeter'), 'title.class');
    expect(classOf('greet'), 'title.function');
    expect(classOf('print'), 'title.function.invoke');
    expect(classOf('items'), 'params');
    expect(classOf('length'), 'property');
    expect(classOf('class'), 'keyword');
    expect(classOf('return'), 'keyword.control');
    expect(classOf('/// Says hello.'), 'comment');
    expect(classOf('{'), startsWith('punctuation.bracket.'));
  });

  test('DSH-2: the bracket pairs from its tokens are the analyzer\'s', () {
    final fromTokens = bracketPairsOf(
      _sample,
      DartSyntaxHighlighter().tokenize(_sample),
    );
    final fromAnalyzer = DartSyntaxHighlighter.extractBracketPairs(_sample);
    expect(
      [for (final p in fromTokens) (p.openOffset, p.closeOffset, p.type)],
      [for (final p in fromAnalyzer) (p.openOffset, p.closeOffset, p.type)],
    );
  });

  testWidgets(
      'DSH-3: plugged into the editor, every character has the '
      'colour of its kind', (tester) async {
    final controller = DartCodeController(initialCode: _sample);
    addTearDown(controller.dispose);
    final theme = DartEditorTheme.dark();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DartCodeEditor(
            controller: controller,
            theme: theme,
            highlighter: DartSyntaxHighlighter(),
            settings: const DartEditorSettings(showToolbar: false),
          ),
        ),
      ),
    );
    final field = find.byType(EditableText).first;
    final span = tester.widget<EditableText>(field).controller.buildTextSpan(
          context: tester.element(field),
          withComposing: false,
        );
    final shown = <Color?>[];
    final text = StringBuffer();
    span.visitChildren((s) {
      if (s is TextSpan && s.text != null) {
        text.write(s.text);
        shown.addAll(List.filled(s.text!.length, s.style?.color));
      }
      return true;
    });
    expect(text.toString(), _sample);

    final expected = List<Color?>.filled(_sample.length, theme.syntax.plain);
    for (final t in DartSyntaxHighlighter.tokenizeKinds(_sample)) {
      for (var i = t.offset; i < t.end && i < _sample.length; i++) {
        expected[i] = _colourOf(t.type, theme);
      }
    }
    expect(shown, expected);
  });

  testWidgets(
      'DSH-4: the summary-backed editor highlights semantically by '
      'default', (tester) async {
    final controller = DartCodeController(initialCode: 'void greet() {}');
    addTearDown(controller.dispose);
    final theme = DartEditorTheme.dark();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SummaryBackedDartCodeEditor(
            controller: controller,
            scope: 'does-not-exist',
            theme: theme,
            settings: const DartEditorSettings(showToolbar: false),
          ),
        ),
      ),
    );
    final field = find.byType(EditableText).first;
    final span = tester.widget<EditableText>(field).controller.buildTextSpan(
          context: tester.element(field),
          withComposing: false,
        );
    Color? greet;
    span.visitChildren((s) {
      if (s is TextSpan && s.text == 'greet') greet = s.style?.color;
      return true;
    });
    expect(greet, theme.syntax.function);
    await tester.pump(const Duration(seconds: 1));
  });
}

// Tests for SpecMarkdown's lightweight/rich routing
// (`tom_specs_editor_specification.md` §13 j/m, OE-3).
//
// SpecMarkdown keeps the lightweight inline renderer for the dozens of short
// labels/help strings and only pays the weight of tom_md_editor's
// MdPreviewPanel when the content actually uses rich features (fenced code,
// GFM tables, math, images). These tests pin that routing decision (the
// predicate) and verify the widget mounts the heavy panel only for rich input.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_md_editor/tom_md_editor.dart';

import 'package:tom_specs_editor/src/document/spec_markdown.dart';

void main() {
  group('isRichMarkdown', () {
    test('plain prose, headings, lists and inline spans are lightweight', () {
      expect(isRichMarkdown(''), isFalse);
      expect(isRichMarkdown('Just a label'), isFalse);
      expect(isRichMarkdown('# Heading\n\nA paragraph.'), isFalse);
      expect(isRichMarkdown('- item one\n- item two'), isFalse);
      expect(isRichMarkdown('Some **bold**, *italic* and `code`.'), isFalse);
      // Bare currency must not trip the math detector.
      expect(isRichMarkdown('It costs \$5 and \$10.'), isFalse);
    });

    test('fenced code, tables, math and images are rich', () {
      expect(isRichMarkdown('```dart\nvoid main() {}\n```'), isTrue);
      expect(
        isRichMarkdown('| a | b |\n| --- | --- |\n| 1 | 2 |'),
        isTrue,
      );
      expect(isRichMarkdown(r'Block: $$ a^2 + b^2 = c^2 $$'), isTrue);
      expect(isRichMarkdown(r'Inline $x_{i}$ math'), isTrue);
      expect(isRichMarkdown('![alt](image.png)'), isTrue);
    });
  });

  group('SpecMarkdown widget routing', () {
    testWidgets('plain text does not mount MdPreviewPanel', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SpecMarkdown('Just a label')),
      ));
      expect(find.byType(MdPreviewPanel), findsNothing);
      expect(find.text('Just a label'), findsOneWidget);
    });

    testWidgets('rich content mounts MdPreviewPanel', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SpecMarkdown('| a | b |\n| --- | --- |\n| 1 | 2 |'),
        ),
      ));
      await tester.pump();
      expect(find.byType(MdPreviewPanel), findsOneWidget);
    });
  });
}

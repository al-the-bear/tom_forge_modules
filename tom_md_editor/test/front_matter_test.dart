/// A file's leading YAML front matter is front matter, not a rule and a
/// setext heading: it is no section, not in the outline, does not hide the
/// schema comment after it, and the rendered view shows it verbatim.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_md_editor/src/models/md_front_matter.dart';
import 'package:tom_md_editor/tom_md_editor.dart';

const _doc = '''---
title: Garden overview
tags: [beds, water]
---
<!-- docspec: quest-overview/1.0 -->

# Garden Quest

The beds.

## Beds

South and north.
''';

void main() {
  group('MdFrontMatter.of', () {
    test('FM-1: finds the block on the first line, with its body and end', () {
      final fm = MdFrontMatter.of(_doc)!;
      expect(fm.body, 'title: Garden overview\ntags: [beds, water]');
      expect(_doc.substring(fm.end), startsWith('<!-- docspec'));
    });

    test('FM-2: a byte-order mark, CRLF and a `...` closer are read alike', () {
      final crlf = '﻿---\r\ntitle: A\r\n...\r\n# H\r\n';
      final fm = MdFrontMatter.of(crlf)!;
      expect(fm.body, 'title: A');
      expect(crlf.substring(fm.end), '# H\r\n');
    });

    test('FM-3: not front matter: a later rule, an unclosed opener, none', () {
      expect(MdFrontMatter.of('# H\n\n---\ntitle: x\n---\n'), isNull);
      expect(MdFrontMatter.of('---\ntitle: x\n# no closer\n'), isNull);
      expect(MdFrontMatter.of('plain text\n'), isNull);
      expect(MdFrontMatter.of(''), isNull);
    });

    test('FM-4: fence keeps the body verbatim, longer than its backticks', () {
      const withTicks = '---\nnote: "```x```"\n---\nText\n';
      final fenced = MdFrontMatter.fence(withTicks, infoString: 'frontmatter');
      expect(fenced, '````frontmatter\nnote: "```x```"\n````\n\nText\n');
      expect(MdFrontMatter.fence('# H\n', infoString: 'x'), '# H\n');
    });
  });

  group('MdParser', () {
    test(
      'FM-5: front matter is no section, and the schema after it is read',
      () {
        final doc = MdParser.parse(_doc);
        expect(doc.allSections.map((s) => s.headline), [
          'Garden Quest',
          'Beds',
        ]);
        expect(doc.title, 'Garden Quest');
        expect(doc.schemaId, 'quest-overview/1.0');
      },
    );
  });

  group('editing a section', () {
    test('FM-7: keeps the front matter and the schema comment above the first '
        'heading', () {
      final controller = MdEditorController()..replaceContent(_doc);
      addTearDown(controller.dispose);
      final beds = controller.document.allSections
          .firstWhere((s) => s.headline == 'Beds');

      controller.updateSectionText(beds, 'South, north and east.');

      expect(
        controller.markdown,
        startsWith(
          '---\ntitle: Garden overview\ntags: [beds, water]\n---\n'
          '<!-- docspec: quest-overview/1.0 -->\n\n# Garden Quest',
        ),
      );
      expect(controller.markdown, contains('South, north and east.'));
      expect(controller.document.schemaId, 'quest-overview/1.0');
    });
  });

  group('the rendered view', () {
    testWidgets('FM-6: shows the front matter verbatim and no heading for it', (
      tester,
    ) async {
      final controller = MdEditorController()..replaceContent(_doc);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdPreviewPanel(
              controller: controller,
              theme: MdEditorTheme.light(),
              settings: const MdEditorSettings(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('md-front-matter')), findsOneWidget);
      // The front matter's text is drawn once, inside the verbatim block,
      // and not as a heading beside it.
      final frontText = find.textContaining(
        'title: Garden overview',
        findRichText: true,
      );
      expect(frontText, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('md-front-matter')),
          matching: frontText,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Garden Quest', findRichText: true),
        findsWidgets,
      );
    });
  });
}

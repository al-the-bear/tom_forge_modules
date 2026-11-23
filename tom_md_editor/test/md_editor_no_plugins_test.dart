/// The editor core with no plugin package (R4): diagrams, math, DocSpecs and
/// review markup are shown as their Markdown, and nothing breaks.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_md_editor/tom_md_editor.dart';

const _doc = r'''<!-- docspec: quest-overview/1.0 -->
# Plain Document

Inline math $a+b$ in a sentence.

$$
E = mc^2
$$

```mermaid
flowchart TD
  A --> B
```

A {++new++} word and a {--gone--} one.

> ⬆️ **C-1** (alexis): Is this still true?

## Goals
<!-- id=GOAL-1 -->

Text of the goals.
''';

void main() {
  group('MD-NOPLUG the core without plugins', () {
    test('MD-NOPLUG-1: the default registry holds only the core plugins', () {
      final registry = createDefaultPluginRegistry(
        settings: MdEditorSettings.standard(),
      );
      expect(registry.all.map((p) => p.id), ['table', 'code']);
      expect(registry.forLanguage('mermaid'), isNull);
      expect(registry.forLanguage('math-display-0'), isNull);
    });

    test('MD-NOPLUG-2: a controller has no schema until one is attached', () {
      final controller = MdEditorController(initialMarkdown: _doc);
      addTearDown(controller.dispose);
      expect(controller.schemaSupport, isNull);
      expect(controller.hasSchema, isFalse);
      // The docspec comment is still read, only nothing validates it.
      expect(controller.schemaId, 'quest-overview/1.0');
      expect(controller.validationErrors, isEmpty);
    });

    testWidgets('MD-NOPLUG-3: the preview shows the plugins\' markup as text', (
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
              settings: MdEditorSettings.standard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The Mermaid fence is a code block with its source.
      expect(
        find.textContaining('flowchart TD', findRichText: true),
        findsWidgets,
      );
      // Math is its LaTeX source.
      expect(find.textContaining('E = mc^2', findRichText: true), findsWidgets);
      expect(find.textContaining(r'$a+b$', findRichText: true), findsWidgets);
      // Review markup and comments are text.
      expect(
        find.textContaining('{++new++}', findRichText: true),
        findsWidgets,
      );
      expect(
        find.textContaining('Is this still true?', findRichText: true),
        findsWidgets,
      );
      expect(
        find.textContaining('Text of the goals', findRichText: true),
        findsWidgets,
      );
    });

    testWidgets('MD-NOPLUG-4: the whole editor renders the document', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final controller = MdEditorController(initialMarkdown: _doc);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MdEditor(controller: controller)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(MdTreeView), findsOneWidget);
      expect(find.byType(MdPreviewPanel), findsOneWidget);
      expect(
        find.textContaining('flowchart TD', findRichText: true),
        findsWidgets,
      );
    });
  });
}

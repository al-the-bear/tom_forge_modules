import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_md_editor/tom_md_editor.dart';
import 'package:tom_md_mermaid/tom_md_mermaid.dart';
import 'package:tom_mermaid_view/tom_mermaid_view.dart';

void main() {
  group('Mermaid detection', () {
    test('detects mermaid code blocks', () {
      const md = '```mermaid\nflowchart TD\n  A-->B\n```';
      expect(containsMermaid(md), isTrue);
    });

    test('returns false for non-mermaid blocks', () {
      const md = '```dart\nvoid main() {}\n```';
      expect(containsMermaid(md), isFalse);
    });

    test('extracts mermaid sources', () {
      const md = '```mermaid\ngraph LR\n  A-->B\n```';
      final sources = extractMermaidSources(md);
      expect(sources, hasLength(1));
      expect(sources[0], contains('graph LR'));
    });
  });

  // ── Mermaid Detection Helpers ──

  group('Mermaid detection helpers', () {
    test('containsMermaid detects mermaid code block', () {
      const text = '```mermaid\nflowchart LR\n  A --> B\n```';
      expect(containsMermaid(text), isTrue);
    });

    test('containsMermaid returns false for non-mermaid blocks', () {
      const text = '```dart\nvoid main() {}\n```';
      expect(containsMermaid(text), isFalse);
    });

    test('extractMermaidSources returns diagram source', () {
      const text = '```mermaid\nflowchart LR\n  A --> B\n```';
      final sources = extractMermaidSources(text);
      expect(sources, hasLength(1));
      expect(sources.first, contains('flowchart LR'));
    });

    test('extractMermaidSources handles multiple blocks', () {
      const text = '''
```mermaid
sequenceDiagram
  Alice->>Bob: Hi
```

Some text

```mermaid
pie
  "A" : 30
  "B" : 70
```
''';
      final sources = extractMermaidSources(text);
      expect(sources, hasLength(2));
      expect(sources[0], contains('sequenceDiagram'));
      expect(sources[1], contains('pie'));
    });

    test('kMermaidDiagramTypes contains expected types', () {
      expect(kMermaidDiagramTypes, contains('flowchart'));
      expect(kMermaidDiagramTypes, contains('sequenceDiagram'));
      expect(kMermaidDiagramTypes, contains('pie'));
      expect(kMermaidDiagramTypes, contains('gantt'));
    });
  });

  // ── Mermaid Renderer Widget ──

  group('MdMermaidRenderer', () {
    testWidgets('renders with mermaid diagram', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdMermaidRenderer(
              source: 'flowchart LR\n  A --> B',
              theme: MdEditorTheme.dark(),
            ),
          ),
        ),
      );

      expect(find.text('Mermaid Diagram'), findsOneWidget);
      expect(find.byIcon(Icons.schema), findsOneWidget);
    });

    testWidgets('shows edit button when onEdit is provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdMermaidRenderer(
              source: 'pie\n  "A": 50\n  "B": 50',
              theme: MdEditorTheme.dark(),
              onEdit: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('toggles source panel', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdMermaidRenderer(
              source: 'flowchart LR\n  A --> B',
              theme: MdEditorTheme.dark(),
            ),
          ),
        ),
      );

      // Initially source is hidden
      expect(find.byIcon(Icons.code), findsOneWidget);
      expect(find.byIcon(Icons.code_off), findsNothing);

      // Tap to show source
      await tester.tap(find.byIcon(Icons.code));
      await tester.pump();

      expect(find.byIcon(Icons.code_off), findsOneWidget);
    });
  });

  group('MD-MERM the Mermaid plugin', () {
    const doc = '# Diagram\n\n```mermaid\nflowchart TD\n  A --> B\n```\n';

    Future<void> pumpPreview(
      WidgetTester tester, {
      List<MdContentPlugin> plugins = const [],
    }) async {
      final controller = MdEditorController()..replaceContent(doc);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdPreviewPanel(
              controller: controller,
              theme: MdEditorTheme.light(),
              settings: MdEditorSettings.standard(),
              plugins: plugins,
            ),
          ),
        ),
      );
      // The webview keeps scheduling frames: a bounded pump, no settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    test('MD-MERM-1: it follows the enableMermaid setting', () {
      final plugin = mdMermaidPlugin();
      expect(plugin.id, 'mermaid');
      expect(plugin.isEnabledBy(MdEditorSettings.standard()), isTrue);
      expect(
        plugin.isEnabledBy(
          MdEditorSettings.standard().copyWith(enableMermaid: false),
        ),
        isFalse,
      );
      final registry = createDefaultPluginRegistry(plugins: [plugin]);
      expect(registry.forLanguage('mermaid'), same(plugin));
    });

    testWidgets('MD-MERM-2: with the plugin, a mermaid fence is a diagram', (
      tester,
    ) async {
      await pumpPreview(tester, plugins: [mdMermaidPlugin()]);
      expect(tester.takeException(), isNull);
      expect(find.byType(MermaidWebView), findsOneWidget);
    });

    testWidgets('MD-MERM-3: without the plugin, it is a code block', (
      tester,
    ) async {
      await pumpPreview(tester);
      expect(find.byType(MermaidWebView), findsNothing);
      expect(
        find.textContaining('flowchart TD', findRichText: true),
        findsWidgets,
      );
    });
  });

  testWidgets(
    'BR-8: a mermaid fence is drawn as a diagram (read-only preview)',
    (tester) async {
      final c = MdEditorController(
        initialMarkdown: '# D\n\n```mermaid\nflowchart TD\n  A-->B\n```\n',
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdPreviewPanel(
              controller: c,
              theme: MdEditorTheme.light(),
              settings: const MdEditorSettings(readOnly: true),
              plugins: [mdMermaidPlugin()],
            ),
          ),
        ),
      );
      await tester.pump();
      final view = tester.widget<MermaidWebView>(find.byType(MermaidWebView));
      expect(view.source.trim(), 'flowchart TD\n  A-->B');
    },
  );
}

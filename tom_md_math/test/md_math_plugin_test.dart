import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_md_editor/tom_md_editor.dart';
import 'package:tom_md_math/tom_md_math.dart';

Future<void> _pumpPreview(
  WidgetTester tester,
  String markdown, {
  MdEditorSettings? settings,
  List<MdContentPlugin> plugins = const [],
}) async {
  final controller = MdEditorController()..replaceContent(markdown);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MdPreviewPanel(
          controller: controller,
          theme: MdEditorTheme.light(),
          settings: settings ?? MdEditorSettings.standard(),
          plugins: plugins,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Math detection', () {
    test('detects inline math', () {
      expect(containsInlineMath(r'The formula $E=mc^2$ is famous.'), isTrue);
      expect(containsInlineMath('No math here'), isFalse);
    });

    test('detects block math', () {
      expect(containsBlockMath(r'$$\sum_{i=1}^n i$$'), isTrue);
      expect(containsBlockMath('No block math'), isFalse);
    });

    test('extracts inline math expressions', () {
      final results = extractInlineMath(r'Both $a+b$ and $x^2$ here.');
      expect(results, hasLength(2));
      expect(results[0], 'a+b');
      expect(results[1], 'x^2');
    });

    test('extracts block math expressions', () {
      final results = extractBlockMath(r'$$\int_0^1 x\,dx$$');
      expect(results, hasLength(1));
      expect(results[0], contains('int'));
    });
  });

  group('MD-MATH the math plugin', () {
    const doc = 'Inline \$a+b\$ here.\n\n\$\$\nE = mc^2\n\$\$\n';

    test('MD-MATH-1: it follows the enableMath setting', () {
      final plugin = mdMathPlugin();
      expect(plugin.id, 'math');
      expect(plugin.isEnabledBy(MdEditorSettings.standard()), isTrue);
      expect(
        plugin.isEnabledBy(
          MdEditorSettings.standard().copyWith(enableMath: false),
        ),
        isFalse,
      );
      final off = createDefaultPluginRegistry(
        settings: MdEditorSettings.standard().copyWith(enableMath: false),
        plugins: [plugin],
      );
      expect(off.forId('math'), isNull);
      final on = createDefaultPluginRegistry(plugins: [plugin]);
      expect(on.all.map((p) => p.id), ['table', 'math', 'code']);
      expect(on.forLanguage('math-display-0'), same(plugin));
    });

    testWidgets('MD-MATH-2: with the plugin, display and inline math render', (
      tester,
    ) async {
      await _pumpPreview(tester, doc, plugins: [mdMathPlugin()]);
      expect(tester.takeException(), isNull);
      // One display formula and one inline formula.
      expect(find.byType(Math), findsNWidgets(2));
    });

    testWidgets('MD-MATH-3: without the plugin, math stays its source', (
      tester,
    ) async {
      await _pumpPreview(tester, doc);
      expect(find.byType(Math), findsNothing);
      expect(find.textContaining('E = mc^2', findRichText: true), findsWidgets);
    });
  });
}

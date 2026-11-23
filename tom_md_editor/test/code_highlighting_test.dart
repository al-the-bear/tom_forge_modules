// Code blocks are highlighted through tom_text_highlight: the overlay's
// code_text_field controller and the preview take the same highlighters,
// styled by MdCodeHighlighting.buildTheme.
import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_md_editor/src/utils/md_code_highlighting.dart';
import 'package:tom_md_editor/tom_md_editor.dart';

void main() {
  test('MD-HL1: the languages tom_text_highlight knows get a highlighter, '
      'others none', () {
    final basic = MdEditorTheme.light().basic;
    for (final language in ['yaml', 'yml', 'json', 'sh', 'bash', 'md', 'env']) {
      expect(
        MdCodeHighlighting.highlighterFor(language, basic),
        isNotNull,
        reason: language,
      );
    }
    for (final language in ['python', 'dart', null, '']) {
      expect(
        MdCodeHighlighting.highlighterFor(language, basic),
        isNull,
        reason: '$language',
      );
    }
  });

  testWidgets('MD-HL2: the overlay highlights a YAML block in the code '
      'theme\'s colours', (tester) async {
    final theme = MdEditorTheme.light();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MdCodeBlockOverlay(
            code: 'key: "v"\nn: 3',
            language: 'yaml',
            theme: theme,
            onSave: (_, _) {},
          ),
        ),
      ),
    );
    final field = tester.widget<CodeField>(find.byType(CodeField));
    final span = field.controller.buildTextSpan(
      context: tester.element(find.byType(CodeField)),
      withComposing: false,
    );
    final styles = <String, TextStyle?>{};
    span.visitChildren((s) {
      if (s is TextSpan && s.text != null) styles[s.text!] = s.style;
      return true;
    });
    final codeTheme = MdCodeHighlighting.buildTheme(theme.basic);
    expect(styles['key'], codeTheme['attr']);
    expect(styles['"v"'], codeTheme['string']);
    expect(styles['3'], codeTheme['number']);
  });
}

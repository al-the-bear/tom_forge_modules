/// The pdf.js editor at the narrowest size an application lays an editor
/// out at (`sizeHints.minSize`): nothing overflows. Overflow errors are not
/// suppressed here: one fails the test.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

import 'support/workspace.dart';

Future<void> _showAt(WidgetTester tester, ForgeEditor editor, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: size,
            child: Builder(builder: editor.buildMain),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('FPDFJS-NARROW-1: the pdf.js editor fits its minimum size', (
    tester,
  ) async {
    final w = Workspace();
    final a = w.add('/docs/a.pdf');
    final js = w.openJs(a);
    await _showAt(tester, js, js.sizeHints.minSize);
    expect(tester.takeException(), isNull);
  });
}

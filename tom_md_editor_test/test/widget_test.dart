// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:tom_md_editor_test/main.dart';

void main() {
  testWidgets('Demo app renders', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MdEditorDemoApp());
    // WebView-backed widgets may keep scheduling frames in tests,
    // so avoid pumpAndSettle() and use a bounded pump window.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tom Markdown Editor'), findsOneWidget);
  });
}

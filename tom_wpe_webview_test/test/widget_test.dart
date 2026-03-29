// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:tom_wpe_webview_test/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Probe catalog is present', () {
    expect(ProbeKind.values.length, 5);
    expect(ProbeKind.remoteExample.label, contains('example.com'));
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:tom_dart_editor_test/main.dart';

void main() {
  testWidgets('App renders editor shell', (WidgetTester tester) async {
    // The pump runs inside `runAsync` on purpose. Mounting the editor starts an
    // `AnalysisDriverScheduler`, and that class has `start()` but no `stop()` —
    // its pump loop reschedules itself for as long as the process lives. That is
    // deliberate upstream: the scheduler is shared per summary scope and is
    // meant to outlive individual editors, so it is not a leak to fix here.
    //
    // Under the default fake-async clock those pumps become `FakeTimer`s, and
    // the binding's end-of-test `!timersPending` assertion then fails on a
    // scheduler that is behaving exactly as designed. `runAsync` gives the pump
    // real timers, which the assertion does not count.
    await tester.runAsync(() async {
      await tester.pumpWidget(const DartAnalyzerApp());
    });
    expect(find.text('Dart Editor Test App'), findsOneWidget);
  });
}

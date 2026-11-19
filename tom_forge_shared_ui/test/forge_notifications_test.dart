/// The notification toasts and their history in the shared package, over
/// tom_forge_core's DefaultNotificationManager.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart';

Future<DefaultNotificationManager> _pumpToasts(WidgetTester tester) async {
  final manager = DefaultNotificationManager();
  await tester.pumpWidget(
    MaterialApp(
      theme: forgeThemeData(Brightness.dark),
      home: Scaffold(
        body: Stack(children: [ForgeNotificationOverlay(manager: manager)]),
      ),
    ),
  );
  return manager;
}

void main() {
  testWidgets('FNO-1: a toast without actions shows and auto-dismisses after '
      '4 s', (tester) async {
    final manager = await _pumpToasts(tester);
    final answer = manager.showInformation('Saved');
    await tester.pump();
    expect(find.text('Saved'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 3900));
    expect(find.text('Saved'), findsOneWidget, reason: 'not yet 4 s');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Saved'), findsNothing);
    expect(await answer, isNull);
  });

  testWidgets('FNO-2: a toast with actions stays, answers the chosen action '
      'and leaves the screen', (tester) async {
    final manager = await _pumpToasts(tester);
    final answer = manager.showWarning(
      'File changed on disk',
      actions: ['Reload', 'Keep mine'],
    );
    await tester.pump();
    expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('File changed on disk'), findsOneWidget, reason: 'stays');

    await tester.tap(find.text('Keep mine'));
    await tester.pump();
    expect(await answer, 'Keep mine');
    expect(find.text('File changed on disk'), findsNothing);
  });

  testWidgets('FNO-3: the close button dismisses a toast, answering null', (
    tester,
  ) async {
    final manager = await _pumpToasts(tester);
    final answer = manager.showError('Build failed', actions: ['Show']);
    await tester.pump();
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(find.text('Build failed'), findsNothing);
    expect(await answer, isNull);
  });

  testWidgets('FNO-4: the popup lists the history, newest first, with '
      'severity icons, and clears it', (tester) async {
    final manager = DefaultNotificationManager();
    var closed = 0;
    manager.showInformation('first', actions: ['OK']);
    manager.showWarning('second', actions: ['OK']);
    manager.showError('third', actions: ['OK']);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForgeNotificationPopup(
            manager: manager,
            onClose: () => closed++,
          ),
        ),
      ),
    );
    expect(find.text('Notifications'), findsOneWidget);
    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(y('third'), lessThan(y('second')));
    expect(y('second'), lessThan(y('first')));
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_sweep));
    await tester.pump();
    expect(find.text('No notifications'), findsOneWidget);
    expect(manager.history.value, isEmpty);

    await tester.tap(find.byIcon(Icons.close));
    expect(closed, 1);
  });
}

/// The shared status bar: items by alignment and priority, shown while
/// visible, rebuilt on demand, with a progress message and items of their
/// own.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart';

ValueListenable<String> _text(String s) => ForgeFixedListenable(s);

Future<void> _pump(WidgetTester tester, Widget bar) => tester.pumpWidget(
  MaterialApp(
    theme: forgeThemeData(Brightness.dark),
    home: Scaffold(bottomNavigationBar: bar),
  ),
);

void main() {
  testWidgets('FSB-1: left, centre and right, higher priority first, in the '
      "theme's status bar colour", (tester) async {
    await _pump(
      tester,
      ForgeStatusBar(
        items: [
          ForgeStatusItem(text: _text('L1'), priority: 1),
          ForgeStatusItem(text: _text('L2'), priority: 2),
          ForgeStatusItem(
            text: _text('R'),
            alignment: StatusBarAlignment.right,
          ),
          ForgeStatusItem(
            text: _text('C'),
            alignment: StatusBarAlignment.center,
          ),
        ],
      ),
    );
    double x(String t) => tester.getTopLeft(find.text(t)).dx;
    expect(x('L2'), lessThan(x('L1')));
    expect(x('L1'), lessThan(x('C')));
    expect(x('C'), lessThan(x('R')));
    final bar = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(ForgeStatusBar),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(bar.color, ForgeShellTheme.dark().statusBarBackground);
    expect(tester.getSize(find.byType(ForgeStatusBar)).height, 24);
  });

  testWidgets('FSB-2: an item is shown while visible, and the bar rebuilds '
      'when that changes', (tester) async {
    final visible = ValueNotifier(false);
    await _pump(
      tester,
      ForgeStatusBar(
        items: [ForgeStatusItem(text: _text('sync'), visible: visible)],
      ),
    );
    expect(find.text('sync'), findsNothing);
    visible.value = true;
    await tester.pump();
    expect(find.text('sync'), findsOneWidget);
  });

  testWidgets('FSB-3: the rebuild listenable re-reads the items', (
    tester,
  ) async {
    final items = <ForgeStatusItem>[];
    final changed = ValueNotifier(0);
    await _pump(tester, ForgeStatusBar(items: items, rebuild: changed));
    items.add(ForgeStatusItem(text: _text('added')));
    changed.value++;
    await tester.pump();
    expect(find.text('added'), findsOneWidget);
  });

  testWidgets('FSB-4: the progress message, a builder item, colour and '
      'emphasis', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      ForgeStatusBar(
        progressMessage: 'Indexing: 3 of 9',
        items: [
          ForgeStatusItem(
            text: _text('unused'),
            onTap: () => taps++,
            builder: (context, foreground) => Chip(
              key: const ValueKey('countdown'),
              label: Text('0:42', style: TextStyle(color: foreground)),
            ),
          ),
          ForgeStatusItem(
            text: _text('Offline'),
            color: const Color(0xFFFF0000),
            emphasis: true,
            alignment: StatusBarAlignment.right,
          ),
        ],
      ),
    );
    expect(find.text('Indexing: 3 of 9'), findsOneWidget);
    expect(find.byKey(const ValueKey('countdown')), findsOneWidget);
    expect(find.text('unused'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('countdown')));
    expect(taps, 1);
    final offline = tester.widget<Text>(find.text('Offline'));
    expect(offline.style!.color, const Color(0xFFFF0000));
    expect(offline.style!.fontWeight, FontWeight.bold);
  });
}

/// The shared action bar: groups of icon buttons that follow their
/// enablement, divided, with the buttons that do not fit in an overflow menu.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart';

Future<void> _pump(
  WidgetTester tester,
  List<ForgeActionGroup> groups, {
  double? width,
}) async {
  final bar = ForgeActionBar(groups: groups);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: width == null
              ? Row(children: [bar])
              : SizedBox(width: width, child: bar),
        ),
      ),
    ),
  );
}

Finder _button(String id) => find.byKey(ValueKey('forge.actionBar.$id'));

void main() {
  late List<String> invoked;
  late ValueNotifier<bool> canPaste;
  late List<ForgeActionGroup> groups;

  setUp(() {
    invoked = [];
    canPaste = ValueNotifier(false);
    ForgeActionItem item(
      String id,
      IconData icon, {
      ValueListenable<bool>? enabled,
      String? shortcut,
    }) => ForgeActionItem(
      id: id,
      icon: icon,
      label: id,
      shortcut: shortcut,
      enabled: enabled ?? const ForgeFixedListenable(true),
      onInvoke: () => invoked.add(id),
    );
    groups = [
      ForgeActionGroup(
        id: 'file',
        items: [item('new', Icons.add), item('open', Icons.folder_open)],
      ),
      ForgeActionGroup(
        id: 'edit',
        items: [
          item('copy', Icons.copy, shortcut: '⌘C'),
          item('paste', Icons.paste, enabled: canPaste),
        ],
      ),
    ];
  });

  testWidgets('FAB-1: every item is a button, groups are divided, a tap '
      'invokes the action', (tester) async {
    await _pump(tester, groups);
    for (final id in ['new', 'open', 'copy', 'paste']) {
      expect(_button(id), findsOneWidget, reason: id);
    }
    expect(find.byType(VerticalDivider), findsOneWidget);
    expect(
      find.byKey(const ValueKey('forge.actionBar.overflow')),
      findsNothing,
    );
    await tester.tap(_button('copy'));
    expect(invoked, ['copy']);
    expect(
      find.byWidgetPredicate((w) => w is Tooltip && w.message == 'copy\n⌘C'),
      findsOneWidget,
    );
  });

  testWidgets('FAB-2: a button follows its enablement', (tester) async {
    await _pump(tester, groups);
    await tester.tap(_button('paste'));
    expect(invoked, isEmpty, reason: 'disabled');
    canPaste.value = true;
    await tester.pump();
    await tester.tap(_button('paste'));
    expect(invoked, ['paste']);
  });

  testWidgets('FAB-3: the buttons that do not fit go into the overflow menu, '
      'in order', (tester) async {
    const bar = ForgeActionBar(groups: []);
    // Room for two buttons and the overflow button.
    await _pump(tester, groups, width: bar.buttonExtent * 3 + 1);
    expect(_button('new'), findsOneWidget);
    expect(_button('open'), findsOneWidget);
    expect(_button('copy'), findsNothing);
    final overflow = find.byKey(const ValueKey('forge.actionBar.overflow'));
    expect(overflow, findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'no overflow error');

    await tester.tap(overflow);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('forge.actionBar.overflow.copy')),
      findsOneWidget,
    );
    final paste = tester.widget<PopupMenuItem<ForgeActionItem>>(
      find.byKey(const ValueKey('forge.actionBar.overflow.paste')),
    );
    expect(paste.enabled, isFalse);
    await tester.tap(
      find.byKey(const ValueKey('forge.actionBar.overflow.copy')),
    );
    await tester.pumpAndSettle();
    expect(invoked, ['copy']);
  });

  testWidgets('FAB-4: an empty bar takes no space', (tester) async {
    await _pump(tester, const [ForgeActionGroup(id: 'none', items: [])]);
    expect(find.byType(LayoutBuilder), findsNothing);
  });
}

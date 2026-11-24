/// The context menu rendering in the shared package: entries in order,
/// dividers between groups, the disabled reason, the chosen entry runs,
/// nothing for no entries; checkmarks and submenus.
library;

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart';

void main() {
  late List<String> ran;

  ForgeContextMenuEntry entry(
    String id, {
    String? group,
    bool enabled = true,
    String? reason,
  }) => ForgeContextMenuEntry(
    id: id,
    label: 'Label $id',
    enabled: enabled,
    unavailableReason: reason,
    group: group,
    run: () async => ran.add(id),
  );

  setUp(() => ran = []);

  Future<void> open(
    WidgetTester tester,
    List<ForgeContextMenuEntry> entries,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => GestureDetector(
              key: const ValueKey('surface'),
              behavior: HitTestBehavior.opaque,
              onSecondaryTapUp: (details) => showForgeContextMenuEntries(
                context,
                entries: entries,
                globalPosition: details.globalPosition,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('surface')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
  }

  test('FCM-1: entries in order, a divider where the group changes', () {
    final items = forgeContextMenuItems([
      entry('a', group: 'edit'),
      entry('b', group: 'edit'),
      entry('c', group: 'file'),
      entry('d'),
      entry('e', group: 'file'),
      entry('f', group: 'view'),
    ]);
    expect(
      items.map(
        (i) => i is PopupMenuDivider ? '|' : (i.key! as ValueKey<String>).value,
      ),
      [
        'forge-context-menu:a',
        'forge-context-menu:b',
        '|',
        'forge-context-menu:c',
        'forge-context-menu:d',
        'forge-context-menu:e',
        '|',
        'forge-context-menu:f',
      ],
    );
    expect(forgeContextMenuEntryKey('x'), const Key('forge-context-menu:x'));
  });

  testWidgets('FCM-2: the menu is drawn at the pointer and the chosen entry '
      'runs', (tester) async {
    await open(tester, [
      entry('copy', group: 'edit'),
      entry('open', group: 'file'),
    ]);
    expect(find.text('Label copy'), findsOneWidget);
    expect(find.byType(PopupMenuDivider), findsOneWidget);
    await tester.tap(find.byKey(forgeContextMenuEntryKey('open')));
    await tester.pumpAndSettle();
    expect(ran, ['open']);
    expect(find.text('Label copy'), findsNothing, reason: 'menu closed');
  });

  testWidgets('FCM-3: a disabled entry carries its reason and does not run', (
    tester,
  ) async {
    await open(tester, [
      entry('paste', enabled: false, reason: 'Nothing to paste'),
    ]);
    final item = tester.widget<PopupMenuItem<ForgeContextMenuEntry>>(
      find.byKey(forgeContextMenuEntryKey('paste')),
    );
    expect(item.enabled, isFalse);
    expect(
      find.byWidgetPredicate(
        (w) => w is Tooltip && w.message == 'Nothing to paste',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Label paste'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(ran, isEmpty);
  });

  testWidgets('FCM-4: nothing is drawn for no entries', (tester) async {
    await open(tester, const []);
    expect(find.byType(PopupMenuItem<ForgeContextMenuEntry>), findsNothing);
  });
  testWidgets('FCM-5: a submenu entry opens its children beside it; the '
      'chosen child runs, the submenu entry does not', (tester) async {
    final sub = ForgeContextMenuEntry(
      id: 'openWith',
      label: 'Open With',
      enabled: true,
      run: () async => ran.add('openWith'),
      children: [
        ForgeContextMenuEntry(
          id: 'md',
          label: 'Markdown',
          enabled: true,
          checked: true,
          run: () async => ran.add('md'),
        ),
        ForgeContextMenuEntry(
          id: 'text',
          label: 'Plain text',
          enabled: true,
          checked: false,
          run: () async => ran.add('text'),
        ),
      ],
    );
    await open(tester, [entry('copy'), sub]);
    expect(find.byIcon(Icons.arrow_right), findsOneWidget);
    expect(find.text('Markdown'), findsNothing);
    final row = tester.getRect(
      find.byKey(forgeContextMenuEntryKey('openWith')),
    );

    await tester.tap(find.byKey(forgeContextMenuEntryKey('openWith')));
    await tester.pumpAndSettle();
    expect(find.text('Label copy'), findsNothing, reason: 'parent closed');
    expect(find.text('Markdown'), findsOneWidget);
    // Beside the row it was chosen from: on its right, where there is room.
    final child = tester.getRect(find.byKey(forgeContextMenuEntryKey('md')));
    expect(child.left, closeTo(row.right, 16));
    expect(child.top, closeTo(row.top, 24));
    // The checkmark on the checked entry only.
    expect(find.byKey(forgeContextMenuCheckKey('md')), findsOneWidget);
    expect(find.byKey(forgeContextMenuCheckKey('text')), findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.tap(find.text('Plain text'));
    await tester.pumpAndSettle();
    expect(ran, ['text']);
    expect(find.text('Markdown'), findsNothing, reason: 'submenu closed');
  });

  test('FCM-6: an entry neither checkable nor a submenu is drawn as its '
      'label alone', () {
    final items = forgeContextMenuItems([entry('a'), entry('b', reason: 'r')]);
    final plain = items.first as PopupMenuItem<ForgeContextMenuEntry>;
    expect(plain.child, isA<Text>());
    expect(plain.onTap, isNull);
    final disabled = items.last as PopupMenuItem<ForgeContextMenuEntry>;
    expect((disabled.child! as Tooltip).child, isA<Text>());
    expect(entry('a').hasChildren, isFalse);
    expect(entry('a').checked, isNull);
  });
}

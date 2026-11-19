import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart';
import 'package:tom_forge_shared_ui_example/main.dart';

void main() {
  testWidgets('the example follows the platform brightness', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(const SharedUiExampleApp());
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, ForgeShellTheme.dark().panelSurface);
  });

  testWidgets('the action bar drives the status bar', (tester) async {
    await tester.pumpWidget(const SharedUiExampleApp());
    expect(find.text('0 items'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('forge.actionBar.remove')));
    await tester.pump();
    expect(find.text('0 items'), findsOneWidget, reason: 'remove disabled');
    await tester.tap(find.byKey(const ValueKey('forge.actionBar.add')));
    await tester.tap(find.byKey(const ValueKey('forge.actionBar.add')));
    await tester.pump();
    expect(find.text('2 items'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('forge.actionBar.remove')));
    await tester.pump();
    expect(find.text('1 items'), findsOneWidget);

    expect(find.text('Working'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('forge.actionBar.work')));
    await tester.pump();
    expect(find.text('Working'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Working'), findsNothing);
  });

  testWidgets('the input box renames, the quick pick sets the count', (
    tester,
  ) async {
    await tester.pumpWidget(const SharedUiExampleApp());
    expect(find.text('Untitled'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('forge.actionBar.rename')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('forge-input-box-field')),
      'Notes',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Notes'), findsOneWidget);
    expect(find.byType(ForgeInputBoxOverlay), findsNothing);

    await tester.tap(find.byKey(const ValueKey('forge.actionBar.pick')));
    await tester.pump();
    await tester.tap(find.text('Ten'));
    await tester.pump();
    expect(find.text('10 items'), findsOneWidget);
    expect(find.byType(ForgeQuickPickOverlay<int>), findsNothing);
  });

  testWidgets('a toast from the action bar, its action resets the count', (
    tester,
  ) async {
    await tester.pumpWidget(const SharedUiExampleApp());
    await tester.tap(find.byKey(const ValueKey('forge.actionBar.add')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('forge.actionBar.notify')));
    await tester.pump();
    expect(find.text('1 items so far'), findsOneWidget);
    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(find.text('1 items so far'), findsNothing);
    expect(find.text('0 items'), findsOneWidget);
  });

  testWidgets('a right-click on the panel opens its context menu', (
    tester,
  ) async {
    await tester.pumpWidget(const SharedUiExampleApp());
    await tester.tap(
      find.byKey(const ValueKey('example.panel')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    final remove = tester.widget<PopupMenuItem<ForgeContextMenuEntry>>(
      find.byKey(forgeContextMenuEntryKey('remove')),
    );
    expect(remove.enabled, isFalse, reason: 'no items yet');
    expect(find.byType(PopupMenuDivider), findsOneWidget);
    await tester.tap(find.byKey(forgeContextMenuEntryKey('add')));
    await tester.pumpAndSettle();
    expect(find.text('1 items'), findsOneWidget);
  });
}

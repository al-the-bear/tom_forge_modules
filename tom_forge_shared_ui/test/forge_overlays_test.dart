/// The shell's overlays and dialogs in the shared package: the input box,
/// the quick pick, the error recovery dialog and the focus indicator.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: forgeThemeData(Brightness.dark),
    home: Scaffold(body: child),
  ),
);

void main() {
  group('ForgeInputBoxOverlay', () {
    testWidgets('FOV-1: Enter answers the text, prefilled and selected', (
      tester,
    ) async {
      final done = Completer<String?>();
      await _pump(
        tester,
        ForgeInputBoxOverlay(
          prompt: 'New name',
          value: 'draft',
          placeholder: 'name',
          completer: done,
        ),
      );
      expect(find.text('New name'), findsOneWidget);
      final field = find.byKey(const Key('forge-input-box-field'));
      final text = tester.widget<TextField>(field).controller!;
      expect(text.text, 'draft');
      expect(
        text.selection,
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );
      await tester.enterText(field, 'final');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(await done.future, 'final');
    });

    testWidgets('FOV-2: an invalid value is refused with its message', (
      tester,
    ) async {
      final done = Completer<String?>();
      await _pump(
        tester,
        ForgeInputBoxOverlay(
          validateInput: (v) => v.isEmpty ? 'Required' : null,
          completer: done,
        ),
      );
      final field = find.byKey(const Key('forge-input-box-field'));
      await tester.enterText(field, '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(done.isCompleted, isFalse);
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('FOV-3: Escape answers null', (tester) async {
      final done = Completer<String?>();
      await _pump(tester, ForgeInputBoxOverlay(completer: done));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(done.isCompleted, isTrue);
      expect(await done.future, isNull);
    });
  });

  group('ForgeQuickPickOverlay', () {
    const items = [
      ForgeQuickPickItem(label: 'Apple', value: 1, description: 'fruit'),
      ForgeQuickPickItem(label: 'Carrot', value: 2, description: 'vegetable'),
      ForgeQuickPickItem(label: 'Banana', value: 3),
    ];

    testWidgets('FOV-4: a tap answers the item value', (tester) async {
      final done = Completer<int?>();
      await _pump(
        tester,
        ForgeQuickPickOverlay<int>(items: items, completer: done),
      );
      expect(find.text('Select an item...'), findsOneWidget);
      await tester.tap(find.text('Carrot'));
      expect(await done.future, 2);
    });

    testWidgets('FOV-5: typing filters by label and description, Enter takes '
        'the first match', (tester) async {
      final done = Completer<int?>();
      await _pump(
        tester,
        ForgeQuickPickOverlay<int>(
          items: items,
          placeholder: 'Pick one',
          completer: done,
        ),
      );
      await tester.enterText(find.byType(TextField), 'veg');
      await tester.pump();
      expect(find.text('Carrot'), findsOneWidget);
      expect(find.text('Apple'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(await done.future, 2);
    });

    testWidgets('FOV-6: arrows move the highlight, Escape answers null', (
      tester,
    ) async {
      final down = Completer<int?>();
      await _pump(
        tester,
        ForgeQuickPickOverlay<int>(items: items, completer: down),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(await down.future, 2);

      final esc = Completer<int?>();
      await _pump(
        tester,
        ForgeQuickPickOverlay<int>(
          key: const ValueKey('second'),
          items: items,
          completer: esc,
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(await esc.future, isNull);
    });
  });

  group('ForgeErrorRecoveryDialog', () {
    Future<Future<ErrorRecoveryAction?>> open(
      WidgetTester tester, {
      bool showOverwrite = false,
    }) async {
      late Future<ErrorRecoveryAction?> answer;
      await _pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => answer = ForgeErrorRecoveryDialog.show(
              context,
              title: 'Save failed',
              message: 'The file changed on disk.',
              showOverwrite: showOverwrite,
            ),
            child: const Text('save'),
          ),
        ),
      );
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      return answer;
    }

    testWidgets('FOV-7: retry and cancel, no overwrite unless asked for', (
      tester,
    ) async {
      final answer = await open(tester);
      expect(find.text('Save failed'), findsOneWidget);
      expect(find.text('The file changed on disk.'), findsOneWidget);
      expect(find.text('Overwrite'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(await answer, ErrorRecoveryAction.retry);
    });

    testWidgets('FOV-8: overwrite when offered', (tester) async {
      final answer = await open(tester, showOverwrite: true);
      await tester.tap(find.text('Overwrite'));
      await tester.pumpAndSettle();
      expect(await answer, ErrorRecoveryAction.overwrite);
    });
  });

  testWidgets('FOV-9: the focus ring shows for keyboard focus only, in the '
      "theme's focus colour", (tester) async {
    await _pump(
      tester,
      const ForgeFocusIndicator(child: SizedBox(width: 40, height: 40)),
    );
    BoxDecoration decoration() =>
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byType(ForgeFocusIndicator),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(decoration().border, isNull);

    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final border = decoration().border as Border?;
    expect(border, isNotNull);
    expect(border!.top.color, ForgeShellTheme.dark().focusRing);
  });
}

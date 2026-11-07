/// The plain value fields on the document's history (qim_none-6).
///
/// A content field without a code scope, a form field and a headline field
/// type through the controller (`typeContent`, `typeFormField`,
/// `typeHeadline`): a word typed keystroke by keystroke is one undo entry —
/// and, for content and form fields, one change-log entry — ended by the
/// typing pause, a caret move, a blur or Enter. Undo and redo keys in a field
/// undo the document, never the field alone (`editor_history_contract.md`
/// §1, §4).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show forgeTypingPause;
import 'package:tom_forge_agentic/tom_forge_agentic.dart' show ChangeKind;

import 'package:tom_specs_editor/src/document/spec_document_controller.dart';
import 'package:tom_specs_editor/src/document/spec_document_editor.dart';
import 'package:tom_specs_editor/src/structure/spec_model.dart';
import 'support/review_store_support.dart';

const _overview = 'D00/D00-OVR';
const _header = 'D00/D00-HDR';

Map<String, dynamic> _json() => {
  'roots': [
    {'type': 'DemoDoc', 'title': 'Demo Document', 'sectionId': 'D00'},
  ],
  'classes': {
    'DemoDoc': {
      'name': 'DemoDoc',
      'sectionId': 'D00',
      'fields': [
        {
          'name': 'overview',
          'kind': 'content',
          'sectionId': 'D00-OVR',
          'headline': 'Overview Heading',
        },
        {
          'name': 'header',
          'kind': 'form',
          'sectionId': 'D00-HDR',
          'formFields': [
            {'name': 'author', 'label': 'Author', 'type': 'String'},
          ],
        },
        {
          'name': 'items',
          'kind': 'list',
          'elementType': 'DemoItem',
          'elementIsComplex': true,
          'sectionId': 'D00-ITM',
          'sectionIdPattern': 'D01.N',
        },
      ],
    },
    'DemoItem': {
      'name': 'DemoItem',
      'headline': 'Item Entry',
      'fields': [
        {'name': 'label', 'kind': 'scalar', 'type': 'String'},
      ],
    },
  },
};

Future<SpecDocumentController> _controller() async {
  final controller = SpecDocumentController(
    modelFuture: Future<SpecModel>.value(SpecModel.fromJson(_json())),
    review: memoryReviewStore(),
    strictHeadlineEditing: false,
  );
  await controller.ensureLoaded();
  addTearDown(controller.dispose);
  return controller;
}

Future<void> _pump(WidgetTester tester, SpecDocumentController controller) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpecDocumentTree(
            controller: controller,
            model: controller.model,
          ),
        ),
      ),
    );

Finder _fieldOf(Finder keyed) =>
    find.descendant(of: keyed, matching: find.byType(TextField));

/// Types [word] into [field] one keystroke at a time, the way an input
/// method does.
Future<void> _typeWord(WidgetTester tester, Finder field, String word) async {
  await tester.showKeyboard(field);
  for (var i = 1; i <= word.length; i++) {
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: word.substring(0, i),
        selection: TextSelection.collapsed(offset: i),
      ),
    );
    await tester.pump();
  }
}

/// The typing pause passes, ending the gesture.
Future<void> _pause(WidgetTester tester) async {
  await tester.pump(forgeTypingPause);
  await tester.pump();
}

/// Ctrl+Z / Ctrl+Shift+Z as the test platform (Android) maps them.
Future<void> _key(WidgetTester tester, {bool redo = false}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (redo) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
  if (redo) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

void main() {
  group('QIMN6 one entry per gesture', () {
    testWidgets('QIMN6-1: a word typed in a content field is one undo entry '
        'and one change-log entry', (tester) async {
      final controller = await _controller();
      await _pump(tester, controller);
      await tester.tap(find.widgetWithText(ActionChip, 'overview'));
      await tester.pump();

      final field = _fieldOf(find.byKey(const ValueKey('content:$_overview')));
      await _typeWord(tester, field, 'roses');
      expect(
        controller.content(_overview),
        'roses',
        reason: 'written to the document at once',
      );
      expect(controller.isTyping, isTrue);
      await _pause(tester);

      expect(controller.isTyping, isFalse);
      final entries = controller.changeLog.entries;
      expect(entries, hasLength(1));
      expect(entries.single.kind, ChangeKind.content);
      expect(entries.single.beforeThisEdit, isNull);
      expect(entries.single.afterThisEdit, 'roses');

      await controller.undo();
      await tester.pump();
      expect(
        controller.content(_overview) ?? '',
        isEmpty,
        reason: 'one undo takes the whole word',
      );
      expect(controller.canUndo, isFalse, reason: 'and it was the only entry');
    });

    testWidgets('QIMN6-2: a word typed in a form field is one undo entry and '
        'one change-log entry; a caret move ends the gesture', (tester) async {
      final controller = await _controller();
      await _pump(tester, controller);
      await tester.tap(find.widgetWithText(ActionChip, 'header'));
      await tester.pump();

      final field = _fieldOf(
        find.byKey(const ValueKey('form:$_header/author')),
      );
      await _typeWord(tester, field, 'Ada');
      expect(controller.formField(_header, 'author'), 'Ada');
      // A caret move, no text change: the gesture ends at once.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Ada',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();
      expect(controller.isTyping, isFalse);

      final entries = controller.changeLog.entries;
      expect(entries, hasLength(1));
      expect(entries.single.kind, ChangeKind.formField);
      expect(entries.single.field, 'author');
      expect(entries.single.afterThisEdit, 'Ada');

      await controller.undo();
      await tester.pump();
      expect(controller.formField(_header, 'author') ?? '', isEmpty);
      expect(controller.canUndo, isFalse);
      await _pause(tester);
    });

    testWidgets('QIMN6-3: a word typed in a headline field is one undo entry, '
        'kept out of the change log; the default clears the stored headline', (
      tester,
    ) async {
      final controller = await _controller();
      controller.setContent(_overview, 'body');
      controller.save();
      await _pump(tester, controller);

      final field = _fieldOf(find.byKey(const ValueKey('headline:$_overview')));
      await _typeWord(tester, field, 'Beds');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(controller.headline(_overview), 'Beds');
      expect(
        controller.changeLog.entries,
        isEmpty,
        reason: 'headlines are not part of the agent change log',
      );
      await controller.undo();
      await tester.pump();
      expect(controller.headline(_overview), isNull);
      expect(
        controller.canUndo,
        isTrue,
        reason: 'the content edit before the save is still undoable',
      );

      // Typing the default back in clears the stored headline at the end.
      await _typeWord(tester, field, 'Overview Heading');
      await _pause(tester);
      expect(controller.headline(_overview), isNull);
    });
  });

  testWidgets('QIMN6-6: with a split copy open, a word typed in the main '
      'view is still one undo entry and one change-log entry', (tester) async {
    final controller = await _controller();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              for (final key in const ['main', 'copy'])
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey(key),
                    child: SpecDocumentTree(
                      controller: controller,
                      model: controller.model,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    final main = find.byKey(const ValueKey('main'));
    await tester.tap(
      find.descendant(
        of: main,
        matching: find.widgetWithText(ActionChip, 'overview'),
      ),
    );
    await tester.pump();

    final field = _fieldOf(
      find.descendant(
        of: main,
        matching: find.byKey(const ValueKey('content:$_overview')),
      ),
    );
    await _typeWord(tester, field, 'roses');
    expect(
      controller.isTyping,
      isTrue,
      reason: 'the copy adopting the value is no gesture of the user',
    );
    await _pause(tester);

    expect(controller.changeLog.entries, hasLength(1));
    await controller.undo();
    await tester.pump();
    expect(controller.content(_overview) ?? '', isEmpty);
    expect(controller.canUndo, isFalse, reason: 'one entry for the word');
  });

  group('QIMN6 the caret after undo and redo', () {
    /// Sets [field]'s text and caret, the way an input method does.
    Future<void> input(
      WidgetTester tester,
      Finder field,
      String text,
      int caret,
    ) async {
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: caret),
        ),
      );
      await tester.pump();
    }

    int caretOf(WidgetTester tester, Finder field) =>
        tester.widget<TextField>(field).controller!.selection.extentOffset;

    testWidgets('QIMN6-7: a form field: undo puts the caret before the typed '
        'text, redo after it', (tester) async {
      final controller = await _controller();
      controller.setFormField(_header, 'author', 'Ada King');
      // A form with a value is shown open: no chip to tap.
      await _pump(tester, controller);
      final field = _fieldOf(
        find.byKey(const ValueKey('form:$_header/author')),
      );
      await tester.showKeyboard(field);
      await input(tester, field, 'Ada King', 3);
      await input(tester, field, 'Ada, King', 4);
      await _pause(tester);
      await input(tester, field, 'Ada, King', 0);

      await controller.undo();
      await tester.pump();
      expect(controller.formField(_header, 'author'), 'Ada King');
      expect(caretOf(tester, field), 3);

      await controller.redo();
      await tester.pump();
      expect(controller.formField(_header, 'author'), 'Ada, King');
      expect(caretOf(tester, field), 4);
    });

    testWidgets('QIMN6-8: a headline: undo puts the caret before the typed '
        'text, redo after it', (tester) async {
      final controller = await _controller();
      controller.setContent(_overview, 'body');
      controller.setHeadline(_overview, 'Garden Plan');
      controller.save();
      await _pump(tester, controller);
      final field = _fieldOf(find.byKey(const ValueKey('headline:$_overview')));
      await tester.showKeyboard(field);
      await input(tester, field, 'Garden Plan', 6);
      await input(tester, field, 'Garden: Plan', 7);
      await _pause(tester);
      await input(tester, field, 'Garden: Plan', 0);

      await controller.undo();
      await tester.pump();
      expect(controller.headline(_overview), 'Garden Plan');
      expect(caretOf(tester, field), 6);

      await controller.redo();
      await tester.pump();
      expect(controller.headline(_overview), 'Garden: Plan');
      expect(caretOf(tester, field), 7);
    });

    test('QIMN6-9: the restored caret names its field only, and an edit that '
        'is not typing restores none', () async {
      final controller = await _controller();
      controller.typeContent(_overview, 'roses', caretBefore: 0, caret: 5);
      controller.endTyping();
      await controller.undo();
      expect(controller.restoredCaretFor(_overview), 0);
      expect(controller.restoredCaretFor(_header, field: 'author'), isNull);
      expect(controller.restoredCaretFor(_overview, headline: true), isNull);
      await controller.redo();
      expect(controller.restoredCaretFor(_overview), 5);

      controller.setContent(_overview, 'tulips');
      await controller.undo();
      expect(
        controller.restoredCaretFor(_overview),
        isNull,
        reason:
            'setContent is no typing gesture: the field puts the caret '
            'at the end',
      );
    });
  });

  group('QIMN6 undo keys reach the document', () {
    testWidgets('QIMN6-4: Ctrl+Z in a value field undoes the document, '
        'Ctrl+Shift+Z redoes it; the field follows', (tester) async {
      final controller = await _controller();
      await _pump(tester, controller);
      await tester.tap(find.widgetWithText(ActionChip, 'overview'));
      await tester.pump();
      final field = _fieldOf(find.byKey(const ValueKey('content:$_overview')));

      await _typeWord(tester, field, 'roses');
      await _pause(tester);
      // A second gesture in the same field.
      await _typeWord(tester, field, 'roses and tulips');
      expect(controller.isTyping, isTrue);

      // Undo while typing: the gesture in progress is the document's entry
      // and is what is undone — not the field's own text history.
      await _key(tester);
      expect(controller.content(_overview), 'roses');
      expect(tester.widget<TextField>(field).controller!.text, 'roses');

      await _key(tester);
      expect(controller.content(_overview) ?? '', isEmpty);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);

      await _key(tester, redo: true);
      expect(controller.content(_overview), 'roses');
      expect(tester.widget<TextField>(field).controller!.text, 'roses');

      // The undo intent itself, as any shortcut map invokes it.
      Actions.invoke(
        tester.element(
          find.descendant(of: field, matching: find.byType(EditableText)),
        ),
        const UndoTextIntent(SelectionChangedCause.keyboard),
      );
      await tester.pump();
      expect(controller.content(_overview) ?? '', isEmpty);
      await _pause(tester);
    });

    testWidgets('QIMN6-5: Ctrl+Z in an item id field drops the id not yet '
        'committed and undoes the document', (tester) async {
      final controller = await _controller();
      await _pump(tester, controller);
      await tester.tap(find.widgetWithText(ActionChip, 'items'));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Add item'));
      await tester.pump();
      final item = controller.listItems('D00/D00-ITM').single;
      final generated = controller.itemSectionId(item);

      final id = _fieldOf(find.byKey(ValueKey('item-id:$item')));
      await _typeWord(tester, id, 'D01.7');
      expect(
        controller.itemSectionId(item),
        generated,
        reason: 'an id commits on Enter or blur only',
      );

      await _key(tester);
      expect(
        controller.listItems('D00/D00-ITM'),
        isEmpty,
        reason: 'the document\'s last edit — the add — is undone',
      );
      await _pause(tester);
    });
  });
}

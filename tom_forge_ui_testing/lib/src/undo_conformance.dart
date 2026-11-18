/// The undo conformance checks every Forge editor runs (wonecmpc19).
///
/// One harness, one set of checks: the history contract in
/// `_copilot_guidelines/editor_history_contract.md` stated as tests. An
/// editor's suite describes how to drive it ([ForgeUndoSubject]) and calls
/// [runForgeUndoConformance]; a check the editor does not meet yet is
/// skipped with the reason, which says which todo removes the skip.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions, forgeTypingPause;

import 'package:tom_forge_ui/tom_forge_ui.dart';

/// The checks.
enum ForgeUndoCheck {
  /// Dirty is measured against the saved state: clean again after undoing
  /// back to it, dirty after undoing past a save.
  dirtyFollowsSavedState,

  /// Undo puts the caret where it was before the edit; redo where it was
  /// after.
  caretAfterUndoAndRedo,

  /// Typing undone within the typing pause is undone, not lost or late.
  typingUndoneWithinPause,

  /// Typing after an undo ends the redo future.
  noRedoAfterTyping,

  /// The split copy shows the same document and the same history.
  splitCopiesShareHistory,

  /// Replaced content (reload, external change, revision restore) is shown
  /// by every view, is the saved state, and leaves nothing to undo.
  replaceContentClearsHistory,
}

/// How to drive one editor through the checks.
///
/// The subject is made per check by the factory handed to
/// [runForgeUndoConformance], with its document holding the given text as
/// the saved state. The defaults drive an editor whose views edit through an
/// [EditableText], the way an input method does — through the main view's
/// text controller; an editor that edits otherwise overrides them.
abstract class ForgeUndoSubject {
  /// The editor under test.
  ForgeEditor get editor;

  /// The text controller of [view]'s first [EditableText].
  TextEditingController controllerOf(WidgetTester tester, Finder view) => tester
      .widget<EditableText>(
        find.descendant(of: view, matching: find.byType(EditableText)).first,
      )
      .controller;

  TextEditingController _main(WidgetTester tester) =>
      controllerOf(tester, find.byKey(forgeUndoMainView));

  /// Types [text] at the caret of the main view, as one gesture.
  Future<void> type(WidgetTester tester, String text) async {
    final controller = _main(tester);
    final value = controller.value;
    final at = value.selection.isValid
        ? value.selection.extentOffset
        : value.text.length;
    controller.value = TextEditingValue(
      text: value.text.replaceRange(at, at, text),
      selection: TextSelection.collapsed(offset: at + text.length),
    );
    await tester.pump();
  }

  /// Moves the caret of the main view to [offset] without changing the text.
  Future<void> moveCaret(WidgetTester tester, int offset) async {
    _main(tester).selection = TextSelection.collapsed(offset: offset);
    await tester.pump();
  }

  /// The document's text now.
  String textOf(WidgetTester tester) => editor.getContent()!;

  /// The caret's offset in the main view now.
  int caretOf(WidgetTester tester) => _main(tester).selection.extentOffset;

  /// The text [view] shows.
  String textOfView(WidgetTester tester, Finder view) =>
      controllerOf(tester, view).text;

  /// The file content that makes [text] the document's text — for a
  /// subject whose document holds its text inside a structure (a YAML
  /// field). By default the text itself.
  String contentFor(String text) => text;

  /// Saves: by default what the shell does once it wrote the file
  /// ([ForgeEditor.markClean]); an editor that saves its own file saves.
  Future<void> saved() async => editor.markClean();

  /// Releases the editor.
  void dispose() {}
}

/// The keys of the two views the harness mounts.
const forgeUndoMainView = ValueKey('forge-undo-conformance-main');
const forgeUndoCopyView = ValueKey('forge-undo-conformance-copy');

/// Runs every [ForgeUndoCheck] against the editor [create] makes, as a
/// group named [name]. [skip] maps a check the editor does not meet yet to
/// the reason (name the todo that removes it).
void runForgeUndoConformance(
  String name,
  ForgeUndoSubject Function(String savedText) create, {
  Map<ForgeUndoCheck, String> skip = const {},
}) {
  group('$name undo conformance', () {
    void check(
      ForgeUndoCheck which,
      String description,
      Future<void> Function(WidgetTester tester) body,
    ) {
      testWidgets('UNDO-CONF ${which.name}: $description', (tester) async {
        await body(tester);
        // Let a typing pause still running end before the tree goes — and
        // the debounce an editor may hold typing in before the pause starts.
        await tester.pump(forgeTypingPause);
        await tester.pump(forgeTypingPause);
      }, skip: skip.containsKey(which));
    }

    Future<ForgeUndoSubject> mount(
      WidgetTester tester,
      String savedText, {
      bool withCopy = false,
    }) async {
      final subject = create(savedText);
      addTearDown(subject.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Row(
                children: [
                  Expanded(
                    child: KeyedSubtree(
                      key: forgeUndoMainView,
                      child: subject.editor.buildMain(context),
                    ),
                  ),
                  if (withCopy)
                    Expanded(
                      child: KeyedSubtree(
                        key: forgeUndoCopyView,
                        child: subject.editor.buildCopy(context),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return subject;
    }

    Future<void> run(WidgetTester tester, ForgeUndoSubject s, String id) async {
      s.editor.executeAction(id);
      await tester.pumpAndSettle();
    }

    const undo = StandardEditingActions.undoActionId;
    const redo = StandardEditingActions.redoActionId;

    check(
      ForgeUndoCheck.dirtyFollowsSavedState,
      'clean after undoing to the saved state, dirty after undoing past a '
      'save',
      (tester) async {
        final s = await mount(tester, 'saved');
        expect(s.editor.isDirty.value, isFalse);
        await s.type(tester, ' one');
        await tester.pump(forgeTypingPause);
        expect(s.editor.isDirty.value, isTrue);
        await run(tester, s, undo);
        expect(s.textOf(tester), 'saved');
        expect(s.editor.isDirty.value, isFalse, reason: 'back to saved');
        await run(tester, s, redo);
        expect(s.editor.isDirty.value, isTrue);
        await s.saved();
        await tester.pump();
        expect(s.editor.isDirty.value, isFalse);
        await run(tester, s, undo);
        expect(s.editor.isDirty.value, isTrue, reason: 'undone past the save');
      },
    );

    check(
      ForgeUndoCheck.caretAfterUndoAndRedo,
      'undo restores the caret before the edit, redo the caret after it',
      (tester) async {
        final s = await mount(tester, 'hello world');
        await s.moveCaret(tester, 5);
        await s.type(tester, ',');
        await tester.pump(forgeTypingPause);
        expect(s.textOf(tester), 'hello, world');
        await s.moveCaret(tester, 0);
        await run(tester, s, undo);
        expect(s.textOf(tester), 'hello world');
        expect(s.caretOf(tester), 5);
        await run(tester, s, redo);
        expect(s.caretOf(tester), 6);
      },
    );

    check(
      ForgeUndoCheck.typingUndoneWithinPause,
      'typing undone before the pause ends is undone',
      (tester) async {
        final s = await mount(tester, 'base');
        await s.type(tester, ' typed');
        await run(tester, s, undo);
        expect(s.textOf(tester), 'base');
        await tester.pump(forgeTypingPause * 2);
        expect(s.textOf(tester), 'base', reason: 'nothing arrives late');
      },
    );

    check(
      ForgeUndoCheck.noRedoAfterTyping,
      'typing after an undo leaves nothing to redo',
      (tester) async {
        final s = await mount(tester, '');
        await s.type(tester, 'a');
        await tester.pump(forgeTypingPause);
        await run(tester, s, undo);
        expect(s.editor.isActionEnabled(redo), isTrue);
        await s.type(tester, 'b');
        expect(s.editor.isActionEnabled(redo), isFalse);
      },
    );

    check(
      ForgeUndoCheck.splitCopiesShareHistory,
      'the copy shows every edit, undo and redo of the main view',
      (tester) async {
        final s = await mount(tester, 'shared', withCopy: true);
        final copy = find.byKey(forgeUndoCopyView);
        await s.type(tester, '!');
        await tester.pump(forgeTypingPause);
        await tester.pumpAndSettle();
        expect(s.textOfView(tester, copy), 'shared!');
        await run(tester, s, undo);
        expect(s.textOfView(tester, copy), 'shared');
        await run(tester, s, redo);
        expect(s.textOfView(tester, copy), 'shared!');
      },
    );

    check(
      ForgeUndoCheck.replaceContentClearsHistory,
      'replaced content is shown everywhere, saved, and not undoable',
      (tester) async {
        final s = await mount(tester, 'old', withCopy: true);
        await s.type(tester, ' edit');
        await tester.pump(forgeTypingPause);
        expect(s.editor.replaceContent(s.contentFor('from disk')), isTrue);
        await tester.pumpAndSettle();
        expect(s.textOf(tester), 'from disk');
        expect(
          s.textOfView(tester, find.byKey(forgeUndoMainView)),
          'from disk',
        );
        expect(
          s.textOfView(tester, find.byKey(forgeUndoCopyView)),
          'from disk',
        );
        expect(s.editor.isDirty.value, isFalse);
        expect(s.editor.isActionEnabled(undo), isFalse);
      },
    );
  });
}

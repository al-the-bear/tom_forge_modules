/// The plain-text editor feature by feature: the file's session (one
/// history, typing per burst, dirty against the saved text, a save that
/// checks the disk first), the encoding and line endings it names, read-only
/// files, find, the application's keys and undo depth, the text editor API
/// (selection, cursor, edits, view state, options, decorations, document)
/// and the file's states.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_plain_text_editor/tom_forge_plain_text_editor.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';

/// Mounts [editor]'s main view, wrapped in [wrap] when given.
Future<void> _mount(
  WidgetTester tester,
  ForgePlainTextEditor editor, {
  Widget Function(Widget view)? wrap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            final view = editor.buildMain(context);
            return wrap == null ? view : wrap(view);
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The source's text controller.
TextEditingController _controller(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText).first).controller;

/// Presses [key] with the platform's primary modifier.
Future<void> _pressPrimary(WidgetTester tester, LogicalKeyboardKey key) async {
  final modifier = ForgeShortcutKey.primaryIsMeta
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

/// The editor of the file at [path] in [bed], read now, with the bed's
/// shell as its application.
ForgePlainTextEditor _forFile(ForgeFileKindTestBed bed, String path) =>
    ForgePlainTextEditor.forFile(
      fileSystem: bed.fileSystem,
      uri: bed.fileSystem.uriOf(path),
      module: bed.shellModule,
    );

/// An application's own find on the primary find key, above the editor.
class _AppFindIntent extends Intent {
  const _AppFindIntent();
}

void main() {
  late ForgeFileKindTestBed bed;
  final editors = <ForgePlainTextEditor>[];

  setUp(() {
    bed = ForgeFileKindTestBed();
    editors.clear();
  });

  tearDown(() {
    for (final editor in editors) {
      editor.dispose();
    }
    bed.dispose();
  });

  ForgePlainTextEditor track(ForgePlainTextEditor editor) {
    editors.add(editor);
    return editor;
  }

  ForgePlainTextEditor inMemory(String content, {String name = 'notes.txt'}) =>
      track(
        ForgePlainTextEditor.fromContent(
          content: content,
          uri: Uri.parse('file:///$name'),
          module: bed.shellModule,
        ),
      );

  group('the editor', () {
    test('FPT-1: a plain-text editor of the type plaintext, titled by its '
        'file, that rejects every file and saves its own', () {
      final editor = inMemory('one');
      expect(editor.editorTypeId, 'plaintext');
      expect(ForgePlainTextEditor.typeId, 'plaintext');
      expect(forgeEditorTypeIdOf(editor), 'plaintext');
      expect(editor.title.value, 'notes.txt');
      expect(editor.titleExtension.value, isNull);
      expect(
        editor.canHandle(Uri.parse('file:///x.txt')),
        FileHandlingResult.reject,
      );
      expect(editor.getContent(), isNull);
      expect(editor.supportedActionIds, {
        StandardEditingActions.undoActionId,
        StandardEditingActions.redoActionId,
        StandardEditingActions.saveActionId,
      });
      expect(editor.capabilities.hasTextBuffer, isTrue);
      expect(editor.capabilities.supportsUndoRedo, isTrue);
      expect(editor.stateSnapshot.isTextMode, isTrue);
      expect(editor.stateSnapshot.hasContent, isTrue);
      expect(editor.kitApi, same(bed.shell));
      expect(ForgePlainTextEditor.isPlainTextExtension('LOG'), isTrue);
      expect(ForgePlainTextEditor.isPlainTextExtension('dart'), isFalse);
    });

    test('FPT-2: forFile reads the file through a session of the file '
        'system; a URI outside it is refused', () async {
      await bed.write('/a.txt', utf8.encode('alpha'));
      final editor = track(_forFile(bed, '/a.txt'));
      await pumpEventQueue();
      expect(editor.session.state, ForgeFileSessionState.ready);
      expect(editor.session.text, 'alpha');
      expect(
        () => ForgePlainTextEditor.forFile(
          fileSystem: TomMemoryFileSystem(root: Uri.directory('/w/')),
          uri: Uri.parse('file:///elsewhere/x.txt'),
          module: bed.shellModule,
        ),
        throwsArgumentError,
      );
    });
  });

  group('the session', () {
    testWidgets('FPT-3: a burst of typing is one change; undo takes it back, '
        'redo puts it back, nothing reaches the shell\'s undo manager', (
      tester,
    ) async {
      final editor = inMemory('one');
      await _mount(tester, editor);
      final field = find.byType(TextField);
      await tester.enterText(field, 'one t');
      await tester.enterText(field, 'one tw');
      await tester.enterText(field, 'one two');
      await tester.pump(const Duration(milliseconds: 400));
      expect(editor.session.history, hasLength(1), reason: 'one burst');
      expect(editor.isDirty.value, isTrue);
      expect(editor.executeAction(StandardEditingActions.undoActionId), isTrue);
      await tester.pumpAndSettle();
      expect(editor.session.text, 'one');
      expect(_controller(tester).text, 'one');
      expect(editor.isDirty.value, isFalse, reason: 'back to the saved text');
      expect(editor.executeAction(StandardEditingActions.redoActionId), isTrue);
      await tester.pumpAndSettle();
      expect(editor.session.text, 'one two');
      expect(
        bed.shell.undoManager.undoCount + bed.shell.undoManager.redoCount,
        0,
      );
      await tester.pump(forgeTypingPause);
    });

    testWidgets('FPT-4: the typing pause, a caret move and leaving the source '
        'each end the burst; clicking and selecting never make the file '
        'dirty', (tester) async {
      final editor = inMemory('hello world');
      await _mount(tester, editor);
      final controller = _controller(tester);
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      await tester.pump();
      expect(editor.isDirty.value, isFalse);
      expect(editor.session.canUndo, isFalse);

      await tester.enterText(find.byType(TextField), 'hello world!');
      await tester.pump(forgeTypingPause * 2);
      await tester.enterText(find.byType(TextField), 'hello world!?');
      await tester.pump();
      expect(editor.session.history, hasLength(2), reason: 'the pause');

      controller.selection = const TextSelection.collapsed(offset: 0);
      await tester.pump();
      controller.value = const TextEditingValue(
        text: '>hello world!?',
        selection: TextSelection.collapsed(offset: 1),
      );
      await tester.pump();
      expect(editor.session.history, hasLength(3), reason: 'the caret move');

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.enterText(find.byType(TextField), '>>hello world!?');
      await tester.pump();
      expect(editor.session.history, hasLength(4), reason: 'leaving it');
      await tester.pump(forgeTypingPause);
    });

    testWidgets('FPT-5: Save writes the file through the session and leaves '
        'the editor clean', (tester) async {
      await bed.write('/notes.txt', utf8.encode('one'));
      final editor = track(_forFile(bed, '/notes.txt'));
      await _mount(tester, editor);
      await tester.enterText(find.byType(TextField), 'one two');
      await tester.pump();
      expect(editor.isDirty.value, isTrue);
      expect(
        editor.isActionEnabled(StandardEditingActions.saveActionId),
        isTrue,
      );
      expect(editor.executeAction(StandardEditingActions.saveActionId), isTrue);
      await tester.pumpAndSettle();
      expect(utf8.decode(await bed.read('/notes.txt')), 'one two');
      expect(editor.isDirty.value, isFalse);
      await tester.pump(forgeTypingPause);
    });

    testWidgets('FPT-6: a file changed on disk is not written over; the '
        'banner keeps the user\'s text or takes the disk\'s', (tester) async {
      await bed.write('/notes.txt', utf8.encode('one'));
      final editor = track(_forFile(bed, '/notes.txt'));
      await _mount(tester, editor);
      await tester.enterText(find.byType(TextField), 'mine');
      await tester.pump();
      await bed.write('/notes.txt', utf8.encode('theirs'));
      editor.executeAction(StandardEditingActions.saveActionId);
      await tester.pumpAndSettle();
      expect(utf8.decode(await bed.read('/notes.txt')), 'theirs');
      expect(find.text('This file changed on disk.'), findsOneWidget);
      await tester.tap(find.text('Take theirs'));
      await tester.pumpAndSettle();
      expect(editor.session.text, 'theirs');
      expect(_controller(tester).text, 'theirs');
      expect(find.text('This file changed on disk.'), findsNothing);

      await tester.enterText(find.byType(TextField), 'mine again');
      await tester.pump();
      await bed.write('/notes.txt', utf8.encode('theirs again'));
      editor.executeAction(StandardEditingActions.saveActionId);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep mine'));
      await tester.pumpAndSettle();
      expect(editor.executeAction(StandardEditingActions.saveActionId), isTrue);
      await tester.pumpAndSettle();
      expect(utf8.decode(await bed.read('/notes.txt')), 'mine again');
      expect(editor.isDirty.value, isFalse);
      await tester.pump(forgeTypingPause);
    });

    testWidgets('FPT-7: content from outside (a revision restore) is shown, '
        'saved and not undoable', (tester) async {
      final editor = inMemory('current');
      await _mount(tester, editor);
      await tester.enterText(find.byType(TextField), 'current, edited');
      await tester.pump(forgeTypingPause);
      expect(editor.replaceContent('restored'), isTrue);
      await tester.pumpAndSettle();
      expect(_controller(tester).text, 'restored');
      expect(editor.isDirty.value, isFalse);
      expect(
        editor.isActionEnabled(StandardEditingActions.undoActionId),
        isFalse,
      );
    });
  });

  group('the file\'s format and state', () {
    testWidgets('FPT-8: the header names the encoding and the line endings '
        'the file is written back with', (tester) async {
      await bed.write('/crlf.txt', utf8.encode('first\r\nsecond\r\n'));
      final crlf = track(_forFile(bed, '/crlf.txt'));
      await _mount(tester, crlf);
      expect(find.text('UTF-8 · CRLF'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'first\r\nedited\r\n');
      await tester.pump();
      crlf.executeAction(StandardEditingActions.saveActionId);
      await tester.pumpAndSettle();
      expect(utf8.decode(await bed.read('/crlf.txt')), 'first\r\nedited\r\n');

      final utf16 = [0xFF, 0xFE];
      for (final unit in 'a\nb\n'.codeUnits) {
        utf16
          ..add(unit & 0xFF)
          ..add(unit >> 8);
      }
      await bed.write('/wide.txt', utf16);
      final wide = track(_forFile(bed, '/wide.txt'));
      await _mount(tester, wide);
      expect(find.text('UTF-16 LE · LF'), findsOneWidget);

      await bed.write('/bom.txt', [0xEF, 0xBB, 0xBF, ...utf8.encode('x')]);
      final bom = track(_forFile(bed, '/bom.txt'));
      await _mount(tester, bom);
      expect(find.text('UTF-8 with BOM · No line breaks'), findsOneWidget);
      await tester.pump(forgeTypingPause);
    });

    testWidgets('FPT-9: a file over the read-only limit opens read-only, the '
        'reason named once, and cannot be saved or typed into', (tester) async {
      await bed.write('/big.log', utf8.encode('x' * (forgeReadOnlyAbove + 1)));
      final editor = track(_forFile(bed, '/big.log'));
      await _mount(tester, editor);
      final reason = editor.session.readOnlyReason!;
      expect(find.text(reason), findsOneWidget, reason: 'the frame says it');
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      expect(
        editor.isActionEnabled(StandardEditingActions.saveActionId),
        isFalse,
      );
      expect(editor.stateSnapshot.isEditable, isFalse);
    });

    testWidgets('FPT-10: a file that is being read, does not exist or is '
        'refused shows that instead of the source', (tester) async {
      final missing = track(_forFile(bed, '/nothing.txt'));
      await _mount(tester, missing);
      expect(find.text('This file does not exist.'), findsOneWidget);
      expect(find.byType(EditableText), findsNothing);

      await bed.write('/image.bin', [0, 1, 2, 0, 0, 255, 0]);
      final refused = track(_forFile(bed, '/image.bin'));
      await _mount(tester, refused);
      expect(refused.session.state, ForgeFileSessionState.refused);
      expect(find.byType(EditableText), findsNothing);
    });

    testWidgets('FPT-11: a file deleted on disk while edited is written again '
        'by a save', (tester) async {
      await bed.write('/gone.txt', utf8.encode('here'));
      final editor = track(_forFile(bed, '/gone.txt'));
      await _mount(tester, editor);
      await tester.enterText(find.byType(TextField), 'here, edited');
      await tester.pump();
      await bed.fileSystem.delete(bed.fileSystem.uriOf('/gone.txt'));
      editor.executeAction(StandardEditingActions.saveActionId);
      await tester.pumpAndSettle();
      expect(utf8.decode(await bed.read('/gone.txt')), 'here, edited');
      expect(editor.isDirty.value, isFalse);
      await tester.pump(forgeTypingPause);
    });
  });

  group('find', () {
    testWidgets('FPT-12: the application\'s find bar searches the text '
        '(findAll), shows a match (revealRange) and replaces every match as '
        'one undoable change', (tester) async {
      final editor = inMemory('one two\none two');
      await _mount(tester, editor);
      final matches = editor.findAll('two');
      expect(matches, hasLength(2));
      expect(matches.last.start, const ForgeTextPosition(line: 1, column: 4));
      editor.revealRange(matches.last);
      await tester.pump();
      expect(
        _controller(tester).selection,
        const TextSelection(baseOffset: 12, extentOffset: 15),
      );
      expect(editor.selectedText, 'two');
      expect(editor.replaceAll(RegExp('two'), '2'), 2);
      await tester.pumpAndSettle();
      expect(editor.session.text, 'one 2\none 2');
      editor.executeAction(StandardEditingActions.undoActionId);
      await tester.pumpAndSettle();
      expect(editor.session.text, 'one two\none two');
      expect(editor.replaceAll('absent', 'x'), 0);
    });

    testWidgets('FPT-13: in an application the find key reaches the '
        'application\'s find; the header\'s button opens the source\'s own', (
      tester,
    ) async {
      var appFinds = 0;
      final editor = inMemory('find me');
      await _mount(
        tester,
        editor,
        wrap: (view) => Shortcuts(
          shortcuts: {
            SingleActivator(
              LogicalKeyboardKey.keyF,
              meta: ForgeShortcutKey.primaryIsMeta,
              control: !ForgeShortcutKey.primaryIsMeta,
            ): const _AppFindIntent(),
          },
          child: Actions(
            actions: {
              _AppFindIntent: CallbackAction<_AppFindIntent>(
                onInvoke: (_) => appFinds++,
              ),
            },
            child: view,
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await _pressPrimary(tester, LogicalKeyboardKey.keyF);
      expect(appFinds, 1);
      expect(find.byKey(const Key('tom-text-search')), findsNothing);
      await tester.tap(find.byKey(const Key('tom-text-find')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tom-text-search')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('tom-text-search')), 'me');
      await tester.pump();
      expect(find.text('0 of 1'), findsOneWidget);
    });

    testWidgets('FPT-14: without an application the source answers the find '
        'and the undo keys itself', (tester) async {
      final editor = track(
        ForgePlainTextEditor.fromContent(
          content: 'alone',
          uri: Uri.parse('file:///alone.txt'),
          module: _BareModule(),
        ),
      );
      expect(editor.kitApi, isNull);
      await _mount(tester, editor);
      expect(editor.integration, isNull);
      await tester.enterText(find.byType(TextField), 'alone, typed');
      await tester.pump();
      await _pressPrimary(tester, LogicalKeyboardKey.keyZ);
      expect(editor.session.text, 'alone');
      await _pressPrimary(tester, LogicalKeyboardKey.keyF);
      expect(find.byKey(const Key('tom-text-search')), findsOneWidget);
    });
  });

  group('the application\'s keys and settings', () {
    testWidgets('FPT-15: the undo and redo actions go through the '
        'application\'s binding table: a rebound key undoes at once, the old '
        'key no longer does', (tester) async {
      final editor = inMemory('one');
      await _mount(tester, editor);
      expect(editor.integration, isNotNull);
      expect(
        bed.shell.actionRegistry.getAction(StandardEditingActions.undoActionId),
        isNotNull,
      );
      await tester.enterText(find.byType(TextField), 'one two');
      await tester.pump(const Duration(milliseconds: 400));
      await _pressPrimary(tester, LogicalKeyboardKey.keyZ);
      expect(editor.session.text, 'one', reason: 'the bound key undoes');
      editor.executeAction(StandardEditingActions.redoActionId);
      await tester.pumpAndSettle();

      final undo = bed.shell.shortcuts.getBinding(
        StandardEditingActions.undoActionId,
      )!;
      bed.shell.shortcuts.rebind(
        undo.action,
        const ForgeShortcutKey(key: LogicalKeyboardKey.f7),
      );
      // The binding table tells of the change after the turn; the view
      // takes the new key map in the frame after that.
      await tester.pump();
      await tester.pump();
      await _pressPrimary(tester, LogicalKeyboardKey.keyZ);
      expect(editor.session.text, 'one two', reason: 'the old key is unbound');
      await tester.sendKeyEvent(LogicalKeyboardKey.f7);
      await tester.pumpAndSettle();
      expect(editor.session.text, 'one');
      await tester.pump(forgeTypingPause);
    });

    testWidgets('FPT-16: the undo depth setting bounds the history, also of '
        'an open editor', (tester) async {
      final editor = inMemory('');
      await _mount(tester, editor);
      for (final text in ['a', 'ab', 'abc']) {
        await tester.enterText(find.byType(TextField), text);
        await tester.pump(forgeTypingPause * 2);
      }
      bed.shell.setTextSettings(
        'plaintext',
        const ForgeTextSettings(maxUndoHistory: 1),
      );
      await tester.pump();
      var undos = 0;
      while (editor.isActionEnabled(StandardEditingActions.undoActionId)) {
        editor.executeAction(StandardEditingActions.undoActionId);
        await tester.pumpAndSettle();
        undos++;
      }
      expect(undos, 1);
      expect(editor.session.text, 'ab');
    });

    test('FPT-17: the text options are taken and kept; decorations are set '
        'and cleared per type', () {
      final editor = inMemory('x');
      expect(editor.options.fontFamily, 'monospace');
      const options = ForgeTextEditorOptions(fontSize: 18);
      editor.updateOptions(options);
      expect(editor.options, same(options));
      const type = ForgeDecorationType(key: 'find');
      editor.setDecorations(type, [
        ForgeDecorationRange(
          range: const ForgeTextRange(
            start: ForgeTextPosition(line: 0, column: 0),
            end: ForgeTextPosition(line: 0, column: 1),
          ),
        ),
      ]);
      expect(editor.decorationsOf(type), hasLength(1));
      editor.clearDecorations(type);
      expect(editor.decorationsOf(type), isEmpty);
    });
  });

  group('the text editor API', () {
    testWidgets('FPT-18: the caret and the selection the user leaves are '
        'reported, the state stream fires, selectAll and setSelection are '
        'shown', (tester) async {
      final editor = inMemory('one\ntwo');
      await _mount(tester, editor);
      var states = 0;
      final sub = editor.onStateChanged.listen((_) => states++);
      addTearDown(sub.cancel);
      _controller(tester).selection = const TextSelection(
        baseOffset: 4,
        extentOffset: 7,
      );
      await tester.pump();
      expect(
        editor.cursorPosition.value,
        const ForgeTextPosition(line: 1, column: 3),
      );
      expect(
        editor.selection.value!.start,
        const ForgeTextPosition(line: 1, column: 0),
      );
      expect(editor.selections.value, hasLength(1));
      expect(editor.hasSelection, isTrue);
      expect(editor.stateSnapshot.hasSelection, isTrue);
      expect(editor.selectedText, 'two');
      expect(states, greaterThan(0));

      _controller(tester).selection = const TextSelection.collapsed(offset: 1);
      await tester.pump();
      expect(editor.hasSelection, isFalse);
      expect(editor.selectedText, '');

      editor.selectAll();
      await tester.pump();
      expect(
        _controller(tester).selection,
        const TextSelection(baseOffset: 0, extentOffset: 7),
      );
      editor.setSelections(const [
        ForgeTextRange(
          start: ForgeTextPosition(line: 0, column: 1),
          end: ForgeTextPosition(line: 0, column: 3),
        ),
      ]);
      await tester.pump();
      expect(
        _controller(tester).selection,
        const TextSelection(baseOffset: 1, extentOffset: 3),
      );
      editor.revealPosition(const ForgeTextPosition(line: 1, column: 1));
      await tester.pump();
      expect(
        _controller(tester).selection,
        const TextSelection.collapsed(offset: 5),
      );
    });

    testWidgets('FPT-19: insertText, replaceRange and deleteRange are each '
        'one undoable change, the caret after the edit', (tester) async {
      final editor = inMemory('hello world');
      await _mount(tester, editor);
      editor.setCursorPosition(const ForgeTextPosition(line: 0, column: 5));
      await tester.pump();
      _controller(tester).selection = const TextSelection.collapsed(offset: 5);
      await tester.pump();
      editor.insertText(',');
      await tester.pumpAndSettle();
      expect(editor.session.text, 'hello, world');
      expect(
        _controller(tester).selection,
        const TextSelection.collapsed(offset: 6),
      );
      const world = ForgeTextRange(
        start: ForgeTextPosition(line: 0, column: 7),
        end: ForgeTextPosition(line: 0, column: 12),
      );
      editor.replaceRange(world, 'there');
      await tester.pumpAndSettle();
      expect(editor.session.text, 'hello, there');
      editor.deleteRange(
        const ForgeTextRange(
          start: ForgeTextPosition(line: 0, column: 5),
          end: ForgeTextPosition(line: 0, column: 6),
        ),
      );
      await tester.pumpAndSettle();
      expect(editor.session.text, 'hello there');
      expect(editor.session.history, hasLength(3));
      editor.executeAction(StandardEditingActions.undoActionId);
      await tester.pumpAndSettle();
      expect(editor.session.text, 'hello, there');
    });

    testWidgets('FPT-20: the view state (caret, selection) is saved and '
        'restored', (tester) async {
      final editor = inMemory('one\ntwo\nthree');
      await _mount(tester, editor);
      _controller(tester).selection = const TextSelection(
        baseOffset: 4,
        extentOffset: 7,
      );
      await tester.pump();
      final state = editor.saveState()!;
      expect(state['cursorLine'], 1);
      expect(state['cursorColumn'], 3);
      expect((state['selection'] as Map)['startLine'], 1);

      _controller(tester).selection = const TextSelection.collapsed(offset: 0);
      await tester.pump();
      editor.restoreState(state);
      await tester.pump();
      expect(
        _controller(tester).selection,
        const TextSelection(baseOffset: 4, extentOffset: 7),
      );
    });

    testWidgets('FPT-21: the document is the session\'s text, by line, and '
        'tells its listeners of a change', (tester) async {
      final editor = inMemory('one\ntwo');
      final document = editor.document;
      expect(document.text, 'one\ntwo');
      expect(document.lineCount, 2);
      expect(document.lineAt(1), 'two');
      expect(document.languageId, 'plaintext');
      expect(document.isUntitled, isTrue, reason: 'text in memory');
      expect(
        document.textInRange(
          const ForgeTextRange(
            start: ForgeTextPosition(line: 0, column: 1),
            end: ForgeTextPosition(line: 1, column: 1),
          ),
        ),
        'ne\nt',
      );
      var changes = 0;
      final sub = document.onDidChange.listen((_) => changes++);
      addTearDown(sub.cancel);
      await _mount(tester, editor);
      await tester.enterText(find.byType(TextField), 'one\ntwo\nthree');
      await tester.pump();
      expect(changes, greaterThan(0));
      expect(document.lineCount, 3);
      await tester.pump(forgeTypingPause);
    });

    testWidgets('FPT-22: a split copy edits the one session', (tester) async {
      final editor = inMemory('shared');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Row(
                children: [
                  Expanded(child: editor.buildMain(context)),
                  Expanded(child: editor.buildCopy(context)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'shared!');
      await tester.pumpAndSettle();
      final copy = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .last
          .controller;
      expect(copy.text, 'shared!');
      await tester.pump(forgeTypingPause);
    });

    testWidgets('FPT-23: a JSON file is highlighted, a text file is not', (
      tester,
    ) async {
      final json = inMemory('{"a": 1}', name: 'data.json');
      await _mount(tester, json);
      final span = _controller(tester).buildTextSpan(
        context: tester.element(find.byType(EditableText)),
        withComposing: false,
      );
      expect(span.children!.length, greaterThan(1));

      final text = inMemory('{"a": 1}', name: 'data.txt');
      await _mount(tester, text);
      final plain = _controller(tester).buildTextSpan(
        context: tester.element(find.byType(EditableText)),
        withComposing: false,
      );
      expect(
        plain.children?.whereType<TextSpan>().where((s) => s.style != null),
        anyOf(isNull, isEmpty),
      );
    });
  });
}

/// A module of no application: an editor made for it works on its own.
class _BareModule extends ForgeKitModule {
  @override
  String get displayName => 'Bare';

  @override
  void activate(ForgeKitApi api) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
}

/// The office editors under Forge's undo conformance harness
/// (`package:tom_forge_ui_testing/tom_forge_ui_testing.dart`): how to drive
/// each one as a [ForgeUndoSubject], the checks each skips and why
/// ([forgeOfficeEditorSkips], [forgeZetaOfficeEditorSkips]), a scripted
/// LibreOffice helper ([ScriptedOfficeHelper]) and a scripted ZetaOffice
/// page ([ScriptedZetaOfficePage]) standing in for the engines, a tile
/// decoder that needs no real time ([forgeOfficeTestDecoder]).
///
/// The runs check the routing — the shell's undo and redo reaching the
/// controller, the dirty marker, the views — against fakes that model
/// LibreOffice's undo behaviour as the evaluation's engine checks found it
/// (a new edit ends the redo; the modified flag clears when undo or redo
/// reaches the saved state), not LibreOffice itself (part-forge-integration, *History and the undo
/// conformance harness*).
///
/// Test-only: a package of its own, taken as a dev_dependency by the suites
/// that drive these editors; nothing a product links depends on it.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_session/tom_file_session.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_office_editors/tom_forge_office_editors.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart' show DefaultShellApi;
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';
import 'package:tom_office_editor/testing.dart';
import 'package:tom_office_editor/tom_office_editor.dart';
import 'package:tom_office_editor/zetaoffice.dart';
import 'package:tom_office_protocol/tom_office_protocol.dart';

/// The todo that decides the office routes' full conformance after the
/// comparison.
const _decidedBy = 'Decided after the comparison (officeproto31h)';

/// The checks the LibreOfficeKit editor skips, with the reason.
const forgeOfficeEditorSkips = <ForgeUndoCheck, String>{
  ForgeUndoCheck.caretAfterUndoAndRedo:
      'the caret is the engine\'s: there is no text offset to compare, and '
      'LibreOffice restores it itself. $_decidedBy',
  ForgeUndoCheck.typingUndoneWithinPause:
      'LibreOffice groups typing itself; forgeTypingPause does not reach '
      'it. $_decidedBy',
  ForgeUndoCheck.replaceContentClearsHistory:
      'replace-in-place is not offered (replaceContent answers false: a '
      'binary document takes no string); the shell reopens the editor '
      'instead (a new helper, an empty history), tested by FOFF-REOPEN-1. '
      '$_decidedBy',
};

/// The checks the ZetaOffice editor skips, with the reason.
const forgeZetaOfficeEditorSkips = <ForgeUndoCheck, String>{
  ForgeUndoCheck.caretAfterUndoAndRedo:
      'the caret is ZetaOffice\'s, inside the webview. $_decidedBy',
  ForgeUndoCheck.typingUndoneWithinPause:
      'ZetaOffice groups typing itself, inside the webview. $_decidedBy',
  ForgeUndoCheck.splitCopiesShareHistory:
      'the copy is not a second view: a webview page cannot be shown twice '
      '(buildCopy says so). $_decidedBy',
  ForgeUndoCheck.replaceContentClearsHistory:
      'replace-in-place is not offered (replaceContent answers false); the '
      'shell reopens the editor instead, tested by FZO-REOPEN-1. $_decidedBy',
};

/// Decodes nothing: a small blank image made synchronously, so tiles need no
/// real decoding under the test's fake clock.
Future<ui.Image> forgeOfficeTestDecoder(
  Uint8List pixels,
  int width,
  int height,
  OfficePixelFormat format,
) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 4, 4),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  return Future.value(recorder.endRecording().toImageSync(4, 4));
}

/// A fake shell for editors made outside a module (notifications only).
DefaultShellApi forgeOfficeTestShell() => DefaultShellApi.withDefaults(
  fileSystemSeed: const {},
  appName: 'Office editors',
  navigatorKey: GlobalKey<NavigatorState>(),
);

const _testPath = '/docs/subject.docx';

/// The file a subject's document is.
final forgeOfficeTestUri = Uri.file(_testPath);

/// LibreOffice as the fake helper channel plays it: the document is
/// [text]; text committed by the input method (`textInput` input, then
/// end) or typed as a key is appended, one undo step per commit or key;
/// undo and redo move it through the history; a new edit ends the redo; the
/// modified flag says whether the history stands at the saved state (the
/// opened one until a save), so undoing back to it clears the flag, as
/// LibreOffice 26.8.3.1 does (`STATE_CHANGED .uno:ModifiedStatus`,
/// `.uno:Undo`, `.uno:Redo`, as LibreOfficeKit reports them). A save writes [text] to the temporary
/// target through [fileSystem].
class ScriptedOfficeHelper extends FakeOfficeHelperChannel {
  /// A helper whose document holds [text]; saves go to [fileSystem].
  ScriptedOfficeHelper(this.text, {required TomFileSystem fileSystem})
    : _fs = fileSystem,
      super();

  /// The document's text.
  String text;

  final TomFileSystem _fs;
  final _undo = <String>[];
  final _redo = <String>[];
  String? _composition;

  /// The undo depth of the saved state (the opened one until a save), or
  /// null once a new edit after undoing past it made it unreachable.
  int? _savedDepth = 0;

  /// The saves, in order.
  int saves = 0;

  /// Whether the document differs from its saved state, as LibreOffice's
  /// `.uno:ModifiedStatus` says it: false again when undo or redo reaches
  /// the saved state's position in the history.
  bool get modified => _savedDepth != _undo.length;

  @override
  void send(OfficeHelperCommand command) {
    switch (command) {
      case OfficeTextInput(type: OfficeTextInputType.input, :final text):
        // The input method's composition, inserted at its end.
        sent.add(command);
        _composition = text;
      case OfficeTextInput(type: OfficeTextInputType.end):
        sent.add(command);
        final composed = _composition;
        _composition = null;
        if (composed != null && composed.isNotEmpty) edit(composed);
      case OfficeKey(type: OfficeKeyEventType.down, :final charCode)
          when charCode > 0:
        sent.add(command);
        edit(String.fromCharCode(charCode));
      case OfficeUno(command: '.uno:Undo'):
        sent.add(command);
        if (_undo.isEmpty) return;
        _redo.add(text);
        text = _undo.removeLast();
        _report();
      case OfficeUno(command: '.uno:Redo'):
        sent.add(command);
        if (_redo.isEmpty) return;
        _undo.add(text);
        text = _redo.removeLast();
        _report();
      case OfficeSave(:final id, :final targetPath):
        sent.add(command);
        unawaited(() async {
          await _fs.write(
            _fs.uriOf(targetPath),
            Uint8List.fromList(utf8.encode(text)),
          );
          saves++;
          _savedDepth = _undo.length;
          emit(OfficeSaved(id: id, ok: true));
          callback('STATE_CHANGED', '.uno:ModifiedStatus=false');
        }());
      default:
        super.send(command);
    }
  }

  /// The user types [typed] into the document.
  void edit(String typed) {
    // A new edit ends the redo; a saved state in it is gone for good.
    final saved = _savedDepth;
    if (saved != null && saved > _undo.length) _savedDepth = null;
    _undo.add(text);
    _redo.clear();
    text += typed;
    _report();
  }

  void _report() {
    callback(
      'STATE_CHANGED',
      '.uno:Undo=${_undo.isEmpty ? 'disabled' : 'enabled'}',
    );
    callback(
      'STATE_CHANGED',
      '.uno:Redo=${_redo.isEmpty ? 'disabled' : 'enabled'}',
    );
    callback('STATE_CHANGED', '.uno:ModifiedStatus=$modified');
  }
}

/// ZetaOffice's page as the fake webview channel plays it: it answers the
/// page load with `ready` and `loaded`; typed text is appended with
/// ZetaOffice's history (a new edit ends the redo); `undo`, `redo` and
/// `save` work as the bridge does, the save posting [text] through
/// [serving]. The modified flag is false whenever undo or redo reaches the
/// saved state, as ZetaOffice's own flag is.
class ScriptedZetaOfficePage extends FakeZetaOfficeChannel {
  /// A page whose document holds [text].
  ScriptedZetaOfficePage(this.text, this.serving);

  /// The document's text.
  String text;

  /// The tab's fake server (the save posts through it).
  final FakeZetaOfficeServing serving;

  final _undo = <String>[];
  final _redo = <String>[];

  /// The undo depth of the saved state (the opened one until a save), or
  /// null once a new edit after undoing past it made it unreachable.
  int? _savedDepth = 0;

  /// Whether the document differs from its saved state.
  bool get modified => _savedDepth != _undo.length;

  @override
  Future<void> load(Uri page) async {
    await super.load(page);
    scheduleMicrotask(() {
      emit({'type': 'ready'});
      emit({
        'type': 'loaded',
        'kind': 'text',
        'product': 'ZetaOffice (scripted)',
      });
      _history();
    });
  }

  @override
  Future<void> call(String function, [List<Object?> args = const []]) async {
    await super.call(function, args);
    switch (function) {
      case 'undo':
        if (_undo.isEmpty) return;
        _redo.add(text);
        text = _undo.removeLast();
        _history();
      case 'redo':
        if (_redo.isEmpty) return;
        _undo.add(text);
        text = _redo.removeLast();
        _history();
      case 'save':
        await serving.postSave(utf8.encode(text));
        _savedDepth = _undo.length;
        emit({'type': 'saved', 'ok': true, 'copy': false});
        emit({'type': 'modified', 'value': false});
    }
  }

  /// The user types [typed] into the page.
  void edit(String typed) {
    // A new edit ends the redo; a saved state in it is gone for good.
    final saved = _savedDepth;
    if (saved != null && saved > _undo.length) _savedDepth = null;
    _undo.add(text);
    _redo.clear();
    text += typed;
    _history();
  }

  void _history() {
    emit({
      'type': 'history',
      'canUndo': _undo.isNotEmpty,
      'canRedo': _redo.isNotEmpty,
    });
    emit({'type': 'modified', 'value': modified});
  }
}

/// The in-memory file system of a subject: its document holds [savedText].
TomMemoryFileSystem forgeOfficeTestFileSystem(String savedText) =>
    TomMemoryFileSystem(seed: {_testPath: savedText});

/// A launcher that hands out [helper] (the LibreOfficeKit editor's).
TomOfficeHelperLauncher forgeOfficeTestLauncher(ScriptedOfficeHelper helper) =>
    FakeOfficeHelperLauncher(channelFor: () => helper);

/// ZetaOffice's files, cached.
TomZetaOfficeFiles forgeZetaOfficeTestFiles() =>
    FakeZetaOfficeFiles(state: TomZetaOfficeCacheState.ready);

/// A host over an in-memory file holding [text] at [path], with [launcher]
/// (the LibreOfficeKit editor's) and the test shell.
ForgeOfficeHost forgeOfficeTestHost({
  required TomMemoryFileSystem fileSystem,
  String path = _testPath,
  TomOfficeHelperLauncher? launcher,
}) {
  final helper = launcher ?? FakeOfficeHelperLauncher();
  return ForgeOfficeHost(
    filePath: path,
    shell: forgeOfficeTestShell(),
    files: TomFileSystemBinaryFiles(fileSystem),
    launcher: () => helper,
    pickImage: () async => null,
  );
}

/// The LibreOfficeKit editor over a [ScriptedOfficeHelper] (made over
/// [forgeOfficeTestHost] with [forgeOfficeTestLauncher] and
/// [forgeOfficeTestDecoder]), typed into
/// through the controller's `commitText` (as the document view's input
/// method commits text).
class ForgeOfficeEditorSubject extends ForgeUndoSubject {
  ForgeOfficeEditorSubject(this.editor, this.helper);

  @override
  final ForgeOfficeEditor editor;

  /// The scripted LibreOffice.
  final ScriptedOfficeHelper helper;

  @override
  Future<void> type(WidgetTester tester, String text) async {
    editor.controller.commitText(text);
    await tester.pump();
  }

  @override
  String textOf(WidgetTester tester) => helper.text;

  /// The text [view] shows: the copy is a second `TomOfficeEditor` on the
  /// same controller, so the same document.
  @override
  String textOfView(WidgetTester tester, Finder view) {
    final shown = tester
        .widget<TomOfficeEditor>(
          find.descendant(of: view, matching: find.byType(TomOfficeEditor)),
        )
        .controller;
    return identical(shown, editor.controller) ? helper.text : '';
  }

  @override
  Future<void> saved() async {
    await editor.controller.save();
  }

  @override
  void dispose() => unawaited(editor.close());
}

/// The ZetaOffice editor over a [ScriptedZetaOfficePage] (made over
/// [forgeOfficeTestHost] with [forgeZetaOfficeTestFiles], the page's
/// server and the page as its channel).
class ForgeZetaOfficeEditorSubject extends ForgeUndoSubject {
  ForgeZetaOfficeEditorSubject(this.editor, this.page);

  @override
  final ForgeZetaOfficeEditor editor;

  /// The scripted page.
  final ScriptedZetaOfficePage page;

  @override
  Future<void> type(WidgetTester tester, String text) async {
    page.edit(text);
    await tester.pump();
  }

  @override
  String textOf(WidgetTester tester) => page.text;

  @override
  Future<void> saved() async {
    await editor.controller.save();
  }

  @override
  void dispose() => unawaited(editor.close());
}

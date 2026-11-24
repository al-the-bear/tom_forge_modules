/// The ZetaOffice office adapter (`tom_forge_office_zetaoffice`) under
/// Forge's undo conformance harness
/// (`package:tom_forge_ui_testing/tom_forge_ui_testing.dart`): how to drive
/// its editor as a [ForgeUndoSubject], the checks it skips and why
/// ([forgeZetaOfficeEditorSkips]), a scripted ZetaOffice page
/// ([ScriptedZetaOfficePage]) standing in for the engine; and the adapter's
/// test bed: its module in a panel shell over a memory file system
/// ([ForgeZetaOfficeWorkspace]).
///
/// The runs check the routing — the application's undo and redo reaching
/// the controller, the dirty marker — against a fake page that models
/// ZetaOffice's undo behaviour (a new edit ends the redo; the modified flag
/// clears when undo or redo reaches the saved state), not ZetaOffice itself.
///
/// Test-only: a package of its own, taken as a dev_dependency by the suites
/// that drive this editor; nothing a product links depends on it. It brings
/// the panel shell to the suites, never to the adapter.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_session/tom_file_session.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_office_zetaoffice/tom_forge_office_zetaoffice.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart' show DefaultShellApi;
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';
import 'package:tom_office_zetaoffice/testing.dart';
import 'package:tom_office_zetaoffice/tom_office_zetaoffice.dart';

export 'src/zetaoffice_workspace.dart';

/// The todo that decides the office routes' full conformance after the
/// comparison.
const _decidedBy = 'Decided after the comparison (officeproto31h)';

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

/// A fake shell for editors made outside a module (notifications only).
DefaultShellApi forgeZetaOfficeTestShell() => DefaultShellApi.withDefaults(
  fileSystemSeed: const {},
  appName: 'Office editor',
  navigatorKey: GlobalKey<NavigatorState>(),
);

const _testPath = '/docs/subject.docx';

/// The file a subject's document is.
final forgeZetaOfficeTestUri = Uri.file(_testPath);

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
TomMemoryFileSystem forgeZetaOfficeTestFileSystem(String savedText) =>
    TomMemoryFileSystem(seed: {_testPath: savedText});

/// ZetaOffice's files, cached.
TomZetaOfficeFiles forgeZetaOfficeTestFiles() =>
    FakeZetaOfficeFiles(state: TomZetaOfficeCacheState.ready);

/// A host over an in-memory file at [path] and the test shell's API.
ForgeZetaOfficeHost forgeZetaOfficeTestHost({
  required TomMemoryFileSystem fileSystem,
  String path = _testPath,
}) => ForgeZetaOfficeHost(
  filePath: path,
  api: forgeZetaOfficeTestShell(),
  files: TomFileSystemBinaryFiles(fileSystem),
);

/// The ZetaOffice editor over a [ScriptedZetaOfficePage] (made over
/// [forgeZetaOfficeTestHost] with [forgeZetaOfficeTestFiles], the page's
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

/// The pdf.js editor under Forge's undo conformance harness
/// (`package:tom_forge_ui_testing/tom_forge_ui_testing.dart`): how to drive
/// it as a [ForgeUndoSubject], the checks it skips and why
/// ([forgePdfJsEditorSkips]), a scripted pdf.js page standing in for the
/// webview ([ScriptedPdfJsPage]) and a bare kit without a shell
/// ([ForgePdfJsTestKit]) for the editor's and the module's suites.
///
/// The harness's checks speak of text; a PDF has annotations. The subject
/// maps one onto the other: typing adds an annotation whose text is what was
/// typed, and the document's text is the annotations' texts joined. The runs
/// check the routing — the application's undo and redo reaching the
/// controller, the dirty marker — against a scripted page, not pdf.js itself
/// (part-forge-integration, *History and the undo conformance harness*).
///
/// Test-only: a package of its own, taken as a dev_dependency by the suites
/// that drive this editor; nothing a product links depends on it.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_pdf_pdfjs/tom_forge_pdf_pdfjs.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';
import 'package:tom_pdf_editor/testing.dart' show MemoryBinaryFiles;
import 'package:tom_pdf_pdfjs/testing.dart';

/// The checks the pdf.js editor skips, with the reason.
const forgePdfJsEditorSkips = <ForgeUndoCheck, String>{
  ForgeUndoCheck.dirtyFollowsSavedState:
      'Forge reopens the document after a save, so pdf.js\'s history starts '
      'again and nothing can be undone past the save. Undoing back to the '
      'saved state does read clean (pdf.js resets its modified state when '
      'the last edit since the open is removed; officeproto31hg)',
  ForgeUndoCheck.caretAfterUndoAndRedo:
      'not applicable: annotations have no caret',
  ForgeUndoCheck.typingUndoneWithinPause:
      'not applicable: pdf.js groups its own editing in the page',
  ForgeUndoCheck.splitCopiesShareHistory:
      'the copy is not a second view: a webview page cannot be shown twice '
      '(buildCopy says so). Decided after the comparison (officeproto24)',
  ForgeUndoCheck.replaceContentClearsHistory:
      'replace-in-place is not offered (replaceContent answers false); the '
      'application reopens the editor instead, tested by FPDFJS-REOPEN-1. '
      'Decided after the comparison (officeproto24)',
};

/// An editor host with no place of its own: what it is asked it reports to
/// the kit state (opened, active, closed).
class ForgePdfJsTestEditorHost implements ForgeEditorHost {
  DefaultKitState? state;

  @override
  Future<void> showEditor(
    ForgeEditor editor, {
    bool focus = true,
    Object? placement,
  }) async {
    state?.addOpenEditor(editor);
    if (focus) state?.setActiveEditor(editor);
  }

  @override
  Future<bool> closeEditor(ForgeEditor editor) async {
    state?.removeOpenEditor(editor);
    return true;
  }

  @override
  void bringToFront(ForgeEditor editor) => state?.setActiveEditor(editor);

  @override
  Future<ForgeEditor?> openEditorFor(Uri uri, {Object? placement}) async =>
      null;
}

/// A bare kit for the pdf.js editor's suites: a [DefaultKitApi] over an
/// in-memory state store and [fileSystem] (in memory by default), with an
/// editor host that only reports to the kit state — no shell, no layout.
class ForgePdfJsTestKit {
  ForgePdfJsTestKit({TomFileSystem? fileSystem})
    : host = ForgePdfJsTestEditorHost() {
    api = DefaultKitApi(
      editorHost: host,
      fileSystem: fileSystem ?? TomMemoryFileSystem(),
      stateStore: ForgeMemoryStateStore(),
    );
    host.state = api.state;
  }

  /// The editor host.
  final ForgePdfJsTestEditorHost host;

  /// The API.
  late final DefaultKitApi api;

  /// Closes [editor] as the application does.
  Future<bool> close(ForgeEditor editor) => host.closeEditor(editor);
}

const _testPath = '/docs/subject.pdf';

/// The file a subject's document is.
final forgePdfJsTestUri = Uri.file(_testPath);

/// Where an offline pdf.js subject's page is said to be.
final forgePdfJsTestBaseUri = Uri.parse('http://pdfjs.test/t/');

/// The host of a pdf.js subject (in-memory files in a bare kit; the page is
/// scripted).
ForgePdfJsHost forgePdfJsTestHost() => ForgePdfJsHost(
  filePath: _testPath,
  api: ForgePdfJsTestKit().api,
  files: MemoryBinaryFiles()..write(_testPath, utf8.encode('%PDF-subject')),
  authorName: 'Tester',
);

/// pdf.js's page as the fake webview channel plays it: it answers `open`
/// with `loaded`, keeps a list of annotations with pdf.js's history (a new
/// annotation ends the redo), and reports `history` and `modified` the way
/// the bridge does.
class ScriptedPdfJsPage extends FakePdfJsChannel {
  /// A page whose document holds [annotations].
  ScriptedPdfJsPage([List<String> annotations = const []])
    : annotations = [...annotations];

  /// The annotations, as their texts.
  final List<String> annotations;

  final _undo = <String>[];
  final _redo = <String>[];

  /// The annotations made since the open (or the last save), as pdf.js's
  /// `annotationStorage` holds them: an edit sets `modified`, and removing
  /// the last value of the storage (undo of the only edit since the open)
  /// resets it.
  final _storage = <String>[];

  @override
  Future<void> load(Uri page) async {
    await super.load(page);
    scheduleMicrotask(() => send({'type': 'ready', 'mode': 'components'}));
  }

  @override
  Future<void> call(String function, [List<Object?> args = const []]) async {
    await super.call(function, args);
    switch (function) {
      case 'open':
        // A (re)open starts with an empty storage and a new history, as
        // pdf.js does for a new document.
        _storage.clear();
        _undo.clear();
        _redo.clear();
        send({'type': 'loaded', 'pageCount': 1, 'ms': 1});
        send({'type': 'textLayer', 'value': true});
      case 'undo':
        if (_undo.isEmpty) return;
        final a = annotations.removeLast();
        _redo.add(a);
        _undo.removeLast();
        _storage.remove(a);
        _history();
      case 'redo':
        if (_redo.isEmpty) return;
        final a = _redo.removeLast();
        annotations.add(a);
        _undo.add(a);
        _storage.add(a);
        _history();
    }
  }

  /// The user adds an annotation with [text] in the page.
  void add(String text) {
    annotations.add(text);
    _undo.add(text);
    _redo.clear();
    _storage.add(text);
    _history();
  }

  /// The document was saved and reopened from the new file, as Forge does
  /// after a save: the storage is empty, the history starts again.
  void savedAndReopened() {
    _storage.clear();
    _undo.clear();
    _redo.clear();
    _history();
  }

  void _history() {
    send({
      'type': 'history',
      'canUndo': _undo.isNotEmpty,
      'canRedo': _redo.isNotEmpty,
    });
    send({'type': 'modified', 'value': _storage.isNotEmpty});
  }
}

/// The pdf.js editor over a [ScriptedPdfJsPage], offline (no server): its
/// editor is made over [forgePdfJsTestHost] with the page as its channel and
/// [forgePdfJsTestBaseUri].
class ForgePdfJsEditorSubject extends ForgeUndoSubject {
  ForgePdfJsEditorSubject(this.editor, this.page);

  @override
  final ForgePdfJsEditor editor;

  /// The scripted page.
  final ScriptedPdfJsPage page;

  @override
  Future<void> type(WidgetTester tester, String text) async {
    page.add(text);
    await tester.pump();
  }

  @override
  String textOf(WidgetTester tester) => page.annotations.join();

  /// A save: Forge writes the file and reopens it (`TomPdfJsController.save`).
  @override
  Future<void> saved() async => page.savedAndReopened();

  @override
  void dispose() => unawaited(editor.close());
}

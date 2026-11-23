/// The PDF editors under Forge's undo conformance harness
/// (`package:tom_forge_ui_testing/tom_forge_ui_testing.dart`): how to drive
/// each one as a [ForgeUndoSubject], the checks each skips and why
/// ([forgePdfEditorSkips], [forgePdfJsEditorSkips]), a scripted pdf.js page
/// standing in for the webview ([ScriptedPdfJsPage]) and a decoder that needs no real I/O
/// ([forgePdfTestDecoder]).
///
/// The harness's checks speak of text; a PDF has annotations. The subjects
/// map one onto the other: typing adds a note whose text is what was typed,
/// and the document's text is the notes' texts joined. The runs check the
/// routing — the shell's undo and redo reaching the controller, the dirty
/// marker, the views — against the base components' fakes, not PDFium or
/// pdf.js themselves (part-forge-integration, *History and the undo
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
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_pdf_editor/testing.dart';
import 'package:tom_pdf_editor/tom_pdf_editor.dart';

import 'package:tom_forge_pdf_editors/tom_forge_pdf_editors.dart';

/// Decodes nothing: a small blank image made synchronously, so rendered
/// pages need no real decoding under the test's fake clock.
Future<ui.Image> forgePdfTestDecoder(Uint8List bgra, int width, int height) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 4, 4),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  return Future.value(recorder.endRecording().toImageSync(4, 4));
}

/// The checks the PDFium editor skips, with the reason.
const forgePdfEditorSkips = <ForgeUndoCheck, String>{
  ForgeUndoCheck.caretAfterUndoAndRedo:
      'not applicable: annotations have no caret (selection only)',
  ForgeUndoCheck.typingUndoneWithinPause:
      'not applicable: nothing is typed into the document (a note\'s text '
      'is edited in a dialog, one undo step)',
  ForgeUndoCheck.replaceContentClearsHistory:
      'replace-in-place is not offered (replaceContent answers false: a '
      'binary document takes no string); the shell reopens the editor '
      'instead, tested by FPDF-REOPEN-1. Full conformance is decided after '
      'the comparison (officeproto24)',
};

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
      'shell reopens the editor instead, tested by FPDFJS-REOPEN-1. Decided '
      'after the comparison (officeproto24)',
};

/// A fake shell for subjects made outside a module (notifications only).
DefaultShellApi forgePdfTestShell() => DefaultShellApi.withDefaults(
  fileSystemSeed: const {},
  appName: 'PDF editors',
  navigatorKey: GlobalKey<NavigatorState>(),
);

const _testPath = '/docs/subject.pdf';

/// The notes of [text]: one note per word-group, so the joined text is
/// [text] again.
List<PdfAnnotation> _notesOf(String text) => [
  if (text.isNotEmpty)
    PdfAnnotation(
      id: 'n0',
      kind: PdfAnnotationKind.note,
      rect: const PdfRect(40, 40, 60, 60),
      contents: text,
    ),
];

String _joined(List<PdfAnnotation> annotations) => [
  for (final a in annotations)
    if (a.kind == PdfAnnotationKind.note) a.contents,
].join();

/// The file a subject's document is.
final forgePdfTestUri = Uri.file(_testPath);

/// Where an offline pdf.js subject's page is said to be.
final forgePdfJsTestBaseUri = Uri.parse('http://pdfjs.test/t/');

/// The host of a PDFium subject: its document holds [savedText] as its
/// saved notes, on a fake engine and in-memory files.
ForgePdfHost forgePdfTestHost(String savedText) {
  final files = MemoryBinaryFiles()
    ..write(_testPath, utf8.encode('%PDF-subject'));
  final engine = FakePdfEngine({
    _testPath: FakePdfDocument(
      pages: const [PdfPageSize(300, 400)],
      texts: const ['subject'],
      annotations: {0: _notesOf(savedText)},
    ),
  }, files: files);
  return ForgePdfHost(
    filePath: _testPath,
    shell: forgePdfTestShell(),
    files: files,
    locatePdfium: () => const TomPdfiumLibrary.found(
      '/fake/libpdfium.dylib',
      kPdfiumBindingsTag,
    ),
    startEngine: (_) async => engine,
    authorName: 'Tester',
  );
}

/// The host of a pdf.js subject (in-memory files; the page is scripted).
ForgePdfHost forgePdfJsTestHost() => ForgePdfHost(
  filePath: _testPath,
  shell: forgePdfTestShell(),
  files: MemoryBinaryFiles()..write(_testPath, utf8.encode('%PDF-subject')),
  locatePdfium: () =>
      const TomPdfiumLibrary.found('/fake/libpdfium.dylib', kPdfiumBindingsTag),
  startEngine: (_) async => FakePdfEngine(const {}),
);

/// The PDFium editor, typed into by adding notes. Its editor is made over
/// [forgePdfTestHost] with [forgePdfTestDecoder].
class ForgePdfEditorSubject extends ForgeUndoSubject {
  ForgePdfEditorSubject(this.editor);

  @override
  final ForgePdfEditor editor;

  var _x = 80.0;

  @override
  Future<void> type(WidgetTester tester, String text) async {
    final c = editor.controller;
    await c.loadAnnotations(0);
    await c.addNote(0, _x, 120, text);
    _x += 30;
    await tester.pump();
  }

  @override
  String textOf(WidgetTester tester) =>
      _joined(editor.controller.annotationsOn(0));

  /// The notes [view]'s `TomPdfEditor` shows: the copy is a second
  /// `TomPdfEditor` on the same controller.
  @override
  String textOfView(WidgetTester tester, Finder view) => _joined(
    tester
        .widget<TomPdfEditor>(
          find.descendant(of: view, matching: find.byType(TomPdfEditor)),
        )
        .controller
        .annotationsOn(0),
  );

  @override
  Future<void> saved() async {
    await editor.controller.save();
    await editor.controller.loadAnnotations(0);
  }

  @override
  void dispose() => unawaited(editor.close());
}

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

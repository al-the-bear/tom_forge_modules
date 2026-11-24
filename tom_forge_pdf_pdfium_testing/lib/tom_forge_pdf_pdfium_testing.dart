/// The PDFium editor under Forge's undo conformance harness
/// (`package:tom_forge_ui_testing/tom_forge_ui_testing.dart`): how to drive
/// it as a [ForgeUndoSubject], the checks it skips and why
/// ([forgePdfEditorSkips]), a decoder that needs no real I/O
/// ([forgePdfTestDecoder]) and a bare kit without a shell
/// ([ForgePdfTestKit]) for the editor's and the module's suites, and the
/// module on a fake engine ([forgePdfiumTestModule]) for the suites of
/// packages that compose it with other modules (the pdf.js adapter's).
///
/// The harness's checks speak of text; a PDF has annotations. The subject
/// maps one onto the other: typing adds a note whose text is what was typed,
/// and the document's text is the notes' texts joined. The runs check the
/// routing — the application's undo and redo reaching the controller, the
/// dirty marker, the views — against the base component's fakes, not PDFium
/// itself (part-forge-integration, *History and the undo conformance
/// harness*).
///
/// Test-only: a package of its own, taken as a dev_dependency by the suites
/// that drive this editor; nothing a product links depends on it.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_pdf_pdfium/tom_forge_pdf_pdfium.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';
import 'package:tom_pdf_editor/testing.dart';
import 'package:tom_pdf_editor/tom_pdf_editor.dart';
import 'package:tom_pdf_pdfium/tom_pdf_pdfium.dart';

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
      'binary document takes no string); the application reopens the editor '
      'instead, tested by FPDF-REOPEN-1. Full conformance is decided after '
      'the comparison (officeproto24)',
};

/// An editor host with no place of its own: what it is asked it reports to
/// the kit state (opened, active, closed).
class ForgePdfTestEditorHost implements ForgeEditorHost {
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

/// A bare kit for the PDF editors' suites: a [DefaultKitApi] over an
/// in-memory state store and [fileSystem] (in memory by default), with an
/// editor host that only reports to the kit state — no shell, no layout.
class ForgePdfTestKit {
  ForgePdfTestKit({TomFileSystem? fileSystem})
    : host = ForgePdfTestEditorHost() {
    api = DefaultKitApi(
      editorHost: host,
      fileSystem: fileSystem ?? TomMemoryFileSystem(),
      stateStore: ForgeMemoryStateStore(),
    );
    host.state = api.state;
  }

  /// The editor host.
  final ForgePdfTestEditorHost host;

  /// The API.
  late final DefaultKitApi api;

  /// Closes [editor] as the application does.
  Future<bool> close(ForgeEditor editor) => host.closeEditor(editor);
}

const _testPath = '/docs/subject.pdf';

/// The notes of [text]: one note, so the joined text is [text] again.
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

/// A usable PDFium library that is not there (the engine is a fake).
const forgePdfTestLibrary = TomPdfiumLibrary.found(
  '/fake/libpdfium.dylib',
  kPdfiumBindingsTag,
);

/// The PDFium module on a fake engine serving [docs] (by path) over the
/// in-memory [files], for a suite that composes it with other modules;
/// [windowFocusRegained] as the module's.
ForgePdfiumModule forgePdfiumTestModule({
  required MemoryBinaryFiles files,
  required Map<String, FakePdfDocument> docs,
  Stream<Object?>? windowFocusRegained,
}) => ForgePdfiumModule(
  files: files,
  locatePdfium: () => forgePdfTestLibrary,
  startEngine: (_) async => FakePdfEngine(docs, files: files),
  decoder: forgePdfTestDecoder,
  authorName: 'Tester',
  windowFocusRegained: windowFocusRegained ?? const Stream.empty(),
);

/// The host of a PDFium subject: its document holds [savedText] as its
/// saved notes, on a fake engine and in-memory files, in a bare kit.
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
    api: ForgePdfTestKit().api,
    files: files,
    locatePdfium: () => forgePdfTestLibrary,
    startEngine: (_) async => engine,
    authorName: 'Tester',
  );
}

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

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_pdf_pdfium_testing/tom_forge_pdf_pdfium_testing.dart'
    show forgePdfiumTestModule;
import 'package:tom_forge_pdf_pdfjs/tom_forge_pdf_pdfjs.dart';
import 'package:tom_forge_pdf_pdfjs_testing/tom_forge_pdf_pdfjs_testing.dart';
import 'package:tom_pdf_editor/testing.dart';
import 'package:tom_pdf_editor/tom_pdf_editor.dart';

/// A bare kit (no shell) with the pdf.js module over a memory file system and
/// in-memory binary files at the same paths; with [withPdfium] the PDFium
/// module too, registered first (as an application composes them) on a fake
/// engine.
class Workspace {
  Workspace({bool withPdfium = false}) : fs = TomMemoryFileSystem() {
    kit = ForgePdfJsTestKit(fileSystem: fs);
    if (withPdfium) {
      pdfium = forgePdfiumTestModule(
        files: files,
        docs: docs,
        windowFocusRegained: focus.stream,
      );
      api.registerModule(pdfium!);
    }
    module = ForgePdfJsModule(
      files: files,
      authorName: 'Tester',
      openExternal: (uri) async => links.add(uri),
      windowFocusRegained: focus.stream,
      channelForTesting: () => pages.last,
      testBaseUri: forgePdfJsTestBaseUri,
    );
    api.registerModule(module);
  }

  final TomMemoryFileSystem fs;
  final files = MemoryBinaryFiles();
  final docs = <String, FakePdfDocument>{};
  late final ForgePdfJsTestKit kit;
  late final ForgePdfJsModule module;

  /// The PDFium module (`tom_forge_pdf_pdfium`), when registered.
  ForgeKitModule? pdfium;

  /// The links the editors opened outside.
  final links = <Uri>[];

  /// Fire to say the window regained focus.
  final focus = StreamController<void>.broadcast();

  /// The scripted pages handed to pdf.js editors, newest last.
  final pages = <ScriptedPdfJsPage>[ScriptedPdfJsPage()];

  DefaultKitApi get api => kit.api;

  Uri add(String path) {
    files.write(path, utf8.encode('%PDF-$path'));
    docs[path] = FakePdfDocument(
      pages: const [PdfPageSize(300, 400)],
      texts: const ['page text'],
    );
    return fs.uriOf(path);
  }

  /// Opens [uri] in the pdf.js editor, as Open With does.
  ForgePdfJsEditor openJs(Uri uri) {
    module.editorChoicesFor(uri).single.open(uri);
    return editorOf(uri)! as ForgePdfJsEditor;
  }

  ForgeEditor? editorOf(Uri uri) =>
      api.state.openEditors.where((e) => e.uri == uri).lastOrNull;

  Future<void> show(WidgetTester tester, ForgeEditor editor) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Builder(builder: editor.buildMain)),
      ),
    );
    await tester.pumpAndSettle();
  }
}

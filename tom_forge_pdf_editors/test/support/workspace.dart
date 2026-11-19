import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_pdf_editors_testing/tom_forge_pdf_editors_testing.dart';
import 'package:tom_forge_pdf_editors/tom_forge_pdf_editors.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_pdf_editor/testing.dart';
import 'package:tom_pdf_editor/tom_pdf_editor.dart';

/// A shell with the module over a memory file system, a fake engine and
/// in-memory binary files at the same paths.
class Workspace {
  Workspace({Uri? root}) : fs = TomMemoryFileSystem(root: root) {
    shell = DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: fs,
      appName: 'PDF editors',
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    engine = FakePdfEngine(docs, files: files);
    module = ForgePdfEditorsModule(
      files: files,
      locatePdfium: () => const TomPdfiumLibrary.found(
        '/fake/libpdfium.dylib',
        kPdfiumBindingsTag,
      ),
      startEngine: (_) async => engine,
      decoder: forgePdfTestDecoder,
      authorName: 'Tester',
      pdfJsChannelForTesting: () => pages.last,
      pdfJsTestBaseUri: Uri.parse('http://pdfjs.test/t/'),
    )..activate(shell);
    (shell.modules as DefaultModuleRegistry).register(module);
  }

  final TomMemoryFileSystem fs;
  final files = MemoryBinaryFiles();
  final docs = <String, FakePdfDocument>{};
  late final FakePdfEngine engine;
  late final DefaultShellApi shell;
  late final ForgePdfEditorsModule module;

  /// The scripted pages handed to pdf.js editors, newest last.
  final pages = <ScriptedPdfJsPage>[ScriptedPdfJsPage()];

  Uri add(String path) {
    files.write(path, utf8.encode('%PDF-$path'));
    docs[path] = FakePdfDocument(
      pages: const [PdfPageSize(300, 400)],
      texts: const ['page text'],
    );
    return fs.uriOf(path);
  }

  ForgeEditor? editorOf(Uri uri) =>
      shell.systemState.openEditors.where((e) => e.uri == uri).lastOrNull;

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

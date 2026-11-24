import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_pdf_pdfium/tom_forge_pdf_pdfium.dart';
import 'package:tom_forge_pdf_pdfium_testing/tom_forge_pdf_pdfium_testing.dart';
import 'package:tom_pdf_editor/testing.dart';
import 'package:tom_pdf_editor/tom_pdf_editor.dart';

/// A bare kit (no shell) with the module over a memory file system, a fake
/// engine and in-memory binary files at the same paths.
class Workspace {
  Workspace({Uri? root}) : fs = TomMemoryFileSystem(root: root) {
    kit = ForgePdfTestKit(fileSystem: fs);
    engine = FakePdfEngine(docs, files: files);
    module = ForgePdfiumModule(
      files: files,
      locatePdfium: () => forgePdfTestLibrary,
      startEngine: (_) async => engine,
      decoder: forgePdfTestDecoder,
      authorName: 'Tester',
      openExternal: (uri) async => links.add(uri),
      windowFocusRegained: focus.stream,
    );
    api.registerModule(module);
  }

  final TomMemoryFileSystem fs;
  final files = MemoryBinaryFiles();
  final docs = <String, FakePdfDocument>{};
  late final FakePdfEngine engine;
  late final ForgePdfTestKit kit;
  late final ForgePdfiumModule module;

  /// The links the editors opened outside.
  final links = <Uri>[];

  /// Fire to say the window regained focus.
  final focus = StreamController<void>.broadcast();

  DefaultKitApi get api => kit.api;

  Uri add(String path) {
    files.write(path, utf8.encode('%PDF-$path'));
    docs[path] = FakePdfDocument(
      pages: const [PdfPageSize(300, 400)],
      texts: const ['page text'],
    );
    return fs.uriOf(path);
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

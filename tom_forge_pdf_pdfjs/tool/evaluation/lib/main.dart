// Copyright (c) 2026 Peter Nicolai Alexis Kyaw
// SPDX-License-Identifier: BSD-3-Clause

/// The PDF routes' evaluation harness as an app: the hosts and the two views
/// the integration tests (`integration_test/pdf_routes_test.dart`) pump. Run
/// it through `run_evaluation.sh`, not on its own.
library;

import 'package:flutter/material.dart';
import 'package:tom_file_session/io.dart';
import 'package:tom_pdf_pdfjs/tom_pdf_pdfjs.dart';
import 'package:tom_pdf_editor/tom_pdf_editor.dart';
import 'package:tom_pdf_pdfium/tom_pdf_pdfium.dart';

/// A desktop host: the binaries layer's PDFium, the real file access, as
/// Forge's `ForgePdfHost` gives the editors.
class EvalPdfHost implements TomPdfEditorHost {
  EvalPdfHost(this.filePath);

  @override
  final String filePath;

  /// The notices the editor gave, as `kind: message`.
  final notices = <String>[];

  @override
  String get name => filePath.split('/').last;

  @override
  String get authorName => 'evaluation';

  @override
  TomBinaryFiles get files => const TomBinaryFileAccess();

  @override
  TomPdfiumLibrary get engineStatus => const TomPdfiumLocator().locate();

  @override
  Future<TomPdfEngine> startEngine(TomPdfiumLibrary library) =>
      PdfiumEngine.acquire(library.path!);

  @override
  void notice(BuildContext context, String message, {required String kind}) =>
      notices.add('$kind: $message');

  @override
  void openLink(String url) {}

  @override
  void historyChanged() {}
}

/// The PDFium editor, as a Forge tab shows it.
class PdfiumEvalApp extends StatelessWidget {
  const PdfiumEvalApp({super.key, required this.controller});

  final TomPdfEditorController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: TomPdfEditor(controller: controller)),
  );
}

/// The pdf.js view in one of its modes, as a Forge tab shows it.
class PdfJsEvalApp extends StatelessWidget {
  const PdfJsEvalApp({super.key, required this.controller});

  final TomPdfJsController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: TomPdfJsView(controller: controller)),
  );
}

void main() {
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'Run integration_test/pdf_routes_test.dart through '
            'run_evaluation.sh.',
          ),
        ),
      ),
    ),
  );
}

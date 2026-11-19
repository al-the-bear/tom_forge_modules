// Copyright (c) 2026 Peter Nicolai Alexis Kyaw
// SPDX-License-Identifier: BSD-3-Clause

/// One file through the PDFium route in a process of its own, for the crash
/// isolation measure: PDFium runs inside Forge's process, so a crash on a
/// damaged file ends it. run_evaluation.py starts this once per file
/// (`EVAL_PROBE_FILE`, optionally `EVAL_PROBE_PASSWORD`) and reads the
/// `PROBE` lines and the exit status.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_pdf_editor/io.dart';
import 'package:tom_pdf_editor/pdfium.dart';

void main() {
  final file = Platform.environment['EVAL_PROBE_FILE'];
  final password = Platform.environment['EVAL_PROBE_PASSWORD'];

  test('PROBE: open, render and read every page (up to 20)', () async {
    expect(file, isNotNull, reason: 'EVAL_PROBE_FILE');
    final library = const TomPdfiumLocator().locate();
    final engine = await PdfiumEngine.acquire(library.path!);
    final opened = await engine.open(file!, password: password);
    final info = opened.info;
    if (info == null) {
      print('PROBE open refused ${opened.error?.name}: ${opened.message}');
    } else {
      print('PROBE open ok pages=${info.pageCount}');
      final last = info.pageCount < 20 ? info.pageCount : 20;
      for (var p = 0; p < last; p++) {
        final size = info.pages[p];
        final w = size.width.round();
        final h = size.height.round();
        final tile = await engine.render(
          info.handle,
          p,
          scale: 1,
          x: 0,
          y: 0,
          pxW: w,
          pxH: h,
        );
        final chars = await engine.charCount(info.handle, p);
        print('PROBE page ${p + 1} rendered=${tile != null} chars=$chars');
      }
      await engine.close(info.handle);
    }
    await engine.release();
    print('PROBE done');
  });
}

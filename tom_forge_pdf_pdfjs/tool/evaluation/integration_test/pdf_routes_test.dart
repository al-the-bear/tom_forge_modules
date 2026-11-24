// Copyright (c) 2026 Peter Nicolai Alexis Kyaw
// SPDX-License-Identifier: BSD-3-Clause

/// The PDF routes' evaluation (office/PDF prototype, `part-evaluation` and
/// `part-pdf-pdfjs` § *What the comparison with PDFium measures*): the
/// PDFium route, then the pdf.js route in each of its three modes, over the
/// public sample set, each writing `results/<route>/run-<n>.yaml`.
///
/// Measures: rendering fidelity against macOS Preview (PDFKit) and the other
/// route; open time, scrolling and zooming (jank), whole-document search;
/// memory on pdf-long and pdf-huge; annotations (the kinds, made, saved
/// incrementally, read back by Preview and the other route); forms (filled,
/// saved, read back by the other route and Preview); pdf.js's crash
/// isolation (damaged files, a killed content process). The PDFium route's
/// crash isolation runs in processes of its own (run_evaluation.py), since
/// a crash there ends the process.
///
/// A measure that fails is recorded as not measured with its error; the run
/// goes on. Started by `run_evaluation.py` (flutter drive --profile).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tom_forge_pdf_route_evaluation/eval_support.dart';
import 'package:tom_forge_pdf_route_evaluation/main.dart';
import 'package:tom_pdf_pdfjs/tom_pdf_pdfjs.dart';
import 'package:tom_pdf_editor/tom_pdf_editor.dart';
import 'package:tom_pdf_pdfium/tom_pdf_pdfium.dart';

/// `EVAL_ONLY` (comma-separated routes) runs only those; empty runs all.
const _only = String.fromEnvironment('EVAL_ONLY');
bool _runs(String route) => _only.isEmpty || _only.split(',').contains(route);

/// The samples every route opens, in order (the first open of a route is
/// its cold start).
const _openSamples = [
  'pdf-text.pdf',
  'pdf-scan.pdf',
  'pdf-long.pdf',
  'pdf-huge.pdf',
  'pdf-form.pdf',
  'pdf-annot.pdf',
  'pdf-encrypted.pdf',
];

/// PDF annotation subtypes by number (ISO 32000 table 169).
const _subtypes = {
  1: 'Text',
  3: 'FreeText',
  9: 'Highlight',
  13: 'Stamp',
  15: 'Ink',
  20: 'Widget',
};

String _subtype(int n) => _subtypes[n] ?? 'subtype $n';

/// The PDFium route's page images, for the pdf.js route's comparison:
/// `<sample>-p<page>` → path.
final _pdfiumPages = <String, String>{};

/// Where pdf.js's comparisons find the PDFium route's saved files.
String get _pdfiumAnnotated => '${EvalConfig.work}/pdfium-annot.pdf';
String get _pdfiumForm => '${EvalConfig.work}/pdfium-form.pdf';

/// Runs [measure]; its error recorded as not measured.
Future<Object?> _measure(
  String name,
  Future<Object?> Function() measure,
) async {
  print('[eval] $name');
  try {
    return await measure();
  } catch (e, s) {
    print('[eval] $name failed: $e\n$s');
    return notMeasured('the harness failed: $e');
  }
}

int _ms(Stopwatch w) => w.elapsedMilliseconds;

/// The width and height of a PNG file.
(int, int) _pngSize(String path) {
  final b = File(path).readAsBytesSync();
  int u32(int o) =>
      (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
  return (u32(16), u32(20));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Directory(EvalConfig.work).createSync(recursive: true);

  Future<void> waitFor(
    WidgetTester tester,
    FutureOr<bool> Function() done, {
    required String what,
    Duration timeout = const Duration(seconds: 120),
    Duration step = const Duration(milliseconds: 20),
  }) async {
    final end = DateTime.now().add(timeout);
    while (!await done()) {
      if (DateTime.now().isAfter(end)) {
        throw TimeoutException('timed out waiting for $what', timeout);
      }
      await tester.pump(step);
    }
  }

  Future<void> idle(WidgetTester tester, Duration d) async {
    final end = DateTime.now().add(d);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Collects the frames drawn while [body] runs.
  Future<List<ui.FrameTiming>> frames(Future<void> Function() body) async {
    final timings = <ui.FrameTiming>[];
    void collect(List<ui.FrameTiming> t) => timings.addAll(t);
    final policy = binding.framePolicy;
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    SchedulerBinding.instance.addTimingsCallback(collect);
    try {
      await body();
      // Timings arrive in batches about once a second.
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(collect);
      binding.framePolicy = policy;
    }
    return timings;
  }

  /// Compares [routePng] with Preview's rendering of the same page and,
  /// for pdf.js, with the PDFium route's; the major ones kept as
  /// screenshots under `results/<route>/screenshots/`.
  Map<String, Object?> compare(
    String route,
    String sample,
    int page,
    String routePng, {
    String? password,
  }) {
    final key = '${sample.replaceAll('.pdf', '')}-p${page + 1}';
    final (w, h) = _pngSize(routePng);
    final preview = '${EvalConfig.work}/preview-$key-${w}x$h.png';
    if (!File(preview).existsSync()) {
      pdfKitRender(
        EvalConfig.sample(sample),
        page,
        w,
        h,
        preview,
        password: password,
      );
    }
    final out = <String, Object?>{'page': page + 1, 'pixels': '${w}x$h'};
    void against(String name, String other) {
      final marked = '${EvalConfig.work}/$route-$key-vs-$name.png';
      final d = pixelDiff(routePng, other, marked: marked);
      final verdict = verdictOf(d.ratio);
      out['vs_$name'] = {
        'differing_pixels': d.ratio,
        'differing_pixels_without_shift_tolerance': d.raw,
        'mean_abs_difference': d.mean,
        'verdict': verdict,
      };
      if (verdict == 'major' && EvalConfig.screenshots) {
        final dir = Directory('${EvalConfig.results}/$route/screenshots')
          ..createSync(recursive: true);
        File(routePng).copySync('${dir.path}/$key-$route.png');
        File(other).copySync('${dir.path}/$key-$name.png');
        File(marked).copySync('${dir.path}/$key-vs-$name-diff.png');
        (out['vs_$name']! as Map)['screenshots'] =
            'screenshots/$key-$route.png, screenshots/$key-$name.png, '
            'screenshots/$key-vs-$name-diff.png';
      }
    }

    against('preview', preview);
    if (route != 'pdfium') {
      final pdfium = _pdfiumPages[key];
      if (pdfium != null) {
        against('pdfium', pdfium);
      } else {
        out['vs_pdfium'] = notMeasured('the PDFium route has no image of it');
      }
    }
    return out;
  }

  /// The file verdicts of [pages] (worst page wins) against [reference].
  Map<String, String> fileVerdicts(
    Map<String, List<Map<String, Object?>>> pages,
    String reference,
  ) => {
    for (final e in pages.entries)
      e.key: e.value.fold<String>('identical', (v, p) {
        final r = p['vs_$reference'];
        return r is Map && r['verdict'] is String
            ? worse(v, r['verdict']! as String)
            : v;
      }),
  };

  // ======================================================================
  // PDFium
  // ======================================================================

  testWidgets(
    'EVAL-PDFIUM: the PDFium route',
    skip: !_runs('pdfium'),
    (tester) => _guarded((errors) async {
      final library = const TomPdfiumLocator().locate();
      expect(library.isUsable, isTrue, reason: library.message);
      final results = <String, Object?>{
        'route': 'pdfium',
        'environment': environmentInfo(
          engines: {'pdfium': library.tag, 'pdfium_library': library.path},
        ),
        'size': {
          'pdfium_dylib_bytes': diskBytes(library.path!),
          'note':
              'the library is loaded from the binaries layer; the Dart '
              'code of the route is tom_pdf_editor (the editor), '
              'tom_pdf_pdfium (the engine) and tom_forge_pdf_pdfium',
        },
      };
      PdfiumViewFinder.tester = tester;

      // ---------------------------------------------------------------- open
      TomPdfEngine? hold;
      final opens = <String, Object?>{};
      final memory = <String, Object?>{};
      for (final (i, sample) in _openSamples.indexed) {
        opens[sample] = await _measure('pdfium open $sample', () async {
          final c = TomPdfEditorController(
            EvalPdfHost(EvalConfig.sample(sample)),
          );
          await tester.pumpWidget(PdfiumEvalApp(controller: c));
          final w = Stopwatch()..start();
          final opening = c.open();
          await waitFor(
            tester,
            () =>
                c.state == TomPdfEditorState.open ||
                c.state == TomPdfEditorState.password ||
                c.state == TomPdfEditorState.failed,
            what: 'pdfium: $sample opened',
          );
          if (c.state == TomPdfEditorState.password) {
            await c.answerPassword(evalEncryptedPassword);
            await waitFor(
              tester,
              () => c.state != TomPdfEditorState.password,
              what: 'pdfium: $sample unlocked',
            );
          }
          await opening;
          final openMs = _ms(w);
          if (c.state != TomPdfEditorState.open) {
            final failure = c.failure;
            await c.close();
            return {'opened': false, 'failure': failure};
          }
          await waitFor(
            tester,
            () => PdfiumViewFinder.drawn(0),
            what: 'pdfium: $sample page 1 drawn',
          );
          final first = _ms(w);
          if (i == 0) {
            // The engine stays up from here: the later opens are warm.
            hold = await PdfiumEngine.acquire(library.path!);
          }
          final r = {
            'opened': true,
            'pages': c.info!.pageCount,
            'encrypted': c.info!.encrypted,
            'start': i == 0 ? 'cold (the engine started)' : 'warm',
            'open_ms': openMs,
            'first_page_ms': first,
          };
          if (sample == 'pdf-long.pdf' || sample == 'pdf-huge.pdf') {
            memory['$sample after open'] = memorySample();
          }
          await tester.pumpWidget(const SizedBox());
          await c.close();
          return r;
        });
      }
      opens['pdf-text.pdf second open'] = await _measure(
        'pdfium second open',
        () async {
          final c = TomPdfEditorController(
            EvalPdfHost(EvalConfig.sample('pdf-text.pdf')),
          );
          await tester.pumpWidget(PdfiumEvalApp(controller: c));
          final w = Stopwatch()..start();
          await c.open();
          final openMs = _ms(w);
          await waitFor(
            tester,
            () => PdfiumViewFinder.drawn(0),
            what: 'pdfium: second open drawn',
          );
          final r = {
            'open_ms': openMs,
            'first_page_ms': _ms(w),
            'start': 'warm',
          };
          await tester.pumpWidget(const SizedBox());
          await c.close();
          return r;
        },
      );
      results['open'] = opens;

      // ------------------------------------------------------------ fidelity
      results['fidelity'] = await _measure('pdfium fidelity', () async {
        final engine = await PdfiumEngine.acquire(library.path!);
        final pages = <String, List<Map<String, Object?>>>{};
        try {
          for (final MapEntry(key: sample, value: list)
              in evalFidelityPages.entries) {
            final password = sample == 'pdf-encrypted.pdf'
                ? evalEncryptedPassword
                : null;
            final opened = await engine.open(
              EvalConfig.sample(sample),
              password: password,
            );
            final info = opened.info!;
            pages[sample] = [];
            for (final page in list) {
              final size = info.pages[page];
              final w = (size.width * evalFidelityScale).round();
              final h = (size.height * evalFidelityScale).round();
              final tile = await engine.render(
                info.handle,
                page,
                scale: evalFidelityScale,
                x: 0,
                y: 0,
                pxW: w,
                pxH: h,
              );
              final key = '${sample.replaceAll('.pdf', '')}-p${page + 1}';
              final png = '${EvalConfig.work}/pdfium-$key.png';
              File(png).writeAsBytesSync(await bgraToPng(tile!.bgra, w, h));
              _pdfiumPages[key] = png;
              pages[sample]!.add(
                compare('pdfium', sample, page, png, password: password),
              );
            }
            await engine.close(info.handle);
          }
        } finally {
          await engine.release();
        }
        return {
          'scale_px_per_pt': evalFidelityScale,
          'method':
              'every page rendered by the route and by PDFKit (macOS '
              'Preview\'s renderer) at the same pixel size; the share of '
              'pixels whose largest channel differs by more than 40 of 255 '
              'and that no pixel within one pixel of the other image matches '
              '(both ways: a glyph placed one pixel apart is no difference, '
              'missing content is). '
              'Verdicts are automatic: identical < 0.5 %, minor < 5 %, major '
              'otherwise; the human verdict is the report\'s.',
          'file_verdict_vs_preview': fileVerdicts(pages, 'preview'),
          'pages': pages,
        };
      });

      // -------------------------------------------------------------- search
      final searches = <String, Object?>{};
      for (final MapEntry(key: sample, value: term)
          in evalSearchTerms.entries) {
        searches[sample] = await _measure('pdfium search $sample', () async {
          final c = TomPdfEditorController(
            EvalPdfHost(EvalConfig.sample(sample)),
          );
          await tester.pumpWidget(PdfiumEvalApp(controller: c));
          await c.open();
          await tester.pump();
          final w = Stopwatch()..start();
          c.find(term);
          int? firstHit;
          await waitFor(
            tester,
            () {
              if (firstHit == null && c.hits.isNotEmpty) firstHit = _ms(w);
              return !c.searching;
            },
            what: 'pdfium: search $sample',
            timeout: const Duration(minutes: 5),
          );
          final whole = _ms(w);
          final r = {
            'term': term,
            'pages': c.info!.pageCount,
            'hits': c.hits.length,
            'first_hit_ms': firstHit,
            'whole_document_ms': whole,
            'case_sensitive': false,
          };
          await tester.pumpWidget(const SizedBox());
          await c.close();
          return r;
        });
      }
      results['search'] = searches;

      // ------------------------------------------- scrolling, zoom, memory
      results['scrolling'] = _lockedFrames(
        await _measure('pdfium scrolling', () async {
          final out = <String, Object?>{};
          for (final (sample, pagesThrough, seconds) in [
            ('pdf-long.pdf', 200, 10),
            ('pdf-huge.pdf', 50, 10),
          ]) {
            final c = TomPdfEditorController(
              EvalPdfHost(EvalConfig.sample(sample)),
            );
            await tester.pumpWidget(PdfiumEvalApp(controller: c));
            await c.open();
            await waitFor(
              tester,
              () => PdfiumViewFinder.drawn(0),
              what: 'pdfium: $sample drawn',
            );
            final v = PdfiumViewFinder.view;
            final target = v.layout.pageTop(pagesThrough);
            final timings = await frames(() async {
              unawaited(
                v.vertical.animateTo(
                  target,
                  duration: Duration(seconds: seconds),
                  curve: Curves.linear,
                ),
              );
              await idle(tester, Duration(seconds: seconds));
            });
            out[sample] = {
              'scripted':
                  'animated scroll through $pagesThrough pages in '
                  '$seconds s at fit width',
              ...frameStats(timings),
            };
            memory['$sample after scrolling'] = memorySample();
            if (sample == 'pdf-long.pdf') {
              // Zoom 50 % → 400 % with the zoom bar, page by page.
              c.restoreView(
                const PdfViewPosition(page: 0, offset: 0, zoom: 50),
              );
              await tester.pumpWidget(PdfiumEvalApp(controller: c));
              await idle(tester, const Duration(seconds: 1));
              var taps = 0;
              final zoomTimings = await frames(() async {
                while (PdfiumViewFinder.view.widget.zoom < 400 && taps < 20) {
                  await tester.tap(find.byTooltip('Zoom in'));
                  taps++;
                  await idle(tester, const Duration(milliseconds: 400));
                }
                await idle(tester, const Duration(seconds: 1));
              });
              out['zoom 50 % to 400 % (pdf-long)'] = {
                'scripted':
                    'the zoom bar\'s Zoom in, $taps steps, 400 ms apart',
                'reached_zoom': PdfiumViewFinder.view.widget.zoom,
                ...frameStats(zoomTimings),
              };
            }
            await tester.pumpWidget(const SizedBox());
            await c.close();
          }
          return out;
        }),
      );
      results['memory'] = {
        ...memory,
        'after ten minutes of editing': notMeasured(
          'a PDF route has no editing session of that length: its edits are '
          'annotations and form fields, measured below',
        ),
      };

      // --------------------------------------------------------- annotations
      results['annotations'] = await _measure('pdfium annotations', () async {
        final path = EvalConfig.copy('pdf-text.pdf', 'pdfium-annot.pdf');
        final original = File(path).readAsBytesSync();
        final c = TomPdfEditorController(EvalPdfHost(path));
        await tester.pumpWidget(PdfiumEvalApp(controller: c));
        await c.open();
        await tester.pump();
        // Highlight: a word selected (the first hit of a search), then the
        // highlight command, as the Highlight tool does on a selection.
        c.find('Chain');
        await waitFor(tester, () => !c.searching, what: 'search for a word');
        final hit = c.hits.first;
        final r = hit.rects.first;
        c.hideFind();
        await c.selectAround(
          hit.page,
          (r.left + r.right) / 2,
          (r.top + r.bottom) / 2,
          line: false,
        );
        final highlighted = await c.highlightSelection();
        final note = await c.addNote(0, 60, 60, 'PDFium note');
        final ink = await c.addInk(0, [
          [
            for (var i = 0; i <= 10; i++)
              (x: 100.0 + i * 20, y: 700.0 + (i.isEven ? 8 : -8)),
          ],
        ]);
        await tester.pump();
        final w = Stopwatch()..start();
        await c.save();
        final saveMs = _ms(w);
        final saved = File(path).readAsBytesSync();
        final prefix =
            saved.length > original.length &&
            _same(saved.sublist(0, original.length), original);
        final engine = c.engine!;
        final read = await engine.annotations(c.info!.handle, 0);
        await tester.pumpWidget(const SizedBox());
        await c.close();
        // pdf-annot's own annotations as PDFium reads them.
        final reader = await PdfiumEngine.acquire(library.path!);
        final annot = (await reader.open(
          EvalConfig.sample('pdf-annot.pdf'),
        )).info!;
        final existing = {
          for (final a in await reader.annotations(annot.handle, 0))
            _subtype(a.subtype),
        }.toList()..sort();
        await reader.close(annot.handle);
        await reader.release();
        return {
          'kinds_offered': [
            for (final t in PdfAnnotationTool.values)
              if (t != PdfAnnotationTool.select) t.name,
          ],
          'made': {
            'highlight': highlighted,
            'note': note != null,
            'ink': ink != null,
          },
          'saved': {
            'save_ms': saveMs,
            'incremental': prefix,
            'bytes_before': original.length,
            'bytes_after': saved.length,
          },
          'read_back': {
            'pdfium_after_reopen': [for (final a in read) _subtype(a.subtype)]
              ..sort(),
            'preview_pdfkit': pdfKitAnnotations(path),
            'chrome': notMeasured(
              'Chrome\'s PDF viewer draws nothing in headless Chrome (a '
              'screenshot of pdf-annot.pdf came back blank), so its view '
              'cannot be read automatically; it is a checklist item for a '
              'person (open evaluation work file pdfium-annot.pdf in Chrome)',
            ),
            'pdfjs': 'measured by the pdf.js runs (annotations.reads_pdfium)',
          },
          'existing_in_pdf_annot_page_1': existing,
          'existing_in_pdf_annot_preview': pdfKitAnnotations(
            EvalConfig.sample('pdf-annot.pdf'),
          ).where((a) => a.startsWith('0:')).toList(),
        };
      });

      // --------------------------------------------------------------- forms
      results['forms'] = await _measure('pdfium forms', () async {
        final path = EvalConfig.copy('pdf-form.pdf', 'pdfium-form.pdf');
        final original = File(path).readAsBytesSync();
        final c = TomPdfEditorController(EvalPdfHost(path));
        await tester.pumpWidget(PdfiumEvalApp(controller: c));
        await c.open();
        await tester.pump();
        final engine = c.engine!;
        final fields = await engine.formFields(c.info!.handle, 0);
        final text = fields.firstWhere((f) => f.name == 'Text1');
        final box = fields.firstWhere((f) => f.type == PdfFieldType.checkbox);
        double cx(PdfFormField f) => (f.rect.left + f.rect.right) / 2;
        double cy(PdfFormField f) => (f.rect.top + f.rect.bottom) / 2;
        await c.formClick(0, cx(text), cy(text));
        await c.formKey(PdfFormKey.selectAll);
        await c.formText('PDFium 42');
        await c.formClick(0, cx(box), cy(box));
        await c.releaseFormFocus();
        await c.save();
        final saved = File(path).readAsBytesSync();
        final now = await c.engine!.formFields(c.info!.handle, 0);
        await tester.pumpWidget(const SizedBox());
        await c.close();
        return {
          'fields_on_page_1': {
            for (final t in PdfFieldType.values)
              t.name: fields.where((f) => f.type == t).length,
          },
          'filled': {
            'Text1': 'PDFium 42',
            box.name: 'ticked',
            'combo_and_list_boxes': notMeasured(
              'the PDFium editor fills text fields, checkboxes and radio '
              'buttons; combo and list boxes are left out (DPPF-4)',
            ),
          },
          'incremental': _same(saved.sublist(0, original.length), original),
          'pdfium_after_reopen': {
            'Text1': now.firstWhere((f) => f.name == 'Text1').value,
            box.name: now.firstWhere((f) => f.name == box.name).checked,
          },
          'preview_pdfkit': pdfKitFields(path)
              .where((f) => f.startsWith('Text1') || f.startsWith(box.name))
              .toList(),
          'pdfjs': 'measured by the pdf.js runs (forms.reads_pdfium)',
        };
      });

      results['crash_isolation'] =
          'in-process: measured in processes of their own by run_evaluation.py '
          '(results/pdfium/crash-isolation.yaml)';
      await hold?.release();
      results['framework_errors'] = _errorSummary(errors);
      writeResults('pdfium', results);
    }),
    timeout: const Timeout(Duration(minutes: 40)),
  );

  // ======================================================================
  // pdf.js
  // ======================================================================

  for (final mode in TomPdfJsMode.values) {
    final route = 'pdfjs-${mode.name}';
    if (!_runs(route)) continue;
    testWidgets(
      'EVAL-PDFJS-${mode.name}: the pdf.js route in ${mode.name} '
      'mode',
      (tester) => _guarded((errors) async {
        final contentBefore = webContentPids();
        final results = <String, Object?>{'route': route, 'mode': mode.name};
        final memory = <String, Object?>{};

        Future<bool> js(TomPdfJsViewState view, String source) async {
          if (screenLocked) await view.evaluate(_nudge);
          return await view.evaluate(source) == true;
        }

        Future<(TomPdfJsController, TomPdfJsViewState)> open(
          String path, {
          String? password,
          bool waitOpen = true,
        }) async {
          final c = TomPdfJsController(EvalPdfHost(path), mode: mode);
          await tester.pumpWidget(PdfJsEvalApp(controller: c));
          final view = tester.state<TomPdfJsViewState>(
            find.byType(TomPdfJsView),
          );
          // On a locked screen the page gets no animation frames: a stand-in
          // is put in before pdf.js draws (see _rafStandIn).
          var standIn = !screenLocked;
          Future<void> installStandIn() async {
            if (!standIn) standIn = await js(view, _rafStandIn);
          }

          if (!waitOpen) {
            final end = DateTime.now().add(const Duration(seconds: 10));
            while (!standIn && DateTime.now().isBefore(end)) {
              await installStandIn();
              await tester.pump(const Duration(milliseconds: 5));
            }
            return (c, view);
          }
          await waitFor(
            tester,
            () async {
              await installStandIn();
              if (password != null && c.state == TomPdfJsState.opening) {
                await _answerPassword(view, password);
              }
              return c.state == TomPdfJsState.open ||
                  c.state == TomPdfJsState.failed;
            },
            what: '$route: ${path.split('/').last} open',
            step: const Duration(milliseconds: 20),
          );
          return (c, view);
        }

        Future<void> close(TomPdfJsController c) async {
          await tester.pumpWidget(const SizedBox());
          await c.close();
          await idle(tester, const Duration(milliseconds: 300));
        }

        const page1 = '.page[data-page-number="1"]';

        // ----------------------------------------------------- open, fidelity
        final opens = <String, Object?>{};
        final fidelity = <String, List<Map<String, Object?>>>{};
        var version = '?';
        for (final (i, sample) in _openSamples.indexed) {
          opens[sample] = await _measure('$route open $sample', () async {
            final password = sample == 'pdf-encrypted.pdf'
                ? evalEncryptedPassword
                : null;
            final w = Stopwatch()..start();
            final (c, view) = await open(
              EvalConfig.sample(sample),
              password: password,
            );
            final openMs = _ms(w);
            if (c.state != TomPdfJsState.open) {
              final failure = c.failure;
              await close(c);
              return {'opened': false, 'failure': failure};
            }
            try {
              await waitFor(tester, () async {
                if (screenLocked) await js(view, _nudge);
                return js(view, _pageDrawn(1));
              }, what: '$route: $sample page 1 drawn');
            } on TimeoutException {
              print(
                '[eval] page 1 not drawn: ${await view.evaluate(_pageState)}',
              );
              rethrow;
            }
            final first = _ms(w);
            version = '${await view.evaluate('globalThis.pdfjsLib?.version')}';
            final r = <String, Object?>{
              'opened': true,
              'pages': c.pageCount,
              'start': i == 0
                  ? 'cold (webview, content process and pdf.js started)'
                  : 'warm',
              'open_ms': openMs,
              'first_page_ms': first,
            };
            if (sample == 'pdf-long.pdf' || sample == 'pdf-huge.pdf') {
              memory['$sample after open'] = memorySample(
                webContent: webContentPids().difference(contentBefore),
              );
            }
            final pages = evalFidelityPages[sample];
            if (pages != null) {
              fidelity[sample] = [
                for (final page in pages)
                  await _renderAndCompare(
                    route,
                    view,
                    sample,
                    page,
                    password,
                    compare,
                  ),
              ];
            }
            await close(c);
            return r;
          });
        }
        results['environment'] = environmentInfo(
          engines: {
            'pdfjs': version,
            'pdfjs_build': 'legacy, vendored',
            // On a locked screen the page's requestAnimationFrame is a
            // stand-in and the viewer is asked to draw (see _rafStandIn).
            'raf_stand_in': screenLocked,
          },
        );
        results['size'] = {
          'pdfjs_assets_bytes': diskBytes(_assetsFolder()),
          'note':
              'the pdf.js assets and Forge\'s bridge as shipped in the '
              'app bundle (flutter_assets/packages/tom_pdf_pdfjs)',
        };
        results['open'] = opens;
        results['fidelity'] = {
          'scale_px_per_pt': evalFidelityScale,
          'method':
              'pdf.js renders each page itself (page.render into a '
              'canvas, annotations and forms drawn) at the PDFium image\'s '
              'pixel size; compared with PDFKit (Preview) and with the PDFium '
              'route as the PDFium results say. The renderer is the same in '
              'every mode; it is measured per mode all the same.',
          'file_verdict_vs_preview': fileVerdicts(fidelity, 'preview'),
          'file_verdict_vs_pdfium': fileVerdicts(fidelity, 'pdfium'),
          'pages': fidelity,
        };

        // -------------------------------------------------------- search
        final searches = <String, Object?>{};
        for (final MapEntry(key: sample, value: term)
            in evalSearchTerms.entries) {
          searches[sample] = await _measure('$route search $sample', () async {
            final (c, view) = await open(EvalConfig.sample(sample));
            await idle(tester, const Duration(milliseconds: 500));
            final w = Stopwatch()..start();
            await c.find(term);
            var hits = -1;
            await waitFor(
              tester,
              () async {
                final n = await view.evaluate(_findDone);
                hits = n is num ? n.toInt() : -1;
                return hits >= 0;
              },
              what: '$route: search $sample',
              timeout: const Duration(minutes: 5),
            );
            final r = {
              'term': term,
              'pages': c.pageCount,
              'hits': hits,
              'whole_document_ms': _ms(w),
              'case_sensitive': false,
              'note':
                  'pdf.js\'s find controller over every page; done when '
                  'each page has its matches',
            };
            await close(c);
            return r;
          });
        }
        results['search'] = searches;

        // --------------------------------------- scrolling, zoom, memory
        results['scrolling'] = _lockedFrames(
          await _measure('$route scrolling', () async {
            final out = <String, Object?>{};
            for (final sample in ['pdf-long.pdf', 'pdf-huge.pdf']) {
              final (c, view) = await open(EvalConfig.sample(sample));
              await waitFor(
                tester,
                () => js(view, '!!document.querySelector(\'$page1 canvas\')'),
                what: '$route: $sample drawn',
              );
              await view.evaluate(
                'forgeBridge.test.adapter.zoom("page-width"); true',
              );
              await idle(tester, const Duration(seconds: 1));
              final intervals = await _rafRun(tester, view, _scrollScript);
              out[sample] = {
                'scripted':
                    'the viewer scrolled 40 px per animation frame for '
                    '600 frames (about 20 pages) at fit width',
                'measured_in':
                    'the web page (requestAnimationFrame intervals); '
                    'coarser than Flutter\'s frame timings',
                ...intervalStats(intervals),
              };
              memory['$sample after scrolling'] = memorySample(
                webContent: webContentPids().difference(contentBefore),
              );
              if (sample == 'pdf-long.pdf') {
                final zoom = await _rafRun(tester, view, _zoomScript);
                out['zoom 50 % to 400 % (pdf-long)'] = {
                  'scripted':
                      'the scale set from 0.5 to 4 in 0.25 steps, one '
                      'step every 12 animation frames',
                  ...intervalStats(zoom),
                };
              }
              await close(c);
            }
            return out;
          }),
        );
        results['memory'] = {
          ...memory,
          'note':
              'the app process and the WebKit content processes started '
              'during this route\'s run (WebKit starts them as XPC services, '
              'so they are found by being new, not by their parent)',
          'after ten minutes of editing': notMeasured(
            'a PDF route has no editing session of that length: its edits are '
            'annotations and form fields, measured below',
          ),
        };

        // ----------------------------------------------------- annotations
        results['annotations'] = await _measure('$route annotations', () async {
          final path = EvalConfig.copy(
            'pdf-text.pdf',
            'pdfjs-${mode.name}-annot.pdf',
          );
          final original = File(path).readAsBytesSync();
          final (c, view) = await open(path);
          await waitFor(
            tester,
            () => js(
              view,
              '!!document.querySelector(\'$page1 .textLayer span\')',
            ),
            what: '$route: text layer',
          );
          final made = <String, Object?>{};
          await c.setTool(TomPdfJsTool.highlight);
          await idle(tester, const Duration(milliseconds: 300));
          made['highlight'] =
              await js(view, 'forgeBridge.test.selectText(1, 40)') &&
              await js(view, 'forgeBridge.test.highlightSelection(); true');
          await c.setTool(TomPdfJsTool.ink);
          await waitFor(
            tester,
            () => js(
              view,
              '!!document.querySelector(\'$page1 .annotationEditorLayer\')',
            ),
            what: '$route: editor layer',
          );
          await idle(tester, const Duration(milliseconds: 300));
          await js(
            view,
            'forgeBridge.test.pointer(1, "pointerdown", 0.2, 0.55)',
          );
          for (var i = 1; i <= 10; i++) {
            await js(
              view,
              'forgeBridge.test.pointer(1, "pointermove", ${0.2 + i * 0.03}, '
              '${0.55 + (i.isEven ? 0.02 : -0.02)})',
            );
          }
          made['ink'] = await js(
            view,
            'forgeBridge.test.pointer(1, "pointerup", 0.5, 0.55)',
          );
          await idle(tester, const Duration(milliseconds: 300));
          await c.setTool(TomPdfJsTool.freeText);
          await idle(tester, const Duration(milliseconds: 300));
          await js(
            view,
            'forgeBridge.test.pointer(1, "pointerdown", 0.6, 0.2)',
          );
          await js(view, 'forgeBridge.test.pointer(1, "pointerup", 0.6, 0.2)');
          await waitFor(
            tester,
            () => js(
              view,
              '!!document.querySelector(".freeTextEditor .internal")',
            ),
            what: '$route: free text editor',
          );
          made['free_text'] = await js(
            view,
            'forgeBridge.test.typeFreeText("pdf.js free text")',
          );
          await c.setTool(TomPdfJsTool.none);
          await waitFor(
            tester,
            () => js(
              view,
              '(() => { const t = forgeBridge.test.storage().types; '
              'return [3, 9, 15].every((k) => t.includes(k)); })()',
            ),
            what: '$route: annotations in the storage',
          );
          made['stamp'] = notMeasured(
            'the stamp tool asks for an image through a file dialog, which '
            'the harness cannot answer; its presence is in kinds_offered',
          );
          final before = c.generation;
          final w = Stopwatch()..start();
          await c.save();
          await waitFor(
            tester,
            () => c.generation > before && c.state == TomPdfJsState.open,
            what: '$route: saved and reopened',
          );
          final saveMs = _ms(w);
          final saved = File(path).readAsBytesSync();
          await close(c);
          final engine = await PdfiumEngine.acquire(
            const TomPdfiumLocator().locate().path!,
          );
          final doc = (await engine.open(path)).info!.handle;
          final pdfium = [
            for (final a in await engine.annotations(doc, 0))
              _subtype(a.subtype),
          ]..sort();
          await engine.close(doc);
          await engine.release();
          // PDFium's annotations as pdf.js reads them.
          Object? readsPdfium;
          if (File(_pdfiumAnnotated).existsSync()) {
            final (p, pv) = await open(_pdfiumAnnotated);
            readsPdfium = await pv.evaluateAsync(
              'const doc = forgeBridge.test.document; '
              'const a = await (await doc.getPage(1)).getAnnotations(); '
              'return a.map((x) => x.subtype).filter((s) => s !== "Link" && '
              's !== "Widget").sort();',
            );
            await close(p);
          } else {
            readsPdfium = notMeasured('the PDFium run saved no annotated file');
          }
          return {
            'kinds_offered': ['freeText', 'highlight', 'stamp', 'ink'],
            'made': made,
            'saved': {
              'save_ms': saveMs,
              'incremental':
                  saved.length > original.length &&
                  _same(saved.sublist(0, original.length), original),
              'bytes_before': original.length,
              'bytes_after': saved.length,
            },
            'read_back': {
              'pdfium': pdfium,
              'preview_pdfkit': pdfKitAnnotations(
                path,
              ).where((a) => a.startsWith('0:')).toList(),
              'chrome': notMeasured(
                'Chrome\'s PDF viewer draws nothing in headless Chrome, so its '
                'view cannot be read automatically; a checklist item for a '
                'person',
              ),
            },
            'reads_pdfium': readsPdfium,
          };
        });

        // ----------------------------------------------------------- forms
        results['forms'] = await _measure('$route forms', () async {
          final path = EvalConfig.copy(
            'pdf-form.pdf',
            'pdfjs-${mode.name}-form.pdf',
          );
          final original = File(path).readAsBytesSync();
          final (c, view) = await open(path);
          await waitFor(
            tester,
            () => js(
              view,
              '!!document.querySelector(\'.annotationLayer [name="Text1"]\')',
            ),
            what: '$route: form fields',
          );
          final text = await js(
            view,
            'forgeBridge.test.fillField("Text1", "pdf.js 42")',
          );
          final box = await js(
            view,
            'document.querySelector(\'.annotationLayer input[type="checkbox"]\')'
            '.click(); true',
          );
          // A combo box and a list box: their second option chosen.
          final choices = await view.evaluate(_chooseSecondOptions);
          await waitFor(tester, () => c.isDirty, what: '$route: form modified');
          final before = c.generation;
          await c.save();
          await waitFor(
            tester,
            () => c.generation > before && c.state == TomPdfJsState.open,
            what: '$route: form saved and reopened',
          );
          await close(c);
          final saved = File(path).readAsBytesSync();
          final engine = await PdfiumEngine.acquire(
            const TomPdfiumLocator().locate().path!,
          );
          final doc = (await engine.open(path)).info!.handle;
          final fields = await engine.formFields(doc, 0);
          await engine.close(doc);
          await engine.release();
          final checkbox = fields.firstWhere(
            (f) => f.type == PdfFieldType.checkbox,
          );
          Object? readsPdfium;
          if (File(_pdfiumForm).existsSync()) {
            final (p, pv) = await open(_pdfiumForm);
            await waitFor(
              tester,
              () => js(
                pv,
                '!!document.querySelector(\'.annotationLayer [name="Text1"]\')',
              ),
              what: '$route: PDFium\'s form',
            );
            readsPdfium = await pv.evaluate(
              '({Text1: document.querySelector(\'.annotationLayer [name="Text1"]\').value, '
              'checkbox: document.querySelector(\'.annotationLayer input[type="checkbox"]\').checked})',
            );
            await close(p);
          } else {
            readsPdfium = notMeasured('the PDFium run saved no filled form');
          }
          return {
            'filled': {
              'Text1': text ? 'pdf.js 42' : 'not filled',
              'first_checkbox': box ? 'clicked' : 'not clicked',
              'combo_and_list_boxes': choices,
            },
            'incremental':
                saved.length > original.length &&
                _same(saved.sublist(0, original.length), original),
            'pdfium_reads': {
              'Text1': fields.firstWhere((f) => f.name == 'Text1').value,
              checkbox.name: checkbox.checked,
              // Combo and list boxes: PDFium's editor does not fill them, it reads
              // their values.
              'choice_fields': {
                for (final f in fields)
                  if (f.type == PdfFieldType.comboBox ||
                      f.type == PdfFieldType.listBox)
                    f.name: f.value,
              },
            },
            'preview_pdfkit': pdfKitFields(path),
            'reads_pdfium': readsPdfium,
          };
        });

        // ------------------------------------------------ crash isolation
        results['crash_isolation'] = await _measure('$route crash', () async {
          final out = <String, Object?>{};
          for (final sample in [
            'damaged-pdf-truncated.pdf',
            'damaged-pdf-corrupt.pdf',
          ]) {
            final (c, view) = await open(
              EvalConfig.sample(sample),
              waitOpen: false,
            );
            try {
              await waitFor(
                tester,
                () =>
                    c.state == TomPdfJsState.open ||
                    c.state == TomPdfJsState.failed,
                what: '$route: $sample',
                timeout: const Duration(seconds: 60),
              );
            } on TimeoutException {
              // Recorded as it stands.
            }
            out[sample] = {
              'forge_still_running': true,
              'state': c.state.name,
              'pages': c.pageCount,
              'message': c.failure,
            };
            await close(c);
          }
          // The content process killed under an open document.
          final (c, view) = await open(EvalConfig.sample('pdf-text.pdf'));
          final mine = webContentPids().difference(contentBefore);
          final now = mine.isEmpty
              ? <int>{}
              : {mine.reduce((a, b) => a > b ? a : b)};
          for (final p in now) {
            Process.killPid(p, ProcessSignal.sigkill);
          }
          await idle(tester, const Duration(seconds: 3));
          final after = {'state': c.state.name, 'message': c.failure};
          var reopened = false;
          Object? reloadError;
          try {
            await c.reload();
            await waitFor(
              tester,
              () => c.state == TomPdfJsState.open,
              what: '$route: reload after the kill',
              timeout: const Duration(seconds: 60),
            );
            reopened = c.pageCount == 43;
          } catch (e) {
            reloadError = '$e';
          }
          final afterReload = {
            'state': c.state.name,
            'message': c.failure,
            'pages': c.pageCount,
            'error': ?reloadError,
          };
          out['content process killed (pdf-text open)'] = {
            'killed_pids': now.toList(),
            'forge_still_running': true,
            'tab_after': after,
            'reload_reopens_the_document': reopened,
            'tab_after_reload': afterReload,
            'lost':
                'unsaved annotations and form values in the page (a '
                'clean document here)',
          };
          await close(c);
          return out;
        });

        results['framework_errors'] = _errorSummary(errors);
        writeResults(route, results);
      }),
      timeout: const Timeout(Duration(minutes: 40)),
    );
  }
}

/// A scrolling result as it may be reported: on a locked screen the scroll
/// still ran (for the memory samples after it), its frame figures are not
/// kept.
Object? _lockedFrames(Object? scrolling) => screenLocked
    ? {
        ...notMeasured(lockedScreenReason),
        'note':
            'the scripted scroll ran all the same, for the memory '
            'samples after scrolling',
      }
    : scrolling;

/// Runs [body] with the Flutter errors reported meanwhile collected (one
/// line each) instead of failing the test: the route's results list them.
Future<void> _guarded(Future<void> Function(List<String> errors) body) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (d) => errors.add(pdfErrorSummary(d));
  try {
    await body(errors);
  } finally {
    FlutterError.onError = previous;
  }
}

/// The errors by message, with how often each was reported.
Map<String, Object?> _errorSummary(List<String> errors) {
  final counts = <String, int>{};
  for (final e in errors) {
    counts[e] = (counts[e] ?? 0) + 1;
  }
  return {'count': errors.length, 'distinct': counts};
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The PDFium view of the editor on screen.
abstract final class PdfiumViewFinder {
  static late WidgetTester tester;

  /// The view, or null before the editor has built it.
  static PdfPageViewState? get maybe {
    final f = find.byType(PdfPageView);
    return f.evaluate().isEmpty ? null : tester.state<PdfPageViewState>(f);
  }

  static PdfPageViewState get view => maybe!;

  /// Whether page [page] is drawn.
  static bool drawn(int page) => maybe?.hasCurrentImages(page) ?? false;
}

/// The folder the app bundle carries tom_pdf_pdfjs's assets in.
String _assetsFolder() {
  final exe = File(Platform.resolvedExecutable).parent.parent.path;
  return '$exe/Frameworks/App.framework/Resources/flutter_assets/packages/'
      'tom_pdf_pdfjs';
}

/// pdf.js's own password prompt answered (the generic viewer's dialog, or
/// the components page's form).
Future<void> _answerPassword(TomPdfJsViewState view, String password) async {
  await view.evaluate('''
(() => {
  // The components page: a form #password with #passwordField.
  const own = document.getElementById("passwordField");
  if (own && own.offsetParent !== null) {
    own.value = ${jsonEncode(password)};
    own.form.requestSubmit();
    return true;
  }
  // The generic viewer: the dialog's input#password and #passwordSubmit.
  const generic = document.querySelector("input#password");
  const submit = document.getElementById("passwordSubmit");
  if (generic && submit && generic.offsetParent !== null) {
    generic.value = ${jsonEncode(password)};
    submit.click();
    return true;
  }
  return false;
})()
''');
}

/// A stand-in for `requestAnimationFrame` (a MessageChannel turn) while the
/// screen is locked, put in as soon as the page has its bridge; true once
/// it is in. The viewer then draws as it would; its frame timing is not
/// measured.
const _rafStandIn = '''
(() => {
  if (!window.forgeBridge) return false;
  if (window.__evalRafStandIn) return true;
  const channel = new MessageChannel();
  let queue = [];
  channel.port1.onmessage = () => {
    const callbacks = queue;
    queue = [];
    const t = performance.now();
    for (const cb of callbacks) { try { cb(t); } catch (e) { console.error(e); } }
  };
  window.requestAnimationFrame = (cb) => {
    queue.push(cb);
    if (queue.length === 1) channel.port2.postMessage(0);
    return queue.length;
  };
  window.cancelAnimationFrame = () => {};
  window.__evalRafStandIn = true;
  return true;
})()
''';

/// The total of matches once pdf.js's find controller has searched every
/// page, else -1.
/// Whether page [n] of the viewer has been drawn: pdf.js's own mark on the
/// page (`data-loaded`) and its canvas.
String _pageDrawn(int n) =>
    '(() => { const p = document.querySelector(\'.page[data-page-number="$n"]\'); '
    'return !!p && p.getAttribute("data-loaded") === "true" && '
    '!!p.querySelector("canvas"); })()';

/// On a locked screen: the viewer asked to lay out and draw its visible
/// pages (its own trigger, a scroll or resize event, does not come).
const _nudge = 'forgeBridge.test.adapter.pdfViewer?.update(); true';

/// What the page shows of its first page, for a timeout's report.
const _pageState = '''
(() => {
  const p = document.querySelector('.page[data-page-number="1"]');
  return JSON.stringify({
    visibility: document.visibilityState,
    hasFocus: document.hasFocus(),
    page: p ? p.outerHTML.slice(0, 400) : null,
    pages: document.querySelectorAll(".page").length,
  });
})()
''';

const _findDone = '''
(() => {
  const fc = forgeBridge.test.adapter.findController;
  const doc = forgeBridge.test.document;
  if (!fc || !doc) return -1;
  const pm = fc.pageMatches;
  let done = 0, total = 0;
  for (let i = 0; i < doc.numPages; i++) {
    if (Array.isArray(pm[i])) { done++; total += pm[i].length; }
  }
  return done === doc.numPages ? total : -1;
})()
''';

/// Scrolls the viewer 40 px per frame for 600 frames; the frame intervals.
const _scrollScript = '''
const c = document.getElementById("viewerContainer");
c.scrollTop = 0;
await new Promise((r) => setTimeout(r, 500));
const intervals = [];
let last = performance.now();
await new Promise((resolve) => {
  let n = 0;
  const frame = (t) => {
    intervals.push(t - last);
    last = t;
    c.scrollTop += 40;
    if (++n < 600) requestAnimationFrame(frame); else resolve();
  };
  requestAnimationFrame(frame);
});
return intervals.slice(1);
''';

/// Zooms 0.5 → 4 in 0.25 steps, one every 12 frames (14 steps, then 24
/// frames more); the frame intervals.
const _zoomScript = '''
const zoom = (v) => forgeBridge.test.adapter.zoom(String(v));
zoom(0.5);
await new Promise((r) => setTimeout(r, 500));
const intervals = [];
let last = performance.now();
await new Promise((resolve) => {
  let n = 0;
  let scale = 0.5;
  const frame = (t) => {
    intervals.push(t - last);
    last = t;
    n++;
    if (n % 12 === 0 && scale < 4) { scale += 0.25; zoom(scale); }
    if (n < 14 * 12 + 24) requestAnimationFrame(frame); else resolve();
  };
  requestAnimationFrame(frame);
});
zoom("page-width");
return intervals.slice(1);
''';

/// Chooses the second option of every combo box and list box of the form.
const _chooseSecondOptions = '''
(() => {
  const out = {};
  for (const s of document.querySelectorAll(".annotationLayer select")) {
    if (s.options.length < 2) continue;
    s.focus();
    s.selectedIndex = 1;
    s.dispatchEvent(new Event("input", { bubbles: true }));
    s.dispatchEvent(new Event("change", { bubbles: true }));
    s.blur();
    out[s.name || "?"] = s.options[1].value;
  }
  return out;
})()
''';

/// Runs [script] (async JavaScript returning frame intervals) while Flutter
/// keeps pumping.
Future<List<num>> _rafRun(
  WidgetTester tester,
  TomPdfJsViewState view,
  String script,
) async {
  var done = false;
  Object? result;
  unawaited(
    view
        .evaluateAsync(script)
        .then(
          (r) {
            result = r;
            done = true;
          },
          onError: (Object e) {
            result = e;
            done = true;
          },
        ),
  );
  final end = DateTime.now().add(const Duration(seconds: 90));
  while (!done && DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  if (result is! List) throw StateError('the page answered $result');
  return [for (final v in result! as List) v as num];
}

/// pdf.js's rendering of [page] at the PDFium image's pixel size, compared.
Future<Map<String, Object?>> _renderAndCompare(
  String route,
  TomPdfJsViewState view,
  String sample,
  int page,
  String? password,
  Map<String, Object?> Function(
    String route,
    String sample,
    int page,
    String png, {
    String? password,
  })
  compare,
) async {
  final key = '${sample.replaceAll('.pdf', '')}-p${page + 1}';
  final pdfium = _pdfiumPages[key];
  final size = pdfium == null ? null : _pngSize(pdfium);
  final data = await view.evaluateAsync('''
const doc = forgeBridge.test.document;
const page = await doc.getPage(${page + 1});
const vp = page.getViewport({ scale: $evalFidelityScale });
const canvas = document.createElement("canvas");
canvas.width = ${size?.$1 ?? 'Math.round(vp.width)'};
canvas.height = ${size?.$2 ?? 'Math.round(vp.height)'};
const ctx = canvas.getContext("2d");
ctx.fillStyle = "white";
ctx.fillRect(0, 0, canvas.width, canvas.height);
await page.render({
  canvasContext: ctx,
  canvas,
  viewport: vp,
  annotationMode: globalThis.pdfjsLib.AnnotationMode.ENABLE,
}).promise;
return canvas.toDataURL("image/png");
''');
  final url = '$data';
  final png = '${EvalConfig.work}/$route-$key.png';
  File(png).writeAsBytesSync(base64Decode(url.substring(url.indexOf(',') + 1)));
  return compare(route, sample, page, png, password: password);
}

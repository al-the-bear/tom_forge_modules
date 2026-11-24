// Copyright (c) 2026 Peter Nicolai Alexis Kyaw
// SPDX-License-Identifier: BSD-3-Clause

/// The PDF routes' checks (office/PDF prototype, `part-evaluation`, measures
/// 7 and 8): per route — PDFium, and pdf.js in each of its three modes —
///
/// - the engine checks: undo, redo, dirty and no-redo-after-typing on the
///   real engine against what the undo-conformance fakes model
///   (`tom_forge_pdf_pdfium_testing`, `tom_forge_pdf_pdfjs_testing`);
/// - the feature checklist: search, text selection, highlight, note, ink,
///   free text, form filling, page thumbnails, and what of the route's own
///   UI is usable inside a Forge tab;
/// - pdf.js's dialog checklist: document properties, print, the password
///   prompt, the stamp's image picker, with a screenshot of each that opens.
///
/// Each route writes `results/<route>/checks.yaml` (beside the timed runs,
/// which `pdf_routes_test.dart` takes). Run with `flutter drive --profile`
/// and the screen unlocked; `EVAL_ONLY` picks routes as there.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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

/// One engine check: what the fake models, what the engine did.
Map<String, Object?> _check(bool fake, bool engine) => {
  'fake': fake,
  'engine': engine,
  'matches': fake == engine,
};

/// The checks and their mismatches.
Map<String, Object?> _engineChecks(
  Map<String, Map<String, Object?>> checks,
  String editedBy,
) => {
  'checks': checks,
  'mismatches': [
    for (final e in checks.entries)
      if (e.value['matches'] != true) e.key,
  ],
  'edited_by': editedBy,
};

void _writeChecks(String route, Map<String, Object?> results) {
  final dir = Directory('${EvalConfig.results}/$route')
    ..createSync(recursive: true);
  File('${dir.path}/checks.yaml').writeAsStringSync(
    '# The $route route\'s checks (officeproto31hc): engine checks against '
    'the fakes,\n# the feature checklist and the dialog checklist. Written '
    'by\n# tom_forge_pdf_pdfjs/tool/evaluation/integration_test/'
    'pdf_checks_test.dart.\n${toYaml(results)}',
  );
  print('[eval] wrote ${dir.path}/checks.yaml');
}

/// A present / missing mark from [ok], with what it rests on.
String _mark(bool ok, String how) => ok ? 'present ($how)' : 'missing ($how)';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Directory(EvalConfig.work).createSync(recursive: true);

  Future<void> waitFor(
    WidgetTester tester,
    FutureOr<bool> Function() done, {
    required String what,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final end = DateTime.now().add(timeout);
    while (!await done()) {
      if (DateTime.now().isAfter(end)) {
        throw TimeoutException('timed out waiting for $what', timeout);
      }
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// Like [waitFor], answering whether [done] came true in [timeout].
  Future<bool> within(
    WidgetTester tester,
    FutureOr<bool> Function() done, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final end = DateTime.now().add(timeout);
    while (!await done()) {
      if (DateTime.now().isAfter(end)) return false;
      await tester.pump(const Duration(milliseconds: 20));
    }
    return true;
  }

  Future<void> idle(WidgetTester tester, Duration d) async {
    final end = DateTime.now().add(d);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  // ======================================================================
  // PDFium
  // ======================================================================

  testWidgets(
    'CHECKS-PDFIUM: the PDFium route\'s engine and feature checks',
    skip: !_runs('pdfium'),
    (tester) async {
      final library = const TomPdfiumLocator().locate();
      expect(library.isUsable, isTrue, reason: library.message);
      final results = <String, Object?>{
        'route': 'pdfium',
        'environment': environmentInfo(engines: {'pdfium': library.tag}),
      };

      Future<TomPdfEditorController> open(String path) async {
        final c = TomPdfEditorController(EvalPdfHost(path));
        await tester.pumpWidget(PdfiumEvalApp(controller: c));
        await c.open();
        await waitFor(
          tester,
          () => c.state == TomPdfEditorState.open,
          what: 'pdfium open',
        );
        await c.loadAnnotations(0);
        await tester.pump();
        return c;
      }

      Future<void> close(TomPdfEditorController c) async {
        await tester.pumpWidget(const SizedBox());
        await c.close();
      }

      // ------------------------------------------------------ engine checks
      // The fake (ForgePdfEditorSubject over a FakePdfEngine) models
      // Forge's own history: a TomUndoStack with a saved marker, so undo back
      // to the saved state is clean.
      results['engine_checks'] = await _measure('pdfium engine', () async {
        final path = EvalConfig.copy('pdf-text.pdf', 'checks-pdfium.pdf');
        var c = await open(path);
        final checks = <String, Map<String, Object?>>{};
        checks['clean after open'] = _check(false, c.isDirty);
        checks['nothing to undo after open'] = _check(false, c.canUndo);
        await c.addNote(0, 60, 60, 'check one');
        await tester.pump();
        checks['an edit: dirty'] = _check(true, c.isDirty);
        checks['an edit: undo enabled'] = _check(true, c.canUndo);
        await c.undo();
        await tester.pump();
        checks['undo: redo enabled'] = _check(true, c.canRedo);
        checks['undo back to the saved state: clean'] = _check(
          false,
          c.isDirty,
        );
        await c.redo();
        await tester.pump();
        await c.undo();
        await tester.pump();
        await c.addNote(0, 90, 60, 'check two');
        await tester.pump();
        checks['a new edit after undo ends the redo'] = _check(
          false,
          c.canRedo,
        );
        await c.save();
        await tester.pump();
        checks['a save clears dirty'] = _check(false, c.isDirty);
        await close(c);
        // The engine's side: the saved note is in the file when it is read
        // again, and the undone one is not.
        c = await open(path);
        final notes = [
          for (final a in c.annotationsOn(0))
            if (a.kind == PdfAnnotationKind.note) a.contents,
        ];
        checks['saved, reopened: the saved note is there'] = _check(
          true,
          notes.contains('check two'),
        );
        checks['saved, reopened: the undone note is not'] = _check(
          false,
          notes.contains('check one'),
        );
        await close(c);
        return _engineChecks(checks, 'notes added through the controller');
      });

      // -------------------------------------------------- feature checklist
      results['feature_checklist'] = await _measure(
        'pdfium features',
        () async {
          final path = EvalConfig.copy('pdf-text.pdf', 'features-pdfium.pdf');
          final c = await open(path);
          final out = <String, Object?>{};
          c.find('Chain');
          await waitFor(tester, () => !c.searching, what: 'search');
          out['search'] = _mark(c.hits.isNotEmpty, '${c.hits.length} hits');
          final hit = c.hits.first;
          final r = hit.rects.first;
          c.hideFind();
          await c.selectAround(
            hit.page,
            (r.left + r.right) / 2,
            (r.top + r.bottom) / 2,
            line: false,
          );
          final selected = await c.selectedText();
          out['text selection'] = _mark(
            (selected ?? '').isNotEmpty,
            'a word selected: "${selected ?? ''}"',
          );
          out['highlight'] = _mark(
            await c.highlightSelection(),
            'the selection highlighted',
          );
          out['note'] = _mark(
            await c.addNote(0, 60, 60, 'feature note') != null,
            'a note added',
          );
          out['ink'] = _mark(
            await c.addInk(0, [
                  [(x: 100.0, y: 700.0), (x: 200.0, y: 710.0)],
                ]) !=
                null,
            'a stroke added',
          );
          final tools = PdfAnnotationTool.values.map((t) => t.name).toSet();
          out['free text'] = _mark(
            tools.any((t) => t.toLowerCase().contains('free')),
            'the tools offered: ${tools.join(', ')}',
          );
          await tester.pump();
          final thumbs = find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('pdf-thumb-'),
          );
          out['page thumbnails'] = _mark(
            thumbs.evaluate().isNotEmpty,
            'the page list\'s thumbnails (pdf-thumb-<n>)',
          );
          await close(c);
          // Forms on pdf-form.
          final form = await open(
            EvalConfig.copy('pdf-form.pdf', 'features-pdfium-form.pdf'),
          );
          final engine = form.engine!;
          final fields = await engine.formFields(form.info!.handle, 0);
          double cx(PdfFormField f) => (f.rect.left + f.rect.right) / 2;
          double cy(PdfFormField f) => (f.rect.top + f.rect.bottom) / 2;
          final text = fields.firstWhere((f) => f.type == PdfFieldType.text);
          final box = fields.firstWhere((f) => f.type == PdfFieldType.checkbox);
          await form.formClick(0, cx(text), cy(text));
          await form.formText('42');
          await form.releaseFormFocus();
          final ticked = await form.formClick(0, cx(box), cy(box));
          await tester.pump();
          out['form filling: text fields'] = _mark(
            form.isDirty,
            'Text field typed into, the document dirty',
          );
          out['form filling: checkboxes'] = _mark(ticked, 'a checkbox clicked');
          out['form filling: combo and list boxes'] =
              'missing (left out of the PDFium editor, DPPF-4)';
          await close(form);
          out['inside a Forge tab'] = {
            'shortcuts, focus, text input':
                'Forge\'s own widgets (the route draws no web page)',
          };
          return out;
        },
      );

      results['dialog_checklist'] = notMeasured(
        'not applicable: the checklist is pdf.js\'s; the PDFium editor\'s '
        'own dialogs (the note text, the password prompt, save unencrypted) '
        'are Flutter widgets, tested in tom_pdf_editor',
      );
      _writeChecks('pdfium', results);
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );

  // ======================================================================
  // pdf.js
  // ======================================================================

  for (final mode in TomPdfJsMode.values) {
    final route = 'pdfjs-${mode.name}';
    testWidgets(
      'CHECKS-PDFJS-${mode.name}: the pdf.js route\'s checks in '
      '${mode.name} mode',
      skip: !_runs(route),
      (tester) async {
        final results = <String, Object?>{'route': route, 'mode': mode.name};
        var version = '?';
        final shots = Directory('${EvalConfig.results}/$route/screenshots')
          ..createSync(recursive: true);

        Future<Object?> js(TomPdfJsViewState view, String source) =>
            view.evaluate(source);

        Future<void> close(TomPdfJsController c) async {
          await tester.pumpWidget(const SizedBox());
          await c.close();
          // The webview and its server go with the tab: give them a moment
          // before the next tab opens (an open straight after a save's
          // reopen and close got no text layer).
          await idle(tester, const Duration(milliseconds: 1500));
        }

        /// The tabs that needed a second open (the first got no text layer
        /// in 20 s), by file.
        final retried = <String>[];

        Future<(TomPdfJsController, TomPdfJsViewState)> open(
          String path, {
          bool waitOpen = true,
          bool textLayer = true,
        }) async {
          for (var attempt = 1; ; attempt++) {
            final c = TomPdfJsController(EvalPdfHost(path), mode: mode);
            await tester.pumpWidget(PdfJsEvalApp(controller: c));
            final view = tester.state<TomPdfJsViewState>(
              find.byType(TomPdfJsView),
            );
            if (!waitOpen) return (c, view);
            final ready = await within(
              tester,
              () async =>
                  c.state == TomPdfJsState.open &&
                  (!textLayer ||
                      await js(
                            view,
                            '!!document.querySelector(\'.page[data-page-number="1"] '
                            '.textLayer span\')',
                          ) ==
                          true),
              timeout: const Duration(seconds: 20),
            );
            if (ready) return (c, view);
            await close(c);
            if (attempt == 2) {
              throw TimeoutException('$route: no text layer after two opens');
            }
            retried.add(path.split('/').last);
          }
        }

        /// Draws an ink stroke on page 1 (the edit of the engine checks).
        Future<void> ink(
          TomPdfJsController c,
          TomPdfJsViewState view,
          double y,
        ) async {
          await c.setTool(TomPdfJsTool.ink);
          await waitFor(
            tester,
            () async =>
                await js(
                  view,
                  '!!document.querySelector(\'.page[data-page-number="1"] '
                  '.annotationEditorLayer\')',
                ) ==
                true,
            what: '$route editor layer',
          );
          await idle(tester, const Duration(milliseconds: 200));
          await js(view, 'forgeBridge.test.pointer(1, "pointerdown", 0.2, $y)');
          for (var i = 1; i <= 6; i++) {
            await js(
              view,
              'forgeBridge.test.pointer(1, "pointermove", ${0.2 + i * 0.04}, '
              '$y)',
            );
          }
          await js(view, 'forgeBridge.test.pointer(1, "pointerup", 0.44, $y)');
          await c.setTool(TomPdfJsTool.none);
          await idle(tester, const Duration(milliseconds: 400));
        }

        Future<String?> shot(TomPdfJsViewState view, String name) async {
          final Uint8List? png = await view.snapshot();
          if (png == null) return null;
          final file = File('${shots.path}/dialog-$name.png')
            ..writeAsBytesSync(png);
          return '$route/screenshots/${file.uri.pathSegments.last}';
        }

        /// Whether the element [selector] is in the page and shown.
        Future<bool> shown(TomPdfJsViewState view, String selector) async =>
            await js(
              view,
              '(() => { const e = document.querySelector(${_q(selector)}); '
              'return !!e && getComputedStyle(e).display !== "none" && '
              '!e.closest("[hidden]"); })()',
            ) ==
            true;

        // ---------------------------------------------------- engine checks
        // The fake (ScriptedPdfJsPage) models pdf.js's history and its
        // annotation storage: an edit sets `modified`, an undo that removes
        // the last edit since the open (or the save, after which Forge
        // reopens) resets it.
        results['engine_checks'] = await _measure('$route engine', () async {
          final path = EvalConfig.copy('pdf-text.pdf', 'checks-$route.pdf');
          final (c, view) = await open(path);
          version = '${await js(view, 'globalThis.pdfjsLib?.version')}';
          final checks = <String, Map<String, Object?>>{};
          checks['clean after open'] = _check(false, c.isDirty);
          checks['nothing to undo after open'] = _check(false, c.canUndo);
          await ink(c, view, 0.55);
          await within(tester, () => c.isDirty && c.canUndo);
          checks['an edit: dirty'] = _check(true, c.isDirty);
          checks['an edit: undo enabled'] = _check(true, c.canUndo);
          await c.undo();
          await within(tester, () => c.canRedo);
          checks['undo: redo enabled'] = _check(true, c.canRedo);
          // The modified flag comes in its own message: given time to clear.
          await c.checkModified();
          await within(
            tester,
            () => !c.isDirty,
            timeout: const Duration(seconds: 3),
          );
          checks['undo back to the saved state: clean'] = _check(
            false,
            c.isDirty,
          );
          await ink(c, view, 0.7);
          await within(tester, () => !c.canRedo);
          checks['a new edit after undo ends the redo'] = _check(
            false,
            c.canRedo,
          );
          final before = c.generation;
          await c.save();
          await waitFor(
            tester,
            () => c.generation > before && c.state == TomPdfJsState.open,
            what: '$route saved and reopened',
          );
          checks['a save clears dirty'] = _check(false, c.isDirty);
          // Forge reopens after a save: pdf.js's history starts again.
          checks['after the save: nothing to undo (reopened)'] = _check(
            false,
            c.canUndo,
          );
          await close(c);
          // Two edits after the save, undone one by one (officeproto31hg):
          // the saved file opened again, as the save's reopen leaves it (an
          // empty storage, a new history).
          final (c2, view2) = await open(path, textLayer: false);
          // How many values pdf.js's annotation storage holds.
          Future<Object?> storage() => js(
            view2,
            'forgeBridge.test.document?.annotationStorage.size ?? null',
          );
          Future<void> settle() async {
            await idle(tester, const Duration(milliseconds: 1500));
            await c2.checkModified();
            await idle(tester, const Duration(milliseconds: 500));
          }

          await ink(c2, view2, 0.4);
          await within(tester, () => c2.isDirty && c2.canUndo);
          await settle();
          final afterA = await storage();
          await ink(c2, view2, 0.8);
          await settle();
          final afterB = await storage();
          await c2.undo();
          await within(tester, () => c2.canRedo);
          await settle();
          checks['after the save, two edits, one undone: dirty'] = {
            ..._check(true, c2.isDirty),
            'storage_size_after_edit_a': afterA,
            'storage_size_after_edit_b': afterB,
            'storage_size_after_undo_b': await storage(),
          };
          checks['after the save, two edits, one undone: undo enabled'] =
              _check(true, c2.canUndo);
          await c2.undo();
          await within(tester, () => !c2.canUndo);
          await settle();
          checks['after the save, both edits undone: nothing to undo'] = _check(
            false,
            c2.canUndo,
          );
          checks['after the save, both edits undone: clean'] = {
            ..._check(false, c2.isDirty),
            'storage_size_after_undo_a': await storage(),
          };
          await close(c2);
          return _engineChecks(
            checks,
            'ink strokes drawn through the bridge\'s pointer events',
          );
        });

        // ------------------------------------------------ feature checklist
        results['feature_checklist'] = await _measure('$route features', () async {
          final path = EvalConfig.copy('pdf-text.pdf', 'features-$route.pdf');
          final (c, view) = await open(path);
          final out = <String, Object?>{};
          await c.find('Chain');
          final found = await within(
            tester,
            () => (c.findCount?.total ?? 0) > 0,
            timeout: const Duration(seconds: 20),
          );
          out['search'] = _mark(
            found,
            '${c.findCount?.total ?? 0} matches (the find bar in Forge)',
          );
          await c.find('');
          out['text selection'] = _mark(
            await js(view, 'forgeBridge.test.selectText(1, 40)') == true &&
                await js(
                      view,
                      'document.getSelection().toString().length > 0',
                    ) ==
                    true,
            'the text layer\'s selection',
          );
          await c.setTool(TomPdfJsTool.highlight);
          await idle(tester, const Duration(milliseconds: 300));
          await js(view, 'forgeBridge.test.selectText(1, 40)');
          await js(view, 'forgeBridge.test.highlightSelection(); true');
          await idle(tester, const Duration(milliseconds: 500));
          Future<List<Object?>> types() async =>
              ((await js(view, 'forgeBridge.test.storage().types') as List?) ??
              const []);
          out['highlight'] = _mark(
            (await types()).contains(9),
            'a highlight in the annotation storage',
          );
          out['note'] =
              'missing (pdf.js offers no note tool: free text, highlight, '
              'ink, stamp)';
          await ink(c, view, 0.55);
          out['ink'] = _mark(
            (await types()).contains(15),
            'an ink stroke in the annotation storage',
          );
          await c.setTool(TomPdfJsTool.freeText);
          await idle(tester, const Duration(milliseconds: 300));
          await js(
            view,
            'forgeBridge.test.pointer(1, "pointerdown", 0.6, 0.2)',
          );
          await js(view, 'forgeBridge.test.pointer(1, "pointerup", 0.6, 0.2)');
          await within(
            tester,
            () async =>
                await js(
                  view,
                  '!!document.querySelector(".freeTextEditor .internal")',
                ) ==
                true,
          );
          await js(view, 'forgeBridge.test.typeFreeText("free text")');
          await c.setTool(TomPdfJsTool.none);
          await idle(tester, const Duration(milliseconds: 500));
          out['free text'] = _mark(
            (await types()).contains(3),
            'a free text in the annotation storage',
          );
          final thumbnails = mode == TomPdfJsMode.components
              ? false
              : await js(
                      view,
                      '(() => { const app = window.PDFViewerApplication; '
                      'const views = app.viewsManager ?? app.pdfSidebar; '
                      'views?.open(); return !!views; })()',
                    ) ==
                    true;
          await idle(tester, const Duration(milliseconds: 1500));
          final thumbCount = mode == TomPdfJsMode.components
              ? 0
              : ((await js(
                              view,
                              'document.querySelectorAll("#thumbnailsView '
                              '.thumbnail").length',
                            ))
                            as num?)
                        ?.toInt() ??
                    0;
          out['page thumbnails'] = mode == TomPdfJsMode.components
              ? 'missing (the components page has no sidebar)'
              : _mark(
                  thumbnails && thumbCount > 0,
                  'the generic viewer\'s views manager: $thumbCount thumbnails',
                );
          await close(c);
          // Forms on pdf-form: a text field, a checkbox, a choice field.
          final (f, fv) = await open(
            EvalConfig.copy('pdf-form.pdf', 'features-$route-form.pdf'),
            // A form without text: its fields, not a text layer.
            textLayer: false,
          );
          await within(
            tester,
            () async =>
                await js(
                  fv,
                  '!!document.querySelector(\'.annotationLayer [name="Text1"]\')',
                ) ==
                true,
            timeout: const Duration(seconds: 15),
          );
          out['form filling: text fields'] = _mark(
            await js(fv, 'forgeBridge.test.fillField("Text1", "42")') == true,
            'Text1 filled',
          );
          out['form filling: checkboxes'] = _mark(
            await js(
                  fv,
                  '(() => { const b = document.querySelector('
                  '\'.annotationLayer input[type="checkbox"]\'); '
                  'if (!b) return false; b.click(); return b.checked; })()',
                ) ==
                true,
            'a checkbox clicked',
          );
          out['form filling: combo and list boxes'] = _mark(
            await js(
                  fv,
                  '(() => { const s = document.querySelector('
                  '\'.annotationLayer select\'); if (!s || s.options.length < 2) '
                  'return false; s.selectedIndex = 1; s.dispatchEvent(new '
                  'Event("input", {bubbles: true})); s.dispatchEvent(new '
                  'Event("change", {bubbles: true})); return true; })()',
                ) ==
                true,
            'a choice field set',
          );
          await close(f);
          out['inside a Forge tab'] = {
            'text input':
                'works for the page\'s own fields and editors (the bridge '
                'types into them as input events)',
            'shortcuts':
                'checked by a person: WebKit gets the keys first; the '
                'page forwards the shell\'s shortcuts it does not use '
                '(TomPdfJsController.shortcuts)',
            'focus': 'checked by a person',
          };
          return out;
        });

        // ------------------------------------------------- dialog checklist
        results['dialog_checklist'] = await _measure(
          '$route dialogs',
          () async {
            final out = <String, Object?>{};
            final generic = mode != TomPdfJsMode.components;
            final (c, view) = await open(
              EvalConfig.copy('pdf-text.pdf', 'dialogs-$route.pdf'),
            );
            // Document properties.
            if (!generic) {
              out['document properties'] =
                  'not offered (the components page has no generic viewer)';
            } else {
              final offered = await shown(view, '#documentProperties');
              await js(
                view,
                'window.PDFViewerApplication.pdfDocumentProperties.open(); '
                'true',
              );
              final opened = await within(
                tester,
                () async =>
                    await js(
                      view,
                      '(() => { const d = document.getElementById('
                      '"documentPropertiesDialog"); return !!d && d.open && '
                      'document.getElementById("pageCountField")?.textContent '
                      '!== "-"; })()',
                    ) ==
                    true,
                timeout: const Duration(seconds: 10),
              );
              await idle(tester, const Duration(milliseconds: 500));
              final screenshot = opened ? await shot(view, 'properties') : null;
              final pages = await js(
                view,
                'document.getElementById("pageCountField")?.textContent ?? ""',
              );
              await js(
                view,
                'document.getElementById("documentPropertiesClose")?.click(); '
                'true',
              );
              final closed = await within(
                tester,
                () async =>
                    await js(
                      view,
                      '!document.getElementById("documentPropertiesDialog")'
                      '?.open',
                    ) ==
                    true,
              );
              out['document properties'] = {
                'button_shown': offered,
                'result': opened && closed
                    ? (offered
                          ? 'works'
                          : 'works with flaws (opens, but its button is not '
                                'shown)')
                    : 'fails',
                'page_count_field': pages,
                'closes': closed,
                'screenshot': screenshot,
              };
            }
            // Print.
            if (!generic) {
              out['print'] = 'not offered (the components page)';
            } else {
              final button = await shown(view, '#printButton');
              final secondary = await shown(view, '#secondaryPrint');
              out['print'] = {
                'button_shown': button || secondary,
                'result': mode == TomPdfJsMode.integrated
                    ? 'hidden by Forge\'s stylesheet (the shell prints)'
                    : notMeasured(
                        'offered; not triggered: it opens the system\'s '
                        'print panel, which the harness cannot answer',
                      ),
              };
            }
            // The stamp's image picker.
            final stampOffered = generic
                ? await shown(view, '#editorStampButton') ||
                      await shown(view, '#editorStamp')
                : find
                      .byKey(const ValueKey('pdfjs-tool-stamp'))
                      .evaluate()
                      .isNotEmpty;
            out['stamp image picker'] = {
              'tool_offered': stampOffered,
              'result': notMeasured(
                'not triggered: the image comes through the system\'s file '
                'dialog, which the harness cannot answer',
              ),
            };
            await close(c);
            // The password prompt, on pdf-encrypted.
            final (p, pv) = await open(
              EvalConfig.copy('pdf-encrypted.pdf', 'dialogs-$route-enc.pdf'),
              waitOpen: false,
            );
            final prompted = await within(
              tester,
              () async =>
                  await js(
                    pv,
                    '(() => { const own = document.getElementById('
                    '"passwordField"); if (own && own.offsetParent !== null) '
                    'return true; const d = document.getElementById('
                    '"passwordDialog"); return !!d && d.open; })()',
                  ) ==
                  true,
              timeout: const Duration(seconds: 30),
            );
            await idle(tester, const Duration(milliseconds: 500));
            final promptShot = prompted ? await shot(pv, 'password') : null;
            if (prompted) {
              await js(pv, '''
(() => {
  const own = document.getElementById("passwordField");
  if (own && own.offsetParent !== null) {
    own.value = "$evalEncryptedPassword"; own.form.requestSubmit(); return true;
  }
  const input = document.querySelector("input#password");
  const submit = document.getElementById("passwordSubmit");
  if (input && submit) { input.value = "$evalEncryptedPassword"; submit.click(); return true; }
  return false;
})()''');
            }
            final unlocked = await within(
              tester,
              () => p.state == TomPdfJsState.open,
              timeout: const Duration(seconds: 30),
            );
            out['password prompt'] = {
              'shown': prompted,
              'opens_with_the_password': unlocked,
              'result': prompted && unlocked ? 'works' : 'fails',
              'screenshot': promptShot,
            };
            await close(p);
            return out;
          },
        );
        results['tabs_opened_twice'] = retried;
        results['environment'] = environmentInfo(engines: {'pdfjs': version});
        _writeChecks(route, results);
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );
  }
}

/// [s] as a JavaScript string literal.
String _q(String s) => "'${s.replaceAll("'", "\\'")}'";

// Tests for markdown import/export + the parse-rejection protocol (step 22,
// `tom_specs_editor_specification.md` §15.2).
//
// The step's Done condition: a round-trip export→import preserves embedded
// d4rt/Dart bodies, and bad input is reported (not silently dropped). These
// tests drive the codec through the shared `SpecDocumentController` over a
// synthetic model covering every render kind, including a content leaf holding
// a multi-line d4rt body with an embedded backtick run (the verbatim-fidelity
// stress case).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tom_specs_editor/src/document/markdown_document.dart';
import 'package:tom_specs_editor/src/document/markdown_io_dialog.dart';
import 'package:tom_specs_editor/src/document/spec_document.dart';
import 'package:tom_specs_editor/src/document/spec_document_controller.dart';
import 'package:tom_specs_editor/src/structure/review_store.dart';
import 'package:tom_specs_editor/src/structure/spec_model.dart';

/// A class graph covering content, enum, `@Form`, a complex sub-section, and a
/// list of complex items (so the round-trip exercises every store).
Map<String, dynamic> _sampleJson() => {
      'roots': [
        {
          'type': 'DemoDoc',
          'title': 'Demo Document',
          'sectionId': 'D00',
          'description': 'A demo document for the editor.',
        },
      ],
      'classes': {
        'DemoDoc': {
          'name': 'DemoDoc',
          'sectionId': 'D00',
          'fields': [
            {'name': 'overview', 'kind': 'content', 'sectionId': 'D00-OVR'},
            {
              'name': 'status',
              'kind': 'enum',
              'sectionId': 'D00-ST',
              'enumValues': ['draft', 'final'],
            },
            {
              'name': 'header',
              'kind': 'form',
              'sectionId': 'D00-HDR',
              'formFields': [
                {'name': 'author', 'label': 'Author', 'type': 'String'},
                {'name': 'reviewer', 'label': 'Reviewer', 'type': 'String'},
              ],
            },
            {
              'name': 'meta',
              'kind': 'complex',
              'type': 'DemoMeta',
              'sectionId': 'D00-MET',
            },
            {
              'name': 'items',
              'kind': 'list',
              'elementType': 'DemoItem',
              'elementIsComplex': true,
              'sectionId': 'D00-ITM',
            },
          ],
        },
        'DemoMeta': {
          'name': 'DemoMeta',
          'sectionId': 'D00-MET',
          'fields': [
            {'name': 'note', 'kind': 'content', 'sectionId': 'D00-MET-NOTE'},
          ],
        },
        'DemoItem': {
          'name': 'DemoItem',
          'fields': [
            {'name': 'label', 'kind': 'content', 'sectionId': 'D01-LBL'},
            {'name': 'body', 'kind': 'content', 'sectionId': 'D01-BODY'},
          ],
        },
      },
    };

ReviewStore _tempReviewStore() {
  final dir = Directory.systemTemp.createTempSync('md_io_review');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return ReviewStore(File('${dir.path}/review.yaml'));
}

Future<SpecDocumentController> _controller([SpecDocument? doc]) async {
  final controller = SpecDocumentController(
    modelFuture: Future<SpecModel>.value(SpecModel.fromJson(_sampleJson())),
    review: _tempReviewStore(),
    document: doc,
  );
  await controller.ensureLoaded();
  addTearDown(controller.dispose);
  return controller;
}

/// A d4rt-flutter body that is multi-line and embeds a run of three backticks —
/// the case that forces the fenced-leaf encoder to widen its fence.
const _d4rtBody = 'Column(\n'
    '  children: [\n'
    '    Text("hi"),\n'
    '  ],\n'
    ') // not a fence: ``` still inside the body';

/// [_sampleJson] plus a **second root**, so an import covering one root can be
/// checked against values living under the other. Kept separate from
/// [_sampleJson] because the export-dialog tests assert on the single-root
/// global scope.
Map<String, dynamic> _twoRootJson() {
  final json = _sampleJson();
  (json['roots'] as List).add({
    'type': 'OtherDoc',
    'title': 'Other Document',
    'sectionId': 'D02',
    'description': 'A second root, never covered by the import.',
  });
  (json['classes'] as Map)['OtherDoc'] = {
    'name': 'OtherDoc',
    'sectionId': 'D02',
    'fields': [
      {'name': 'summary', 'kind': 'content', 'sectionId': 'D02-SUM'},
    ],
  };
  return json;
}

Future<SpecDocumentController> _twoRootController() async {
  final controller = SpecDocumentController(
    modelFuture: Future<SpecModel>.value(SpecModel.fromJson(_twoRootJson())),
    review: _tempReviewStore(),
  );
  await controller.ensureLoaded();
  addTearDown(controller.dispose);
  return controller;
}

Future<SpecDocumentController> _populated() async {
  final c = await _controller();
  c.setContent('D00/D00-OVR', 'An overview paragraph.\nWith two lines.');
  c.setContent('D00/D00-ST', 'final');
  c.setFormField('D00/D00-HDR', 'author', 'Ada Lovelace');
  c.setContent('D00/D00-MET/D00-MET-NOTE', 'A note.');
  final item = c.addListItem('D00/D00-ITM');
  c.setContent('$item/D01-LBL', 'First item');
  c.setContent('$item/D01-BODY', _d4rtBody);
  final item2 = c.addListItem('D00/D00-ITM');
  c.setContent('$item2/D01-LBL', 'Second item');
  return c;
}

/// A [MarkdownFileIo] that records its calls and returns canned values, so the
/// dialog tests exercise the per-file IO seam (OE-19) without the platform
/// file-picker channel.
class _FakeFileIo implements MarkdownFileIo {
  _FakeFileIo({this.savePath, this.openContent});

  /// What [saveText] returns — the "written" path, or `null` to simulate cancel.
  final String? savePath;

  /// What [openText] returns, or `null` to simulate cancel.
  final String? openContent;

  String? savedName;
  String? savedContent;
  int openCalls = 0;

  @override
  Future<String?> saveText(String suggestedName, String content) async {
    savedName = suggestedName;
    savedContent = content;
    return savePath;
  }

  @override
  Future<String?> openText() async {
    openCalls++;
    return openContent;
  }
}

void main() {
  group('export', () {
    test('emits a docspec header and section headings for populated nodes',
        () async {
      final c = await _populated();
      final md = c.exportMarkdown('D00');
      // SOM §11: headings carry the section id as a headline comment plus a
      // readable title; content is plain markdown text under the heading.
      expect(md, contains('<!-- docspec:'));
      expect(md, contains('# <!--[D00]--> Demo Document'));
      expect(md, contains('## <!--[D00-OVR]--> Overview'));
      expect(md, contains('## <!--[D00-HDR]--> Header'));
      // Empty fields (e.g. the reviewer form field) are not emitted (sparse).
      expect(md, isNot(contains('Reviewer')));
    });

    test('a content leaf with an embedded backtick run stays plain text '
        '(no fence)', () async {
      final c = await _populated();
      final md = c.exportMarkdown('D00');
      // SOM §11: content is plain markdown text; the body's mid-line ``` run is
      // not a code fence, so no line starts one and the body survives verbatim.
      expect(md, contains(_d4rtBody));
      expect(md.split('\n').any((l) => l.startsWith('```')), isFalse);
    });
  });

  group('round-trip', () {
    test('export → import into a fresh document reproduces every value',
        () async {
      final source = await _populated();
      final md = source.exportMarkdown('D00');

      final target = await _controller();
      final report = target.importMarkdown(md);
      expect(report.isClean, isTrue, reason: report.rejections.toString());

      final doc = target.document;
      expect(doc.content('D00/D00-OVR'),
          'An overview paragraph.\nWith two lines.');
      expect(doc.content('D00/D00-ST'), 'final');
      expect(doc.formField('D00/D00-HDR', 'author'), 'Ada Lovelace');
      expect(doc.content('D00/D00-MET/D00-MET-NOTE'), 'A note.');

      final items = doc.listItems('D00/D00-ITM');
      expect(items, hasLength(2));
      expect(doc.content('${items[0]}/D01-LBL'), 'First item');
      // The embedded d4rt body survives verbatim, backticks and all.
      expect(doc.content('${items[0]}/D01-BODY'), _d4rtBody);
      expect(doc.content('${items[1]}/D01-LBL'), 'Second item');
    });

    test('import is a full overwrite of the covered root', () async {
      final source = await _populated();
      final md = source.exportMarkdown('D00');

      // A target that already holds a stale value under the same root.
      final target = await _controller();
      target.setContent('D00/D00-OVR', 'STALE — should be replaced');
      target.setContent('D00/D00-ST', 'draft');
      target.importMarkdown(md);

      expect(target.document.content('D00/D00-OVR'),
          'An overview paragraph.\nWith two lines.');
      expect(target.document.content('D00/D00-ST'), 'final');
    });

    test('the overwrite covers only the imported scope — headlines and '
        'codeSpecs under another root survive', () async {
      // A source under the imported root carrying both a stored headline
      // (YRD3) and a codeSpec mapping (codespecs_mapping.md §9.2), so the
      // export round-trips them.
      final source = await _twoRootController();
      source.setContent('D00/D00-OVR', 'An overview paragraph.');
      source.setHeadline('D00/D00-OVR', 'Executive Overview');
      source.document.setCodeSpec('D00/D00-OVR', 'CsForm:DemoForm');
      final md = source.exportMarkdown('D00');

      // The target holds values under a SECOND root the import never covers,
      // plus stale ones under the imported root.
      final target = await _twoRootController();
      target.setContent('D02/D02-SUM', 'Untouched summary.');
      target.setHeadline('D02/D02-SUM', 'Kept Headline');
      target.document.setCodeSpec('D02/D02-SUM', 'CsTable:KeptTable');
      target.setContent('D00/D00-OVR', 'STALE');
      target.setHeadline('D00/D00-OVR', 'Stale Headline');
      target.document.setCodeSpec('D00/D00-OVR', 'CsForm:StaleForm');
      target.document.setCodeSpec('D00/D00-ST', 'CsEnum:StaleEnum');

      final report = target.importMarkdown(md);
      expect(report.isClean, isTrue, reason: report.rejections.toString());

      // Out of scope: every store survives, not just content.
      expect(target.document.content('D02/D02-SUM'), 'Untouched summary.');
      expect(target.document.headline('D02/D02-SUM'), 'Kept Headline');
      expect(target.document.codeSpec('D02/D02-SUM'), 'CsTable:KeptTable');
      // In scope: the parsed values replace the stale ones …
      expect(target.document.content('D00/D00-OVR'), 'An overview paragraph.');
      expect(target.document.headline('D00/D00-OVR'), 'Executive Overview');
      expect(target.document.codeSpec('D00/D00-OVR'), 'CsForm:DemoForm');
      // … and a stale in-scope value the markdown does not carry is dropped,
      // since the import is a full overwrite of the covered root.
      expect(target.document.codeSpec('D00/D00-ST'), isNull);
    });

    test('an import is a single undoable step', () async {
      final source = await _populated();
      final md = source.exportMarkdown('D00');
      final target = await _controller();
      target.importMarkdown(md);
      expect(target.document.isEmpty, isFalse);
      expect(target.canUndo, isTrue);
      await target.undo();
      expect(target.document.isEmpty, isTrue);
    });
  });

  group('parse-rejection protocol', () {
    test('an unknown section id is reported, valid siblings still applied',
        () async {
      final c = await _controller();
      // The bogus heading nests under `meta` (which has no list children), so
      // it resolves to an unknown section rather than a stored-id list item.
      const md = '<!-- docspec: demo-document/1.0 -->\n'
          '# <!--[D00]--> Demo Document\n\n'
          '## <!--[D00-OVR]--> Overview\n\n'
          'kept\n\n'
          '## <!--[D00-MET]--> Meta\n\n'
          '### <!--[D00-NOPE]--> Bogus\n\n'
          'dropped\n';
      final report = c.importMarkdown(md);
      expect(report.isClean, isFalse);
      expect(
        report.rejections.any((r) =>
            r.anchor == 'D00-NOPE' &&
            r.reason == MarkdownRejectReason.unknownSection),
        isTrue,
      );
      // The valid section was still applied (not silently dropped wholesale).
      expect(c.document.content('D00/D00-OVR'), 'kept');
    });

    test('content with no owning section is reported as orphaned', () async {
      final c = await _controller();
      const md = 'stray preamble text\n'
          '# <!--[D00]--> Demo Document\n\n'
          '## <!--[D00-OVR]--> Overview\n\n'
          'kept\n';
      final report = c.importMarkdown(md);
      expect(report.isClean, isFalse);
      expect(
        report.rejections
            .any((r) => r.reason == MarkdownRejectReason.orphanContent),
        isTrue,
      );
      // The valid section still parses despite the orphaned preamble.
      expect(c.document.content('D00/D00-OVR'), 'kept');
    });

    test('a child heading under a content section is a kind mismatch',
        () async {
      final c = await _controller();
      const md = '# <!--[D00]--> Demo Document\n\n'
          '## <!--[D00-OVR]--> Overview\n\n'
          'kept\n\n'
          '### <!--[D00-MET-NOTE]--> Note\n\n'
          'misplaced\n';
      final report = c.importMarkdown(md);
      expect(
        report.rejections
            .any((r) => r.reason == MarkdownRejectReason.kindMismatch),
        isTrue,
      );
    });
  });

  group('scope', () {
    test('MarkdownScope exposes single / multiple / global', () {
      expect(MarkdownScope.values,
          containsAll([MarkdownScope.single, MarkdownScope.multiple,
              MarkdownScope.global]));
    });
  });

  group('export dialog', () {
    testWidgets('previews the generated markdown for the default (global) root',
        (tester) async {
      final c = await _populated();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MarkdownExportDialog(controller: c, roots: c.model.roots),
        ),
      ));
      await tester.pumpAndSettle();
      // The preview renders the exported markdown of the Demo (global) root.
      expect(find.textContaining('<!-- docspec:'), findsOneWidget);
      expect(find.textContaining('<!--[D00-OVR]-->'), findsOneWidget);
    });
  });

  group('per-file IO (OE-19)', () {
    testWidgets('Save to file writes the previewed markdown via the IO seam',
        (tester) async {
      final c = await _populated();
      final io = _FakeFileIo(savePath: '/some/dir/D00.md');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MarkdownExportDialog(
              controller: c, roots: c.model.roots, fileIo: io),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save to file…'));
      await tester.pumpAndSettle();

      // The global scope is the single PD root (D00) → a `D00.md` suggestion,
      // and the written content is exactly the previewed export.
      expect(io.savedName, 'D00.md');
      expect(io.savedContent, contains('<!-- docspec:'));
      expect(io.savedContent, contains('<!--[D00-OVR]-->'));
      // The written path is surfaced inline.
      expect(find.textContaining('Saved to /some/dir/D00.md'), findsOneWidget);
    });

    testWidgets('a cancelled save surfaces no path', (tester) async {
      final c = await _populated();
      final io = _FakeFileIo(savePath: null); // user cancelled the picker
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MarkdownExportDialog(
              controller: c, roots: c.model.roots, fileIo: io),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save to file…'));
      await tester.pumpAndSettle();

      expect(io.savedContent, isNotNull, reason: 'the write was attempted');
      expect(find.textContaining('Saved to'), findsNothing);
    });

    testWidgets('Load from file fills the input from the IO seam',
        (tester) async {
      final c = await _controller();
      const md = '<!-- docspec: demo/1.0 -->';
      final io = _FakeFileIo(openContent: md);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MarkdownImportDialog(controller: c, fileIo: io)),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Load from file…'));
      await tester.pumpAndSettle();

      expect(io.openCalls, 1);
      expect(find.widgetWithText(TextField, md), findsOneWidget);
    });

    testWidgets('a cancelled load leaves the input untouched', (tester) async {
      final c = await _controller();
      final io = _FakeFileIo(openContent: null); // user cancelled the picker
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MarkdownImportDialog(controller: c, fileIo: io)),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Load from file…'));
      await tester.pumpAndSettle();

      expect(io.openCalls, 1);
      expect(find.widgetWithText(TextField, ''), findsOneWidget);
    });
  });
}

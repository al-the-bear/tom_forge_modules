import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_specs_editor/src/document/docspecs_file.dart';
import 'package:tom_specs_editor/src/document/spec_document.dart';
import 'package:tom_specs_editor/src/document/spec_document_controller.dart';
import 'package:tom_specs_editor/src/structure/review_store.dart';
import 'package:tom_specs_editor/src/structure/spec_model.dart';

/// A trivial single-root model; the codec operates on section-ID paths, so the
/// schema shape is irrelevant for round-trip tests.
Map<String, dynamic> _model() => {
      'roots': [
        {'type': 'DemoDoc', 'title': 'Demo', 'sectionId': 'D00'},
      ],
      'classes': {
        'DemoDoc': {
          'name': 'DemoDoc',
          'sectionId': 'D00',
          'fields': [
            {'name': 'overview', 'kind': 'content', 'sectionId': 'D00-OVR'},
          ],
        },
      },
    };

/// Encodes [doc] + [review], then decodes and applies onto a fresh document /
/// review map — the load→save→load round-trip under test.
({SpecDocument doc, Map<String, ReviewEntry> review}) roundTrip(
  SpecDocument doc,
  Map<String, ReviewEntry> review,
) {
  final yaml = DocSpecsFile.encode(document: doc, review: review);
  final parsed = DocSpecsFile.decode(yaml);
  final outDoc = SpecDocument()..loadJson(parsed.document);
  return (doc: outDoc, review: parsed.review);
}

void main() {
  group('document pass round-trip', () {
    test('content values survive a save→load', () {
      final doc = SpecDocument()
        ..setContent('D00-OVR', 'hello world')
        ..setContent('D00-SUM', 'a summary');
      final out = roundTrip(doc, const {}).doc;
      expect(out.content('D00-OVR'), 'hello world');
      expect(out.content('D00-SUM'), 'a summary');
    });

    test('form fields survive a save→load', () {
      final doc = SpecDocument()
        ..setFormField('D00-HDR', 'title', 'My System')
        ..setFormField('D00-HDR', 'owner', 'Alice');
      final out = roundTrip(doc, const {}).doc;
      expect(out.formField('D00-HDR', 'title'), 'My System');
      expect(out.formField('D00-HDR', 'owner'), 'Alice');
    });

    test('list items and the seq counter survive (D3 continuity)', () {
      final doc = SpecDocument();
      final a = doc.addListItem('D00-REQ'); // -1
      final b = doc.addListItem('D00-REQ'); // -2
      doc.setContent('$a/text', 'first');
      doc.setContent('$b/text', 'second');
      doc.removeListItem(a); // seq stays at 2, item -1 gone

      final out = roundTrip(doc, const {}).doc;
      expect(out.listItems('D00-REQ'), [b]);
      expect(out.content('$b/text'), 'second');

      // The counter resumed from 2 → next add is -3, never reusing -1/-2.
      final c = out.addListItem('D00-REQ');
      expect(c, 'D00-REQ-3');
    });

    test('multi-line, leading-space, and trailing-newline values round-trip '
        'exactly', () {
      final tricky = {
        'D00-A': 'line one\nline two\nline three',
        'D00-B': '  indented first line\n    deeper',
        'D00-C': 'ends with newline\n',
        'D00-D': 'two trailing newlines\n\n', // JSON-quoted fallback
        'D00-E': '', // cleared → absent, never emitted
        'D00-F': 'value: with: colons # and hash',
      };
      final doc = SpecDocument();
      tricky.forEach(doc.setContent);
      final out = roundTrip(doc, const {}).doc;
      for (final e in tricky.entries) {
        expect(out.content(e.key), e.value.isEmpty ? isNull : e.value,
            reason: 'key ${e.key} must round-trip verbatim');
      }
    });

    test('the encoded YAML is human-readable: block scalars for multi-line '
        'content', () {
      final doc = SpecDocument()..setContent('D00-OVR', 'line one\nline two');
      final yaml = DocSpecsFile.encode(document: doc, review: const {});
      // A literal block scalar header, and the body visible as plain lines.
      expect(yaml, contains('|2-'));
      expect(yaml, contains('line one'));
      expect(yaml, contains('line two'));
    });

    test('an empty document omits all sections', () {
      final yaml = DocSpecsFile.encode(document: SpecDocument(), review: const {});
      expect(yaml, contains('document: {}'));
      expect(yaml, isNot(contains('content:')));
      expect(yaml, isNot(contains('forms:')));
      expect(yaml, isNot(contains('lists:')));
    });

    test('no duplicate subtrees: each section path appears once', () {
      final doc = SpecDocument()
        ..setContent('D00-OVR', 'x')
        ..setContent('D00-OVR/child', 'y');
      final yaml = DocSpecsFile.encode(document: doc, review: const {});
      expect('"D00-OVR":'.allMatches(yaml).length, 1);
      expect('"D00-OVR/child":'.allMatches(yaml).length, 1);
    });
  });

  group('review pass round-trip', () {
    test('populated review entries survive; empty ones are dropped', () {
      final review = <String, ReviewEntry>{
        'D00/a': ReviewEntry(
          scope: ReviewScope.global,
          stopHere: true,
          comment: 'keep me\nacross lines',
        ),
        'D00/b': ReviewEntry(), // empty → must not persist
      };
      final out = roundTrip(SpecDocument(), review).review;
      expect(out.keys, ['D00/a']);
      final e = out['D00/a']!;
      expect(e.scope, ReviewScope.global);
      expect(e.stopHere, isTrue);
      expect(e.comment, 'keep me\nacross lines');
    });

    test('an empty review map encodes as `review: {}`', () {
      final yaml = DocSpecsFile.encode(document: SpecDocument(), review: const {});
      expect(yaml, contains('review: {}'));
    });
  });

  group('decode tolerance', () {
    test('a missing pass decodes as empty rather than throwing', () {
      final parsed = DocSpecsFile.decode('version: 1\n');
      expect(parsed.document, isEmpty);
      expect(parsed.review, isEmpty);
    });

    test('an empty string decodes as empty', () {
      final parsed = DocSpecsFile.decode('');
      expect(parsed.document, isEmpty);
      expect(parsed.review, isEmpty);
    });
  });

  group('document model-version stamp (step 2)', () {
    test('encode writes the authoring modelVersion beside the format version',
        () {
      final yaml = DocSpecsFile.encode(
        document: SpecDocument(),
        review: const {},
        modelVersion: '0.7',
      );
      expect(yaml, contains('version: ${DocSpecsFile.formatVersion}'));
      expect(yaml, contains('modelVersion: '));
      // The stamp must read back through decode (the generic runtime path).
      expect(DocSpecsFile.decode(yaml).modelVersion, '0.7');
    });

    test('a fixture *.docspecs.yaml carries the stamp, read back on decode', () {
      const fixture = '''
version: 1
modelVersion: "1.2"
document: {}
review: {}
''';
      final parsed = DocSpecsFile.decode(fixture);
      expect(parsed.modelVersion, '1.2');
      expect(parsed.document, isEmpty);
      expect(parsed.review, isEmpty);
    });

    test('a file without the stamp decodes modelVersion as null', () {
      final yaml = DocSpecsFile.encode(
        document: SpecDocument(),
        review: const {},
      );
      expect(yaml, isNot(contains('modelVersion:')));
      expect(DocSpecsFile.decode(yaml).modelVersion, isNull);
    });
  });

  group('session-id sidecar (A2)', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('specs_docspecs_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('the session id lives in a sidecar, never in the document YAML', () {
      final doc = SpecDocument()..setContent('D00-OVR', 'x');
      final yaml = DocSpecsFile.encode(document: doc, review: const {});
      expect(yaml, isNot(contains('sess-1234')));
    });

    test('writeSessionId / readSessionId round-trips and clears', () async {
      final file = File('${dir.path}/doc.docspecs.yaml');
      await DocSpecsFile.writeSessionId(file, 'sess-1234');
      expect(DocSpecsFile.sidecarFor(file).existsSync(), isTrue);
      expect(await DocSpecsFile.readSessionId(file), 'sess-1234');

      await DocSpecsFile.writeSessionId(file, null);
      expect(DocSpecsFile.sidecarFor(file).existsSync(), isFalse);
      expect(await DocSpecsFile.readSessionId(file), isNull);
    });
  });

  group('controller wiring (§15.1)', () {
    late Directory dir;

    SpecDocumentController makeController() => SpecDocumentController(
          modelFuture: Future<SpecModel>.value(SpecModel.fromJson(_model())),
          review: ReviewStore(File('${dir.path}/review.yaml')),
        );

    setUp(() => dir = Directory.systemTemp.createTempSync('specs_ctl_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('save→load restores the full UI state and clears dirty + undo',
        () async {
      final file = File('${dir.path}/doc.docspecs.yaml');
      final c = makeController();
      c.setContent('D00-OVR', 'authored');
      c.setReview('D00-OVR', (e) => e.scope = ReviewScope.global);
      expect(c.isDirty, isTrue);
      expect(c.canUndo, isTrue);

      await c.saveDocSpecs(file, sessionId: 'sess-42');
      expect(c.isDirty, isFalse); // save re-baselines
      expect(c.canUndo, isTrue); // undo stack kept across save (N6)

      // A fresh controller loads the file and sees the same state.
      final c2 = makeController();
      final session = await c2.loadDocSpecs(file);
      expect(c2.content('D00-OVR'), 'authored');
      expect(c2.review.entryFor('D00-OVR')?.scope, ReviewScope.global);
      expect(session, 'sess-42');
      expect(c2.isDirty, isFalse); // load is a fresh save point
      expect(c2.canUndo, isFalse); // undo stack cleared on load
    });

    test('the agent change log is not serialized (resets on save, M2)',
        () async {
      final file = File('${dir.path}/doc.docspecs.yaml');
      final c = makeController();
      c.setContent('D00-OVR', 'x');
      expect(c.changeLog.length, 1);

      await c.saveDocSpecs(file);
      expect(c.changeLog.length, 0); // save() reset the log

      final yaml = await file.readAsString();
      expect(yaml, isNot(contains('changeLog')));
      expect(yaml, isNot(contains('change_log')));
    });
  });
}

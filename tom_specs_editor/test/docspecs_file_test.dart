import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_som_dart_runtime/tom_som_dart_runtime.dart'
    show buildSomMetaTree, SpecYamlFormatException;
import 'package:tom_specs_editor/src/document/docspecs_file.dart';
import 'package:tom_specs_editor/src/document/spec_document.dart';
import 'package:tom_specs_editor/src/document/spec_document_controller.dart';
import 'package:tom_specs_editor/src/structure/review_store.dart';
import 'package:tom_specs_editor/src/structure/spec_model.dart';

/// A single-root model exercising the field kinds the tree-driven codec
/// walks: content sections, a `@Form`, a complex list with a section-id
/// pattern, and a scalar list. The codec keys every value by its hierarchical
/// section-id path from the root (`D00/D00-OVR`, `D00/D00-HDR`, …), so the
/// schema shape drives which paths are valid.
Map<String, dynamic> _model() => {
  'roots': [
    {'type': 'DemoDoc', 'title': 'Demo', 'sectionId': 'D00'},
  ],
  'classes': {
    'DemoDoc': {
      'name': 'DemoDoc',
      'sectionId': 'D00',
      'fields': [
        {
          'name': 'overview',
          'kind': 'content',
          'sectionId': 'D00-OVR',
          'serializationOrder': 0,
        },
        {
          'name': 'summary',
          'kind': 'content',
          'sectionId': 'D00-SUM',
          'serializationOrder': 1,
        },
        {
          'name': 'header',
          'kind': 'form',
          'sectionId': 'D00-HDR',
          'serializationOrder': 2,
          'formFields': [
            {'name': 'title', 'label': 'Title', 'type': 'String'},
            {'name': 'owner', 'label': 'Owner', 'type': 'String'},
          ],
        },
        {
          'name': 'requirements',
          'kind': 'list',
          'sectionId': 'D00-REQ',
          'sectionIdPattern': 'REQ-xxx',
          'elementType': 'Requirement',
          'elementIsComplex': true,
          'serializationOrder': 3,
        },
        {
          'name': 'tags',
          'kind': 'list',
          'sectionId': 'D00-TAG',
          'elementType': 'String',
          'elementIsComplex': false,
          'serializationOrder': 4,
        },
      ],
    },
    'Requirement': {
      'name': 'Requirement',
      'fields': [
        {'name': 'text', 'kind': 'content', 'serializationOrder': 0},
      ],
    },
  },
};

void main() {
  final tree = buildSomMetaTree(SpecModel.fromJson(_model()));

  String encode(
    SpecDocument doc, {
    Map<String, ReviewEntry> review = const {},
  }) => DocSpecsFile.encode(document: doc, tree: tree, review: review);

  /// Encodes [doc] + [review], then decodes back to a live document / review
  /// map — the save→load round-trip under test. The decoder returns a
  /// live [SpecDocument] directly.
  ({SpecDocument doc, Map<String, ReviewEntry> review}) roundTrip(
    SpecDocument doc, [
    Map<String, ReviewEntry> review = const {},
  ]) {
    final parsed = DocSpecsFile.decode(encode(doc, review: review), tree);
    return (doc: parsed.document, review: parsed.review);
  }

  group('document pass round-trip', () {
    test('content values survive a save→load', () {
      final doc = SpecDocument()
        ..setContent('D00/D00-OVR', 'hello world')
        ..setContent('D00/D00-SUM', 'a summary');
      final out = roundTrip(doc).doc;
      expect(out.content('D00/D00-OVR'), 'hello world');
      expect(out.content('D00/D00-SUM'), 'a summary');
    });

    test('form fields survive a save→load', () {
      final doc = SpecDocument()
        ..setFormField('D00/D00-HDR', 'title', 'My System')
        ..setFormField('D00/D00-HDR', 'owner', 'Alice');
      final out = roundTrip(doc).doc;
      expect(out.formField('D00/D00-HDR', 'title'), 'My System');
      expect(out.formField('D00/D00-HDR', 'owner'), 'Alice');
    });

    test('list items survive with their ids, content, and order', () {
      final doc = SpecDocument();
      final a = doc.addListItem('D00/D00-REQ', sectionId: 'REQ-1');
      final b = doc.addListItem('D00/D00-REQ'); // anonymous positional item
      doc.setContent('$a/text', 'first');
      doc.setContent('$b/text', 'second');

      final out = roundTrip(doc).doc;
      final items = out.listItems('D00/D00-REQ');
      expect(items, hasLength(2));
      expect(out.itemSectionId(items[0]), 'REQ-1');
      expect(out.itemSectionId(items[1]), isNull); // anonymous stays anonymous
      expect(out.content('${items[0]}/text'), 'first');
      expect(out.content('${items[1]}/text'), 'second');
    });

    test('scalar list items round-trip', () {
      final doc = SpecDocument();
      final t = doc.addListItem('D00/D00-TAG');
      doc.setContent(t, 'alpha');
      final out = roundTrip(doc).doc;
      final tags = out.listItems('D00/D00-TAG');
      expect(out.content(tags.single), 'alpha');
    });

    test('multi-line, leading-space, and trailing-newline values round-trip '
        'exactly', () {
      final tricky = <String>[
        'line one\nline two\nline three',
        '  indented first line\n    deeper',
        'ends with newline\n',
        'two trailing newlines\n\n', // JSON-quoted fallback
        'value: with: colons # and hash',
        '- looks: like\n  yaml: [a, b]\n# comment-ish',
      ];
      for (var i = 0; i < tricky.length; i++) {
        final doc = SpecDocument()..setContent('D00/D00-OVR', tricky[i]);
        final out = roundTrip(doc).doc;
        expect(
          out.content('D00/D00-OVR'),
          tricky[i],
          reason: 'case #$i must round-trip verbatim',
        );
      }
    });

    test('a cleared (empty) value is never emitted', () {
      final doc = SpecDocument()..setContent('D00/D00-OVR', '');
      final yaml = encode(doc);
      // An empty document keeps its root key with an empty body (SOM §12.3).
      expect(yaml, matches(RegExp(r'\ndocument:\n  [^\n]+: \{\}\n')));
      expect(roundTrip(doc).doc.content('D00/D00-OVR'), isNull);
    });

    test('the encoded YAML is human-readable: block scalars for multi-line '
        'content', () {
      final doc = SpecDocument()
        ..setContent('D00/D00-OVR', 'line one\nline two');
      final yaml = encode(doc);
      // A literal block scalar header, and the body visible as plain lines.
      expect(yaml, contains('|2-'));
      expect(yaml, contains('line one'));
      expect(yaml, contains('line two'));
    });

    test('an empty document omits all sections', () {
      final yaml = encode(SpecDocument());
      expect(yaml, matches(RegExp(r'\ndocument:\n  [^\n]+: \{\}\n')));
      expect(yaml, isNot(contains('D00-OVR')));
      expect(yaml, isNot(contains('D00-HDR')));
      expect(yaml, isNot(contains('D00-REQ')));
    });

    test('no duplicate subtrees: each section is emitted once', () {
      final doc = SpecDocument()
        ..setContent('D00/D00-OVR', 'x')
        ..setContent('D00/D00-SUM', 'y');
      final yaml = encode(doc);
      expect('D00-OVR overview:'.allMatches(yaml).length, 1);
      expect('D00-SUM summary:'.allMatches(yaml).length, 1);
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
      final yaml = encode(SpecDocument());
      expect(yaml, contains('review: {}'));
    });
  });

  group('strict decode', () {
    test('a version-1 (flat path-map) file is rejected', () {
      expect(
        () => DocSpecsFile.decode('version: 1\ndocument: {}\n', tree),
        throwsA(
          isA<SpecYamlFormatException>().having(
            (e) => e.message,
            'message',
            contains('version 1'),
          ),
        ),
      );
    });

    test('an empty string is rejected', () {
      expect(
        () => DocSpecsFile.decode('', tree),
        throwsA(isA<SpecYamlFormatException>()),
      );
    });

    test('a missing version is rejected', () {
      expect(
        () => DocSpecsFile.decode('document: {}\n', tree),
        throwsA(isA<SpecYamlFormatException>()),
      );
    });

    test('a value the metadata tree cannot place is a structured error', () {
      final doc = SpecDocument()..setContent('D00/ghost', 'x');
      expect(() => encode(doc), throwsA(isA<SpecYamlFormatException>()));
    });

    test('a missing/empty document pass on a v2 file decodes as empty', () {
      expect(
        DocSpecsFile.decode('version: 2\n', tree).document.isEmpty,
        isTrue,
      );
      expect(
        DocSpecsFile.decode(
          'version: 2\ndocument: {}\n',
          tree,
        ).document.isEmpty,
        isTrue,
      );
    });
  });

  group('document model-version stamp', () {
    test(
      'encode writes the authoring modelVersion beside the format version',
      () {
        final yaml = DocSpecsFile.encode(
          document: SpecDocument(),
          tree: tree,
          review: const {},
          modelVersion: '0.7',
        );
        expect(yaml, contains('version: ${DocSpecsFile.formatVersion}'));
        expect(yaml, contains('modelVersion: '));
        // The stamp must read back through decode (the generic runtime path).
        expect(DocSpecsFile.decode(yaml, tree).modelVersion, '0.7');
      },
    );

    test(
      'a fixture *.docspecs.yaml carries the stamp, read back on decode',
      () {
        const fixture = '''
version: 2
modelVersion: "1.2"
document: {}
review: {}
''';
        final parsed = DocSpecsFile.decode(fixture, tree);
        expect(parsed.modelVersion, '1.2');
        expect(parsed.document.isEmpty, isTrue);
        expect(parsed.review, isEmpty);
      },
    );

    test('a file without the stamp decodes modelVersion as null', () {
      final yaml = encode(SpecDocument());
      expect(yaml, isNot(contains('modelVersion:')));
      expect(DocSpecsFile.decode(yaml, tree).modelVersion, isNull);
    });
  });

  group('session-id sidecar (A2)', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('specs_docspecs_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('the session id lives in a sidecar, never in the document YAML', () {
      final doc = SpecDocument()..setContent('D00/D00-OVR', 'x');
      final yaml = encode(doc);
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

  group('controller wiring (tom_specs_editor_specification.md §15.1)', () {
    late Directory dir;

    SpecDocumentController makeController() => SpecDocumentController(
      modelFuture: Future<SpecModel>.value(SpecModel.fromJson(_model())),
      review: ReviewStore(File('${dir.path}/review.yaml')),
    );

    setUp(() => dir = Directory.systemTemp.createTempSync('specs_ctl_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test(
      'save→load restores the full UI state and clears dirty + undo',
      () async {
        final file = File('${dir.path}/doc.docspecs.yaml');
        final c = makeController();
        c.setContent('D00/D00-OVR', 'authored');
        c.setReview('D00/D00-OVR', (e) => e.scope = ReviewScope.global);
        expect(c.isDirty, isTrue);
        expect(c.canUndo, isTrue);

        await c.saveDocSpecs(file, sessionId: 'sess-42');
        expect(c.isDirty, isFalse); // save re-baselines
        expect(c.canUndo, isTrue); // undo stack kept across save (N6)

        // A fresh controller loads the file and sees the same state.
        final c2 = makeController();
        final session = await c2.loadDocSpecs(file);
        expect(c2.content('D00/D00-OVR'), 'authored');
        expect(c2.review.entryFor('D00/D00-OVR')?.scope, ReviewScope.global);
        expect(session, 'sess-42');
        expect(c2.isDirty, isFalse); // load is a fresh save point
        expect(c2.canUndo, isFalse); // undo stack cleared on load
      },
    );

    test(
      'the agent change log is not serialized (resets on save, M2)',
      () async {
        final file = File('${dir.path}/doc.docspecs.yaml');
        final c = makeController();
        c.setContent('D00/D00-OVR', 'x');
        expect(c.changeLog.length, 1);

        await c.saveDocSpecs(file);
        expect(c.changeLog.length, 0); // save() reset the log

        final yaml = await file.readAsString();
        expect(yaml, isNot(contains('changeLog')));
        expect(yaml, isNot(contains('change_log')));
      },
    );
  });
}

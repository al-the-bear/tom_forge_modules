/// The TomSpecs document editor over one spec file of a shell's file system
/// (qim_none-9): what Webforge offers for a `*.docspecs.yaml` or
/// `*.tomspecs.yaml` beside the YAML editor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_specs_editor/src/document/spec_document_controller.dart';
import 'package:tom_specs_editor/src/structure/review_store.dart';
import 'package:tom_specs_editor/tom_specs_editor.dart';
import 'support/review_store_support.dart';

const _overview = 'D00/D00-OVR';

Map<String, dynamic> _json() => {
  'roots': [
    {'type': 'DemoDoc', 'title': 'Demo Document', 'sectionId': 'D00'},
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

/// A spec document holding [overview], as `*.docspecs.yaml` text.
Future<String> _document(String overview) async {
  final writer = SpecDocumentController(
    modelFuture: Future.value(SpecModel.fromJson(_json())),
    review: memoryReviewStore(),
  );
  await writer.ensureLoaded();
  writer.setContent(_overview, overview);
  return writer.encodeDocSpecs();
}

void main() {
  test('QIMN9-1: the spec files are *.docspecs.yaml and *.tomspecs.yaml', () {
    expect(isTomSpecsFile(Uri.parse('file:///ws/a.docspecs.yaml')), isTrue);
    expect(isTomSpecsFile(Uri.parse('file:///ws/b.tomspecs.yaml')), isTrue);
    expect(isTomSpecsFile(Uri.parse('file:///ws/C.DocSpecs.YAML')), isTrue);
    expect(isTomSpecsFile(Uri.parse('file:///ws/config.yaml')), isFalse);
    expect(isTomSpecsFile(Uri.parse('file:///ws/a.docspecs.md')), isFalse);
  });

  test('QIMN9-2: the editor loads the file through the file system, an edit '
      'makes it dirty, its content is the document as the file format, and '
      'the shell\'s save makes the save point', () async {
    final fs = TomMemoryFileSystem(
      seed: {'/ws/demo.docspecs.yaml': await _document('Roses')},
    );
    final uri = fs.uriOf('/ws/demo.docspecs.yaml');
    final editor = SpecFileEditor(
      uri: uri,
      fileSystem: fs,
      model: Future.value(SpecModel.fromJson(_json())),
    );
    expect(editor.getContent(), isNull, reason: 'nothing before the load');
    await editor.loaded;

    expect(editor.uri, uri);
    expect(editor.title.value, 'demo.docspecs.yaml');
    expect(editor.controller.content(_overview), 'Roses');
    expect(editor.isDirty.value, isFalse, reason: 'a load is a save point');

    editor.controller.setContent(_overview, 'Roses and tulips');
    expect(editor.isDirty.value, isTrue);

    // What the shell writes reads back as the edited document.
    final written = editor.getContent()!;
    final reader = SpecDocumentController(
      modelFuture: Future.value(SpecModel.fromJson(_json())),
      review: ReviewStore.inDocument(),
    );
    await reader.loadDocSpecsText(written);
    expect(reader.content(_overview), 'Roses and tulips');

    editor.markClean();
    expect(editor.isDirty.value, isFalse);
    expect(editor.controller.isDirty, isFalse);
    expect(
      editor.controller.canUndo,
      isTrue,
      reason: 'the save keeps the history',
    );
  });

  testWidgets('QIMN9-3: the editor shows the document once it is loaded, and '
      'says so when the file is not a spec document', (tester) async {
    final fs = TomMemoryFileSystem(
      seed: {
        '/ws/demo.docspecs.yaml':
            await tester.runAsync(() => _document('Roses')) as String,
        '/ws/broken.docspecs.yaml': '- not: [a spec',
      },
    );
    Future<void> show(String path) async {
      final editor = SpecFileEditor(
        uri: fs.uriOf(path),
        fileSystem: fs,
        model: Future.value(SpecModel.fromJson(_json())),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Builder(builder: editor.buildMain)),
        ),
      );
      await tester.runAsync(() => editor.loaded.catchError((_) {}));
      await tester.pumpAndSettle();
    }

    await show('/ws/demo.docspecs.yaml');
    expect(find.textContaining('Roses', findRichText: true), findsWidgets);

    await show('/ws/broken.docspecs.yaml');
    expect(
      find.textContaining('could not be opened as a TomSpecs document'),
      findsOneWidget,
    );
  });
}

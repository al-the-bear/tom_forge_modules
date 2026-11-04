/// A spec document's embedded Dart code field keeps no history of its own
/// (wonecmpc23): the Dart editor runs in its external history mode over the
/// document's history, so the field's typing is written to the document at
/// once, is one document undo entry per gesture, and undoes in order with
/// the document's other edits.
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart' show DartCodeController;
import 'package:tom_specs_editor/src/document/spec_document_controller.dart';
import 'package:tom_specs_editor/src/document/spec_document_editor.dart'
    show SpecDocumentFieldHistory;
import 'package:tom_specs_editor/src/structure/review_store.dart';
import 'package:tom_specs_editor/src/structure/spec_model.dart';

Map<String, dynamic> _model() => {
  'roots': [
    {'type': 'DemoDoc', 'title': 'Demo', 'sectionId': 'D00'},
  ],
  'classes': {
    'DemoDoc': {
      'name': 'DemoDoc',
      'sectionId': 'D00',
      'fields': [
        {'name': 'code', 'kind': 'content', 'sectionId': 'D00-COD'},
        {'name': 'notes', 'kind': 'content', 'sectionId': 'D00-NTS'},
      ],
    },
  },
};

const _code = 'D00-COD';
const _notes = 'D00-NTS';

TextSelection _at(int offset) => TextSelection.collapsed(offset: offset);

void main() {
  late Directory dir;
  late SpecDocumentController doc;
  late DartCodeController field;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('wonecmpc23_');
    doc = SpecDocumentController(
      modelFuture: Future<SpecModel>.value(SpecModel.fromJson(_model())),
      review: ReviewStore(File('${dir.path}/review.yaml')),
    );
    field = DartCodeController(
      historyHost: SpecDocumentFieldHistory(doc, _code),
    );
  });

  tearDown(() {
    field.dispose();
    doc.dispose();
    dir.deleteSync(recursive: true);
  });

  test('CF-1: typing is written at once and is one entry per gesture', () async {
    field.edit('a', _at(1));
    field.edit('ab', _at(2));
    expect(doc.content(_code), 'ab', reason: 'written at once');
    expect(doc.isDirty, isTrue);
    expect(doc.canUndo, isTrue, reason: 'the typing in progress');
    expect(field.canUndo, isTrue, reason: 'the field reads the document');
    field.select(_at(0)); // a caret move ends the gesture
    expect(doc.changeLog.length, 1);
    field.edit('xab', _at(1));
    field.select(_at(3));
    expect(doc.changeLog.length, 2);

    field.undo(); // the field's undo is the document's
    await pumpEventQueue();
    expect(doc.content(_code), 'ab');
    await doc.undo();
    expect(doc.content(_code), isNull);
    expect(doc.isDirty, isFalse);
    await doc.redo();
    expect(doc.content(_code), 'ab');
  });

  test('CF-2: another edit ends the typing first, and the two undo in the '
      'order they were made', () async {
    field.edit('code', _at(4));
    doc.setContent(_notes, 'note');
    expect(doc.changeLog.length, 2);
    await doc.undo();
    expect(doc.content(_notes), isNull);
    expect(doc.content(_code), 'code');
    await doc.undo();
    expect(doc.content(_code), isNull);
  });

  test('CF-3: undo while typing undoes the typing; typing ends the redo '
      'future; save ends the typing', () async {
    field.edit('one', _at(3));
    await doc.undo();
    expect(doc.content(_code), isNull, reason: 'not lost, not late');
    expect(doc.canRedo, isTrue);
    field.edit('two', _at(3));
    expect(doc.canRedo, isFalse);
    doc.save();
    expect(doc.isTyping, isFalse);
    expect(doc.isDirty, isFalse);
    expect(doc.changeLog.length, 0, reason: 'the save resets the log');
    await doc.undo();
    expect(doc.content(_code), isNull);
    expect(doc.isDirty, isTrue, reason: 'undone past the save');
  });

  test('CF-4: typing back to where it started is no entry', () async {
    field.edit('x', _at(1));
    field.edit('', _at(0));
    field.flush();
    expect(doc.canUndo, isFalse);
    expect(doc.changeLog.length, 0);
  });
}

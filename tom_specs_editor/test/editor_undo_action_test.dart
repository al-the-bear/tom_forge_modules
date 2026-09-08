// Proof for OE-11: the document editor exposes its controller's undo stack
// through the shell's standard editing-action seam (`EditorActionProvider`),
// so the shell's global undo/redo button — which routes
// `forge.edit.undo`/`forge.edit.redo` to the *active editor* — reflects and
// drives the document's own `DefaultUndoManager`. No `notifyTextEdit` bridge
// is used (that would double-count); the controller stays the single authority.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;
import 'package:tom_specs_editor/src/document/spec_document_controller.dart';
import 'package:tom_specs_editor/src/document/spec_document_editor.dart';
import 'package:tom_specs_editor/src/structure/review_store.dart';
import 'package:tom_specs_editor/src/structure/spec_model.dart';

/// A trivial single-content-field model; the undo seam operates purely on
/// section-ID paths, so the schema shape is irrelevant.
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

void main() {
  late Directory dir;

  SpecDocumentController makeController() => SpecDocumentController(
    modelFuture: Future<SpecModel>.value(SpecModel.fromJson(_model())),
    review: ReviewStore(File('${dir.path}/review.yaml')),
  );

  setUp(() => dir = Directory.systemTemp.createTempSync('specs_editor_undo_'));
  tearDown(() => dir.deleteSync(recursive: true));

  final undoId = StandardEditingActions.undoActionId;
  final redoId = StandardEditingActions.redoActionId;

  test('the editor advertises undo/redo as supported standard actions', () {
    final editor = SpecDocumentEditor(controller: makeController());
    expect(editor.supportedActionIds, containsAll([undoId, redoId]));
    expect(editor.capabilities.supportsUndoRedo, isTrue);
  });

  test('undo/redo enablement tracks the controller stack', () async {
    final c = makeController();
    final editor = SpecDocumentEditor(controller: c);

    // Nothing on the stack yet: both disabled.
    expect(editor.stateSnapshot.canUndo, isFalse);
    expect(editor.stateSnapshot.canRedo, isFalse);
    expect(editor.isActionEnabled(undoId), isFalse);
    expect(editor.isActionEnabled(redoId), isFalse);

    // An edit makes undo available (but not redo).
    c.setContent('D00-OVR', 'hi');
    expect(editor.stateSnapshot.canUndo, isTrue);
    expect(editor.stateSnapshot.canRedo, isFalse);
    expect(editor.isActionEnabled(undoId), isTrue);
    expect(editor.isActionEnabled(redoId), isFalse);
  });

  test('executeAction routes undo/redo to the controller', () async {
    final c = makeController();
    final editor = SpecDocumentEditor(controller: c);
    c.setContent('D00-OVR', 'hi');

    // The shell's standard-undo route lands on the controller's stack.
    expect(editor.executeAction(undoId), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(c.content('D00-OVR'), isNull);
    expect(editor.stateSnapshot.canRedo, isTrue);
    expect(editor.isActionEnabled(redoId), isTrue);

    // ...and redo replays it.
    expect(editor.executeAction(redoId), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(c.content('D00-OVR'), 'hi');

    // An unsupported action is not handled here.
    expect(editor.executeAction('forge.edit.cut'), isFalse);
  });

  test('onStateChanged fires when the controller changes', () async {
    final c = makeController();
    final editor = SpecDocumentEditor(controller: c);
    final events = <void>[];
    final sub = editor.onStateChanged.listen(events.add);
    addTearDown(sub.cancel);

    c.setContent('D00-OVR', 'hi');
    await Future<void>.delayed(Duration.zero);
    expect(events, isNotEmpty);
  });
}

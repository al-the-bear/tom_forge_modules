import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_agentic/tom_forge_agentic.dart';
import 'package:tom_specs_editor/src/document/spec_document_controller.dart';
import 'package:tom_specs_editor/src/structure/spec_model.dart';
import 'support/review_store_support.dart';

/// A trivial single-root model; the undo/change-log machinery operates purely
/// on section-ID paths, so the schema shape is irrelevant here.
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
  SpecDocumentController makeController({int max = 50}) =>
      SpecDocumentController(
        modelFuture: Future<SpecModel>.value(SpecModel.fromJson(_model())),
        review: memoryReviewStore(),
        maxSnapshots: max,
      );

  group('snapshot undo/redo', () {
    test('an edit is undoable and redoable', () async {
      final c = makeController();
      c.setContent('D00-OVR', 'hello');
      expect(c.content('D00-OVR'), 'hello');
      expect(c.canUndo, isTrue);

      await c.undo();
      expect(c.content('D00-OVR'), isNull);
      expect(c.canRedo, isTrue);

      await c.redo();
      expect(c.content('D00-OVR'), 'hello');
    });

    test('a no-op edit does not snapshot', () {
      final c = makeController();
      c.setContent('D00-OVR', 'x');
      expect(c.changeLog.length, 1);
      c.setContent('D00-OVR', 'x'); // same value → no change
      expect(c.changeLog.length, 1);
    });

    test('the snapshot stack is capped', () {
      final c = makeController(max: 2);
      c.setContent('D00-OVR', 'a');
      c.setContent('D00-OVR', 'b');
      c.setContent('D00-OVR', 'c');
      // Cap of 2 keeps the two most recent undo entries.
      expect(c.canUndo, isTrue);
    });
  });

  group('agent turn grouping (tom_specs_editor_specification.md §9/§10)', () {
    test(
      'an agent turn is one undo step but individual changes are inspectable',
      () async {
        final c = makeController();
        c.beginTurn('t1');
        c.setContent('D00-OVR', 'first');
        c.setContent('D00-OVR', 'second');
        c.setContent('D00-OVR', 'third');
        c.endTurn();

        // Three inspectable change-log entries, all in turn t1.
        expect(c.changeLog.length, 3);
        expect(c.changeLog.groups, hasLength(1));
        expect(c.changeLog.groups.single.turnId, 't1');

        // ...but a single undo step reverts the whole turn.
        await c.undo();
        expect(c.content('D00-OVR'), isNull);
        expect(c.canUndo, isFalse);
      },
    );
  });

  group('pick-a-pane (tom_specs_editor_specification.md §9 M1)', () {
    test('applying a pane pick creates a new undo entry', () async {
      final c = makeController();
      c.setContent('D00-OVR', 'base');
      c.save(); // base captured; change log reset.
      c.setContent('D00-OVR', 'edited');

      final entry = c.changeLog.entries.single;
      expect(entry.baseAtLastSave, 'base');
      expect(entry.afterThisEdit, 'edited');

      // Picking the "base" pane (different from current) is a fresh edit.
      c.applyPanePick(entry, ReviewPane.base);
      expect(c.content('D00-OVR'), 'base');

      // It is fully undoable, returning to the edited value.
      await c.undo();
      expect(c.content('D00-OVR'), 'edited');
    });

    test('picking the current value is a no-op', () {
      final c = makeController();
      c.setContent('D00-OVR', 'v');
      final entry = c.changeLog.entries.single;
      final before = c.changeLog.length;
      c.applyPanePick(entry, ReviewPane.current);
      expect(c.changeLog.length, before); // nothing new recorded
    });
  });

  group('save lifecycle (tom_specs_editor_specification.md §9 M2)', () {
    test('save resets the change log but keeps the undo stack', () {
      final c = makeController();
      c.setContent('D00-OVR', 'v');
      expect(c.changeLog.isEmpty, isFalse);
      expect(c.isDirty, isTrue);

      c.save();
      expect(c.changeLog.isEmpty, isTrue);
      expect(c.isDirty, isFalse);
      // The snapshot stack survives the save (post-save undo, N6).
      expect(c.canUndo, isTrue);
    });

    test('undoing back to the saved state clears dirty', () async {
      final c = makeController();
      c.setContent('D00-OVR', 'v');
      expect(c.isDirty, isTrue);
      await c.undo();
      expect(c.isDirty, isFalse);
    });
  });
}

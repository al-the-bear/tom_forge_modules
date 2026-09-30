/// An entry whose application throws stays on the stack it was taken from,
/// and a composite that fails part-way puts back what it had already applied.
///
/// `undo()` used to pop the entry *before* awaiting it, so an entry whose
/// undo threw was gone from both stacks — the act neither undone nor
/// redoable. Consumers that noticed (Webwork's annotation reversal) worked
/// around it by never throwing, which is a rule hoped for rather than held.
/// The guarantee belongs here, once, for every consumer.
library;

import 'package:test/test.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

UndoEntry _entry(String label, List<String> log, {bool undoThrows = false, bool redoThrows = false}) =>
    UndoEntry(
      label: label,
      undo: () async {
        if (undoThrows) throw StateError('$label refuses to undo');
        log.add('undo $label');
      },
      redo: () async {
        if (redoThrows) throw StateError('$label refuses to redo');
        log.add('redo $label');
      },
    );

void main() {
  group('DefaultUndoManager keeps an entry whose application throws', () {
    test('a failed undo leaves the entry on the undo stack and rethrows', () async {
      final manager = DefaultUndoManager();
      final log = <String>[];
      manager.push(_entry('a', log));
      manager.push(_entry('b', log, undoThrows: true));
      final events = <UndoEventType>[];
      manager.onUndoEvent.listen((e) => events.add(e.type));

      await expectLater(manager.undo(), throwsStateError);

      expect(manager.undoCount, 2, reason: 'b is still to be undone');
      expect(manager.redoCount, 0);
      expect(manager.nextUndoLabel, 'b');
      expect(manager.canUndo.value, isTrue);
      expect(log, isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty, reason: 'nothing was undone, so nothing is announced');
    });

    test('a failed redo leaves the entry on the redo stack', () async {
      final manager = DefaultUndoManager();
      final log = <String>[];
      manager.push(_entry('a', log, redoThrows: true));
      await manager.undo();
      expect(manager.redoCount, 1);

      await expectLater(manager.redo(), throwsStateError);

      expect(manager.redoCount, 1);
      expect(manager.undoCount, 0);
      expect(manager.nextRedoLabel, 'a');
      expect(log, ['undo a']);
    });

    test('the same entry can be retried and then moves', () async {
      final manager = DefaultUndoManager();
      final log = <String>[];
      var refuse = true;
      manager.push(UndoEntry(
        label: 'flaky',
        undo: () async {
          if (refuse) throw StateError('not now');
          log.add('undo');
        },
        redo: () async => log.add('redo'),
      ));
      await expectLater(manager.undo(), throwsStateError);
      refuse = false;
      await manager.undo();
      expect(manager.undoCount, 0);
      expect(manager.redoCount, 1);
      expect(log, ['undo']);
    });
  });

  group('CompositeUndoEntry is atomic on failure', () {
    test('a failed undo puts back the entries already undone, in order', () async {
      final manager = DefaultUndoManager();
      final log = <String>[];
      manager.beginUndoGroup(label: 'step');
      manager.push(_entry('first', log, undoThrows: true));
      manager.push(_entry('second', log));
      manager.push(_entry('third', log));
      manager.endUndoGroup();

      await expectLater(manager.undo(), throwsStateError);

      // Undone newest-first: third, second; then first threw; so second and
      // third are redone, oldest-first.
      expect(log, ['undo third', 'undo second', 'redo second', 'redo third']);
      expect(manager.undoCount, 1, reason: 'the step is whole and still there');
      expect(manager.nextUndoLabel, 'step');
    });

    test('a failed redo puts back the entries already redone', () async {
      final manager = DefaultUndoManager();
      final log = <String>[];
      manager.beginUndoGroup(label: 'step');
      manager.push(_entry('first', log));
      manager.push(_entry('second', log));
      manager.push(_entry('third', log, redoThrows: true));
      manager.endUndoGroup();
      await manager.undo();
      log.clear();

      await expectLater(manager.redo(), throwsStateError);

      expect(log, ['redo first', 'redo second', 'undo second', 'undo first']);
      expect(manager.redoCount, 1);
      expect(manager.undoCount, 0);
    });
  });
}

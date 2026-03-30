import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

void main() {
  late DefaultShortcutManager manager;
  late ForgeAction saveAction;
  late ForgeAction toggleCommentAction;
  late ForgeAction blockCommentAction;
  late ForgeShortcutKey ctrlS;
  late ForgeShortcutKey ctrlK;
  late ForgeShortcutKey ctrlC;
  late ForgeShortcutKey ctrlA;

  setUp(() {
    manager = DefaultShortcutManager();

    saveAction = ForgeAction(
      id: 'file.save',
      label: 'Save',
      execute: (_) async => null,
      isEnabled: () => true,
      isVisible: () => true,
    );

    toggleCommentAction = ForgeAction(
      id: 'edit.toggleComment',
      label: 'Toggle Line Comment',
      execute: (_) async => null,
      isEnabled: () => true,
      isVisible: () => true,
    );

    blockCommentAction = ForgeAction(
      id: 'edit.toggleBlockComment',
      label: 'Toggle Block Comment',
      execute: (_) async => null,
      isEnabled: () => true,
      isVisible: () => true,
    );

    ctrlS = const ForgeShortcutKey(
      key: LogicalKeyboardKey.keyS,
      primaryModifier: true,
    );
    ctrlK = const ForgeShortcutKey(
      key: LogicalKeyboardKey.keyK,
      primaryModifier: true,
    );
    ctrlC = const ForgeShortcutKey(
      key: LogicalKeyboardKey.keyC,
      primaryModifier: true,
    );
    ctrlA = const ForgeShortcutKey(
      key: LogicalKeyboardKey.keyA,
      primaryModifier: true,
    );
  });

  tearDown(() {
    manager.dispose();
  });

  // ── Basic binding management ────────────────────────────

  group('Basic binding management', () {
    test('loadBindings populates allBindings', () {
      manager.loadBindings([
        ForgeShortcutBinding(action: saveAction, key: ctrlS),
      ]);
      expect(manager.allBindings, hasLength(1));
      expect(manager.allBindings.first.action.id, 'file.save');
    });

    test('getBinding returns binding by action id', () {
      manager.loadBindings([
        ForgeShortcutBinding(action: saveAction, key: ctrlS),
      ]);
      final binding = manager.getBinding('file.save');
      expect(binding, isNotNull);
      expect(binding!.key, ctrlS);
    });

    test('getBinding returns null for unknown action', () {
      manager.loadBindings([]);
      expect(manager.getBinding('unknown'), isNull);
    });

    test('rebind changes the key for an existing action', () {
      manager.loadBindings([
        ForgeShortcutBinding(action: saveAction, key: ctrlS),
      ]);
      final newKey = const ForgeShortcutKey(
        key: LogicalKeyboardKey.keyS,
        primaryModifier: true,
        shift: true,
      );
      manager.rebind(saveAction, newKey);
      expect(manager.getBinding('file.save')!.key, newKey);
    });

    test('resetToDefault restores original key', () {
      manager.loadBindings([
        ForgeShortcutBinding(action: saveAction, key: ctrlS),
      ]);
      final newKey = const ForgeShortcutKey(
        key: LogicalKeyboardKey.keyX,
        primaryModifier: true,
      );
      manager.rebind(saveAction, newKey);
      manager.resetToDefault(saveAction);
      expect(manager.getBinding('file.save')!.key, ctrlS);
    });

    test('conflictsWith detects key collision', () {
      manager.loadBindings([
        ForgeShortcutBinding(action: saveAction, key: ctrlS),
      ]);
      expect(manager.conflictsWith(ctrlS), isNotNull);
      expect(manager.conflictsWith(ctrlK), isNull);
    });
  });

  // ── Chord bindings ─────────────────────────────────────

  group('Chord bindings', () {
    late List<ForgeShortcutBinding> bindings;

    setUp(() {
      bindings = [
        ForgeShortcutBinding(action: saveAction, key: ctrlS),
        ForgeShortcutBinding(
          action: toggleCommentAction,
          key: ctrlK,
          chord: ForgeChordKey(firstKey: ctrlK, secondKey: ctrlC),
        ),
        ForgeShortcutBinding(
          action: blockCommentAction,
          key: ctrlK,
          chord: ForgeChordKey(firstKey: ctrlK, secondKey: ctrlA),
        ),
      ];
      manager.loadBindings(bindings);
    });

    test('chordBindings returns only chord entries', () {
      expect(manager.chordBindings, hasLength(2));
      expect(
        manager.chordBindings.map((b) => b.action.id),
        containsAll(['edit.toggleComment', 'edit.toggleBlockComment']),
      );
    });

    test('isChord flag is correct on bindings', () {
      final save = manager.getBinding('file.save')!;
      final comment = manager.getBinding('edit.toggleComment')!;
      expect(save.isChord, isFalse);
      expect(comment.isChord, isTrue);
    });
  });

  // ── Chord state machine ────────────────────────────────

  group('Chord state machine', () {
    setUp(() {
      manager.loadBindings([
        ForgeShortcutBinding(action: saveAction, key: ctrlS),
        ForgeShortcutBinding(
          action: toggleCommentAction,
          key: ctrlK,
          chord: ForgeChordKey(firstKey: ctrlK, secondKey: ctrlC),
        ),
        ForgeShortcutBinding(
          action: blockCommentAction,
          key: ctrlK,
          chord: ForgeChordKey(firstKey: ctrlK, secondKey: ctrlA),
        ),
      ]);
    });

    test('first key press enters chord mode', () {
      expect(manager.isChordPending, isFalse);
      final result = manager.handleKeyForChord(ctrlK);
      expect(result, isNull);
      expect(manager.isChordPending, isTrue);
      expect(manager.pendingChordFirstKey, ctrlK);
    });

    test('pendingChordCompletions lists available second keys', () {
      manager.handleKeyForChord(ctrlK);
      final completions = manager.pendingChordCompletions;
      expect(completions, hasLength(2));
      expect(
        completions.map((b) => b.chord!.secondKey),
        containsAll([ctrlC, ctrlA]),
      );
    });

    test('matching second key completes chord and returns binding', () {
      manager.handleKeyForChord(ctrlK);
      final result = manager.handleKeyForChord(ctrlC);
      expect(result, isNotNull);
      expect(result!.action.id, 'edit.toggleComment');
      expect(manager.isChordPending, isFalse);
    });

    test('non-matching second key cancels chord', () {
      manager.handleKeyForChord(ctrlK);
      final result = manager.handleKeyForChord(ctrlS);
      expect(result, isNull);
      expect(manager.isChordPending, isFalse);
    });

    test('cancelChord resets pending state', () {
      manager.handleKeyForChord(ctrlK);
      expect(manager.isChordPending, isTrue);
      manager.cancelChord();
      expect(manager.isChordPending, isFalse);
      expect(manager.pendingChordFirstKey, isNull);
    });

    test('non-chord key does not enter chord mode', () {
      final result = manager.handleKeyForChord(ctrlS);
      expect(result, isNull);
      expect(manager.isChordPending, isFalse);
    });

    test('chord auto-cancels after timeout', () async {
      manager.handleKeyForChord(ctrlK);
      expect(manager.isChordPending, isTrue);

      // Wait longer than the chord timeout (2 seconds).
      await Future<void>.delayed(
        DefaultShortcutManager.chordTimeout + const Duration(milliseconds: 100),
      );
      expect(manager.isChordPending, isFalse);
    });
  });

  // ── Chord event stream ─────────────────────────────────

  group('Chord event stream', () {
    setUp(() {
      manager.loadBindings([
        ForgeShortcutBinding(
          action: toggleCommentAction,
          key: ctrlK,
          chord: ForgeChordKey(firstKey: ctrlK, secondKey: ctrlC),
        ),
      ]);
    });

    test('emits entered event on first key', () async {
      final events = <ForgeChordEvent>[];
      final sub = manager.onChordStateChanged.listen(events.add);

      manager.handleKeyForChord(ctrlK);
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.state, ForgeChordState.entered);
      expect(events.first.firstKey, ctrlK);
      expect(events.first.completions, hasLength(1));

      await sub.cancel();
    });

    test('emits completed event on matching second key', () async {
      final events = <ForgeChordEvent>[];
      final sub = manager.onChordStateChanged.listen(events.add);

      manager.handleKeyForChord(ctrlK);
      manager.handleKeyForChord(ctrlC);
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(2));
      expect(events[0].state, ForgeChordState.entered);
      expect(events[1].state, ForgeChordState.completed);
      expect(events[1].executedBinding!.action.id, 'edit.toggleComment');

      await sub.cancel();
    });

    test('emits cancelled event on non-matching second key', () async {
      final events = <ForgeChordEvent>[];
      final sub = manager.onChordStateChanged.listen(events.add);

      manager.handleKeyForChord(ctrlK);
      manager.handleKeyForChord(ctrlS);
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(2));
      expect(events[0].state, ForgeChordState.entered);
      expect(events[1].state, ForgeChordState.cancelled);

      await sub.cancel();
    });

    test('emits cancelled event on explicit cancel', () async {
      final events = <ForgeChordEvent>[];
      final sub = manager.onChordStateChanged.listen(events.add);

      manager.handleKeyForChord(ctrlK);
      manager.cancelChord();
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(2));
      expect(events[1].state, ForgeChordState.cancelled);

      await sub.cancel();
    });
  });

  // ── Display strings ────────────────────────────────────

  group('Display strings', () {
    test('ForgeShortcutKey toDisplayString returns readable label', () {
      final key = const ForgeShortcutKey(
        key: LogicalKeyboardKey.keyS,
        primaryModifier: true,
      );
      final display = key.toDisplayString();
      // Platform-dependent: "Ctrl+S" on Linux/Windows, "⌘S" on macOS.
      expect(display, contains('S'));
    });

    test('ForgeShortcutBinding displayString for simple binding', () {
      final binding = ForgeShortcutBinding(action: saveAction, key: ctrlS);
      expect(binding.displayString, ctrlS.toDisplayString());
    });

    test('ForgeShortcutBinding displayString for chord binding', () {
      final binding = ForgeShortcutBinding(
        action: toggleCommentAction,
        key: ctrlK,
        chord: ForgeChordKey(firstKey: ctrlK, secondKey: ctrlC),
      );
      final display = binding.displayString;
      expect(display, contains(ctrlK.toDisplayString()));
      expect(display, contains(ctrlC.toDisplayString()));
    });
  });
}

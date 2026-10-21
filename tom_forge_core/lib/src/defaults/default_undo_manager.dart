import 'dart:async';

import '../services/forge_undo_manager.dart';
import '../types/forge_listenable.dart';
import 'undo_stack.dart';

/// An undo entry with forward and backward operations.
///
/// The optional [data] field carries serializable metadata (e.g. text ranges,
/// old/new content) for persistence via `.forge/undo/`. Callbacks cannot be
/// serialized, but [data] can.
class UndoEntry {
  final Future<void> Function() undo;
  final Future<void> Function() redo;
  final String? label;

  /// Optional serializable metadata for persistence.
  ///
  /// When non-null, workspace state managers can persist and restore undo
  /// history using this data. The map should follow the undo-stack schema
  /// defined in the spec (§6.3).
  final Map<String, dynamic>? data;

  const UndoEntry({
    required this.undo,
    required this.redo,
    this.label,
    this.data,
  });
}

/// A composite undo entry that groups multiple entries into one atomic step.
///
/// When undone, all entries are undone in reverse order.
/// When redone, all entries are redone in forward order.
///
/// **Atomic on failure as well as on success.** If an entry's application
/// throws part-way, the entries already applied in this pass are put back
/// (each one's opposite operation, in reverse), and the error is rethrown.
/// Without that a step of N entries whose k-th undo fails would be left with
/// N−k entries undone and k not — and, because [DefaultUndoManager] keeps the
/// entry, the next undo would apply the whole step again and *redo* the ones
/// that had succeeded. An entry's operations are expected to be each other's
/// inverse, which is what makes the put-back correct.
class CompositeUndoEntry extends UndoEntry {
  final List<UndoEntry> entries;

  CompositeUndoEntry({
    required this.entries,
    super.label,
  }) : super(
          undo: () => forgeApplyAllAsync<UndoEntry>(
            entries.reversed,
            (e) => e.undo(),
            (e) => e.redo(),
          ),
          redo: () => forgeApplyAllAsync<UndoEntry>(
            entries,
            (e) => e.redo(),
            (e) => e.undo(),
          ),
        );
}

/// Default implementation of [ForgeUndoManager].
///
/// A [ForgeUndoStack] of [UndoEntry] with composite grouping via
/// [beginUndoGroup]/[endUndoGroup].
///
/// Memory budget: max [maxEntries] entries per stack (spec §4.1: 100).
///
/// **An entry whose application throws stays where it was** — the stack's
/// guarantee: if the operation throws, the entry is still on the stack it was
/// taken from, no event is emitted, and the error propagates to the caller,
/// which is the one place that can say what happened.
class DefaultUndoManager implements ForgeUndoManager {
  static bool debugEnabled = false;

  /// Maximum number of undo entries to keep (spec §4.1).
  final int maxEntries;

  final ForgeUndoStack<UndoEntry> _stack;
  final _canUndo = ForgeValueNotifier<bool>(false);
  final _canRedo = ForgeValueNotifier<bool>(false);
  final _eventController = StreamController<UndoEvent>.broadcast();

  /// Active group nesting depth. 0 = no active group.
  int _groupDepth = 0;

  /// Label for the current outermost group.
  String? _groupLabel;

  /// Entries collected during the current outermost group.
  final List<UndoEntry> _groupEntries = [];

  DefaultUndoManager({this.maxEntries = 100})
    : _stack = ForgeUndoStack<UndoEntry>(maxEntries: maxEntries);

  @override
  Future<void> undo() async {
    final entry = await _stack.undoAsync((e) => e.undo());
    if (entry == null) return;
    _updateState();
    _eventController.add(UndoEvent(type: UndoEventType.undone, label: entry.label));
  }

  @override
  Future<void> redo() async {
    final entry = await _stack.redoAsync((e) => e.redo());
    if (entry == null) return;
    _updateState();
    _eventController.add(UndoEvent(type: UndoEventType.redone, label: entry.label));
  }

  @override
  ForgeValueListenable<bool> get canUndo => _canUndo;

  @override
  ForgeValueListenable<bool> get canRedo => _canRedo;

  @override
  int get undoCount => _stack.undoCount;

  /// The label of the entry [undo] would apply, or null when there is none.
  ///
  /// Read after a failed [undo] it names the entry that failed, since the
  /// entry is still on the stack.
  String? get nextUndoLabel => _stack.nextUndo?.label;

  /// The label of the entry [redo] would apply, or null when there is none.
  String? get nextRedoLabel => _stack.nextRedo?.label;

  @override
  int get redoCount => _stack.redoCount;

  @override
  Stream<UndoEvent> get onUndoEvent => _eventController.stream;

  @override
  void beginUndoGroup({String? label}) {
    if (_groupDepth == 0) {
      _groupLabel = label;
      _groupEntries.clear();
    }
    _groupDepth++;
    if (debugEnabled) {
      // ignore: avoid_print
      print('[DefaultUndoManager] beginUndoGroup depth=$_groupDepth label=${label ?? _groupLabel ?? "unnamed"}');
    }
  }

  @override
  void endUndoGroup() {
    if (_groupDepth <= 0) return;
    _groupDepth--;
    if (_groupDepth == 0 && _groupEntries.isNotEmpty) {
      final composite = CompositeUndoEntry(
        entries: List.of(_groupEntries),
        label: _groupLabel,
      );
      _groupEntries.clear();
      _groupLabel = null;
      _pushInternal(composite);
      if (debugEnabled) {
        // ignore: avoid_print
        print('[DefaultUndoManager] endUndoGroup committed ${composite.entries.length} entries');
      }
    } else if (_groupDepth == 0) {
      _groupEntries.clear();
      _groupLabel = null;
    }
  }

  /// Push an undo entry onto the stack.
  ///
  /// If inside a [beginUndoGroup]/[endUndoGroup] block, the entry is collected
  /// into the group instead of being pushed directly.
  void push(UndoEntry entry) {
    if (_groupDepth > 0) {
      _groupEntries.add(entry);
      if (debugEnabled) {
        // ignore: avoid_print
        print('[DefaultUndoManager] collected in group: ${entry.label ?? "unnamed"}');
      }
      return;
    }
    _pushInternal(entry);
  }

  void _pushInternal(UndoEntry entry) {
    _stack.push(entry);
    _updateState();
    _eventController.add(UndoEvent(type: UndoEventType.pushed, label: entry.label));
    if (debugEnabled) {
      // ignore: avoid_print
      print('[DefaultUndoManager] pushed: ${entry.label ?? "unnamed"}');
    }
  }

  /// Clear all undo/redo history.
  void clear() {
    _stack.clear();
    _groupDepth = 0;
    _groupEntries.clear();
    _groupLabel = null;
    _updateState();
    _eventController.add(const UndoEvent(type: UndoEventType.cleared));
  }

  void _updateState() {
    _canUndo.value = _stack.canUndo;
    _canRedo.value = _stack.canRedo;
  }

  /// Dispose resources.
  void dispose() {
    _canUndo.dispose();
    _canRedo.dispose();
    _eventController.close();
  }
}

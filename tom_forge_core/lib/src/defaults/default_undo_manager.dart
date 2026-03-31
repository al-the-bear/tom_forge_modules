import 'dart:async';

import 'package:tom_forge_core/tom_forge_core.dart';

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
class CompositeUndoEntry extends UndoEntry {
  final List<UndoEntry> entries;

  CompositeUndoEntry({
    required this.entries,
    super.label,
  }) : super(
          undo: () async {
            for (var i = entries.length - 1; i >= 0; i--) {
              await entries[i].undo();
            }
          },
          redo: () async {
            for (final entry in entries) {
              await entry.redo();
            }
          },
        );
}

/// Default implementation of [ForgeUndoManager].
///
/// Maintains simple undo/redo stacks of [UndoEntry] with support for
/// composite grouping via [beginUndoGroup]/[endUndoGroup].
///
/// Memory budget: max [maxEntries] entries per stack (spec §4.1: 100).
class DefaultUndoManager implements ForgeUndoManager {
  static bool debugEnabled = false;

  /// Maximum number of undo entries to keep (spec §4.1).
  final int maxEntries;

  final List<UndoEntry> _undoStack = [];
  final List<UndoEntry> _redoStack = [];
  final _canUndo = ForgeValueNotifier<bool>(false);
  final _canRedo = ForgeValueNotifier<bool>(false);
  final _eventController = StreamController<UndoEvent>.broadcast();

  /// Active group nesting depth. 0 = no active group.
  int _groupDepth = 0;

  /// Label for the current outermost group.
  String? _groupLabel;

  /// Entries collected during the current outermost group.
  final List<UndoEntry> _groupEntries = [];

  DefaultUndoManager({this.maxEntries = 100});

  @override
  Future<void> undo() async {
    if (_undoStack.isEmpty) return;
    final entry = _undoStack.removeLast();
    await entry.undo();
    _redoStack.add(entry);
    _updateState();
    _eventController.add(UndoEvent(type: UndoEventType.undone, label: entry.label));
  }

  @override
  Future<void> redo() async {
    if (_redoStack.isEmpty) return;
    final entry = _redoStack.removeLast();
    await entry.redo();
    _undoStack.add(entry);
    _updateState();
    _eventController.add(UndoEvent(type: UndoEventType.redone, label: entry.label));
  }

  @override
  ForgeValueListenable<bool> get canUndo => _canUndo;

  @override
  ForgeValueListenable<bool> get canRedo => _canRedo;

  @override
  int get undoCount => _undoStack.length;

  @override
  int get redoCount => _redoStack.length;

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
    _undoStack.add(entry);
    _redoStack.clear();
    // Enforce memory budget (spec §4.1: 100 entries).
    while (_undoStack.length > maxEntries) {
      _undoStack.removeAt(0);
    }
    _updateState();
    _eventController.add(UndoEvent(type: UndoEventType.pushed, label: entry.label));
    if (debugEnabled) {
      // ignore: avoid_print
      print('[DefaultUndoManager] pushed: ${entry.label ?? "unnamed"}');
    }
  }

  /// Clear all undo/redo history.
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    _groupDepth = 0;
    _groupEntries.clear();
    _groupLabel = null;
    _updateState();
    _eventController.add(const UndoEvent(type: UndoEventType.cleared));
  }

  void _updateState() {
    _canUndo.value = _undoStack.isNotEmpty;
    _canRedo.value = _redoStack.isNotEmpty;
  }

  /// Dispose resources.
  void dispose() {
    _canUndo.dispose();
    _canRedo.dispose();
    _eventController.close();
  }
}

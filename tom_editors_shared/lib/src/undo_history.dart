/// Generic typed undo/redo history with configurable depth.
///
/// Each entry stores both old and new state, enabling forward and backward
/// traversal. The redo stack is cleared whenever a new entry is pushed
/// after an undo.
///
/// ```dart
/// final history = UndoHistory<String>(maxDepth: 50);
///
/// history.push(UndoEntry(oldState: 'a', newState: 'b'));
/// history.push(UndoEntry(oldState: 'b', newState: 'c'));
///
/// var entry = history.undo(); // entry.oldState == 'b'
/// var redo  = history.redo(); // redo.newState == 'c'
/// ```
class UndoHistory<T> {
  final List<UndoEntry<T>> _undoStack = [];
  final List<UndoEntry<T>> _redoStack = [];

  /// Maximum number of undo entries to keep.
  final int maxDepth;

  /// Creates an undo history with the given [maxDepth].
  UndoHistory({this.maxDepth = 100});

  /// Whether an undo operation is available.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether a redo operation is available.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Number of entries in the undo stack.
  int get undoCount => _undoStack.length;

  /// Number of entries in the redo stack.
  int get redoCount => _redoStack.length;

  /// Push a new entry onto the undo stack.
  ///
  /// Clears the redo stack (any "future" edits after an undo are discarded).
  void push(UndoEntry<T> entry) {
    _undoStack.add(entry);
    if (_undoStack.length > maxDepth) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  /// Undo the last operation.
  ///
  /// Moves the top entry from the undo stack to the redo stack and returns it.
  /// Returns `null` if [canUndo] is false.
  UndoEntry<T>? undo() {
    if (!canUndo) return null;
    var entry = _undoStack.removeLast();
    _redoStack.add(entry);
    return entry;
  }

  /// Redo the last undone operation.
  ///
  /// Moves the top entry from the redo stack back to the undo stack
  /// and returns it. Returns `null` if [canRedo] is false.
  UndoEntry<T>? redo() {
    if (!canRedo) return null;
    var entry = _redoStack.removeLast();
    _undoStack.add(entry);
    return entry;
  }

  /// Clear both undo and redo stacks.
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}

/// A single entry in the [UndoHistory] stack.
///
/// Stores both the state before and after the change, allowing traversal
/// in either direction.
class UndoEntry<T> {
  /// The state before this change.
  final T oldState;

  /// The state after this change.
  final T newState;

  /// Optional human-readable description of the change.
  final String? description;

  /// When this change was made.
  final DateTime timestamp;

  /// Creates an undo entry recording a state transition.
  UndoEntry({
    required this.oldState,
    required this.newState,
    this.description,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

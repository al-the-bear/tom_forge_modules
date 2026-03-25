import 'package:tom_forge_core/tom_forge_core.dart';

/// An undo entry with forward and backward operations.
class UndoEntry {
  final Future<void> Function() undo;
  final Future<void> Function() redo;
  final String? label;

  const UndoEntry({
    required this.undo,
    required this.redo,
    this.label,
  });
}

/// Default implementation of [ForgeUndoManager].
///
/// Maintains simple undo/redo stacks of [UndoEntry].
class DefaultUndoManager implements ForgeUndoManager {
  static bool debugEnabled = false;

  final List<UndoEntry> _undoStack = [];
  final List<UndoEntry> _redoStack = [];
  final _canUndo = ForgeValueNotifier<bool>(false);
  final _canRedo = ForgeValueNotifier<bool>(false);

  @override
  Future<void> undo() async {
    if (_undoStack.isEmpty) return;
    final entry = _undoStack.removeLast();
    await entry.undo();
    _redoStack.add(entry);
    _updateState();
  }

  @override
  Future<void> redo() async {
    if (_redoStack.isEmpty) return;
    final entry = _redoStack.removeLast();
    await entry.redo();
    _undoStack.add(entry);
    _updateState();
  }

  @override
  ForgeValueListenable<bool> get canUndo => _canUndo;

  @override
  ForgeValueListenable<bool> get canRedo => _canRedo;

  /// Push an undo entry onto the stack.
  void push(UndoEntry entry) {
    _undoStack.add(entry);
    _redoStack.clear();
    _updateState();
    if (debugEnabled) {
      // ignore: avoid_print
      print('[DefaultUndoManager] pushed: ${entry.label ?? "unnamed"}');
    }
  }

  /// Clear all undo/redo history.
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    _updateState();
  }

  void _updateState() {
    _canUndo.value = _undoStack.isNotEmpty;
    _canRedo.value = _redoStack.isNotEmpty;
  }

  /// Dispose resources.
  void dispose() {
    _canUndo.dispose();
    _canRedo.dispose();
  }
}

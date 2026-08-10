import 'dart:async';

import '../types/forge_listenable.dart';

/// Undo/redo management for shell-level actions.
///
/// Supports individual undo entries and composite grouping via
/// [beginUndoGroup]/[endUndoGroup] for multi-operation atomicity.
abstract class ForgeUndoManager {
  /// Undo the last undoable action (or composite group).
  Future<void> undo();

  /// Redo the last undone action (or composite group).
  Future<void> redo();

  /// Whether undo is available.
  ForgeValueListenable<bool> get canUndo;

  /// Whether redo is available.
  ForgeValueListenable<bool> get canRedo;

  /// Number of entries in the undo stack.
  int get undoCount;

  /// Number of entries in the redo stack.
  int get redoCount;

  /// Begin a composite undo group.
  ///
  /// All entries pushed between [beginUndoGroup] and [endUndoGroup] are
  /// collected into a single composite entry that undoes/redoes atomically.
  /// Groups can be nested; only the outermost [endUndoGroup] commits.
  void beginUndoGroup({String? label});

  /// End the current composite undo group.
  ///
  /// If this closes the outermost group, the collected entries are
  /// committed as a single composite [UndoEntry].
  void endUndoGroup();

  /// Stream of undo events for external listeners (e.g. persistence).
  Stream<UndoEvent> get onUndoEvent;
}

/// Events emitted by [ForgeUndoManager] for persistence and observation.
enum UndoEventType { pushed, undone, redone, cleared }

/// An undo event with the action type and optional entry metadata.
class UndoEvent {
  final UndoEventType type;
  final String? label;
  const UndoEvent({required this.type, this.label});
}

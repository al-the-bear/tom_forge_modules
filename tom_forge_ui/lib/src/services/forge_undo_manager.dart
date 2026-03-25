import 'package:flutter/foundation.dart';

/// Undo/redo management for shell-level actions.
abstract class ForgeUndoManager {
  Future<void> undo();
  Future<void> redo();
  ValueListenable<bool> get canUndo;
  ValueListenable<bool> get canRedo;
}

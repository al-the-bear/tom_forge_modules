import 'package:tom_forge_core/tom_forge_core.dart';

/// Undo/redo management for shell-level actions.
abstract class ForgeUndoManager {
  Future<void> undo();
  Future<void> redo();
  ForgeValueListenable<bool> get canUndo;
  ForgeValueListenable<bool> get canRedo;
}

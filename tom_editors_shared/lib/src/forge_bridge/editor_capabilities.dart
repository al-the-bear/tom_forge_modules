/// Structured capabilities for the shell to query editor features
/// without knowing specific action IDs.
///
/// This is a static description of what operations an editor supports.
/// It does NOT change based on editor state — use [EditorStateSnapshot]
/// for dynamic state queries.
class EditorCapabilities {
  /// Editor has a text buffer (as opposed to a pure tree/form editor).
  final bool hasTextBuffer;

  /// Editor supports undo/redo.
  final bool supportsUndoRedo;

  /// Editor supports clipboard operations (cut/copy/paste).
  final bool supportsClipboard;

  /// Editor supports line-level operations (delete, duplicate, move, comment).
  final bool supportsLineEditing;

  /// Editor supports text selection.
  final bool supportsSelection;

  /// Editor content is currently read-only.
  final bool isReadOnly;

  const EditorCapabilities({
    this.hasTextBuffer = true,
    this.supportsUndoRedo = true,
    this.supportsClipboard = true,
    this.supportsLineEditing = true,
    this.supportsSelection = true,
    this.isReadOnly = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditorCapabilities &&
          hasTextBuffer == other.hasTextBuffer &&
          supportsUndoRedo == other.supportsUndoRedo &&
          supportsClipboard == other.supportsClipboard &&
          supportsLineEditing == other.supportsLineEditing &&
          supportsSelection == other.supportsSelection &&
          isReadOnly == other.isReadOnly;

  @override
  int get hashCode => Object.hash(
        hasTextBuffer,
        supportsUndoRedo,
        supportsClipboard,
        supportsLineEditing,
        supportsSelection,
        isReadOnly,
      );

  @override
  String toString() => 'EditorCapabilities('
      'hasTextBuffer: $hasTextBuffer, '
      'supportsUndoRedo: $supportsUndoRedo, '
      'supportsClipboard: $supportsClipboard, '
      'supportsLineEditing: $supportsLineEditing, '
      'supportsSelection: $supportsSelection, '
      'isReadOnly: $isReadOnly)';
}

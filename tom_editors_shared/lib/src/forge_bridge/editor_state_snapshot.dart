/// Immutable snapshot of the editor's current state, relevant to
/// action enablement decisions.
///
/// Editors update this snapshot on every relevant state change and
/// notify the shell. The shell reads the snapshot to evaluate
/// isEnabled — never by calling into the editor's internals.
class EditorStateSnapshot {
  /// True when the editor has a non-collapsed text selection.
  final bool hasSelection;

  /// True when the editor has non-empty text content.
  final bool hasContent;

  /// True when content is editable (not read-only).
  final bool isEditable;

  /// True when undo is available.
  final bool canUndo;

  /// True when redo is available.
  final bool canRedo;

  /// True when the editor has focus.
  final bool hasFocus;

  /// True when the editor is in a text-editing mode (as opposed to
  /// tree/form mode). Affects whether line-editing actions are available.
  final bool isTextMode;

  const EditorStateSnapshot({
    this.hasSelection = false,
    this.hasContent = false,
    this.isEditable = true,
    this.canUndo = false,
    this.canRedo = false,
    this.hasFocus = false,
    this.isTextMode = true,
  });

  /// Returns a copy with the given fields replaced.
  EditorStateSnapshot copyWith({
    bool? hasSelection,
    bool? hasContent,
    bool? isEditable,
    bool? canUndo,
    bool? canRedo,
    bool? hasFocus,
    bool? isTextMode,
  }) {
    return EditorStateSnapshot(
      hasSelection: hasSelection ?? this.hasSelection,
      hasContent: hasContent ?? this.hasContent,
      isEditable: isEditable ?? this.isEditable,
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      hasFocus: hasFocus ?? this.hasFocus,
      isTextMode: isTextMode ?? this.isTextMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditorStateSnapshot &&
          hasSelection == other.hasSelection &&
          hasContent == other.hasContent &&
          isEditable == other.isEditable &&
          canUndo == other.canUndo &&
          canRedo == other.canRedo &&
          hasFocus == other.hasFocus &&
          isTextMode == other.isTextMode;

  @override
  int get hashCode => Object.hash(
        hasSelection,
        hasContent,
        isEditable,
        canUndo,
        canRedo,
        hasFocus,
        isTextMode,
      );

  @override
  String toString() => 'EditorStateSnapshot('
      'hasSelection: $hasSelection, '
      'hasContent: $hasContent, '
      'isEditable: $isEditable, '
      'canUndo: $canUndo, '
      'canRedo: $canRedo, '
      'hasFocus: $hasFocus, '
      'isTextMode: $isTextMode)';
}

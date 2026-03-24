/// Word wrap modes for text editors.
enum ForgeWordWrap {
  /// No wrapping — lines extend beyond the viewport.
  off,

  /// Wrap at viewport boundary.
  on,

  /// Wrap at a configured column.
  wordWrapColumn,

  /// Wrap at the minimum of viewport boundary and column.
  bounded,
}

/// Per-editor text options that override global defaults.
class ForgeTextEditorOptions {
  /// Number of spaces per tab. Null = use global default.
  final int? tabSize;

  /// Whether to insert spaces instead of tab characters.
  final bool? insertSpaces;

  /// Word wrap mode.
  final ForgeWordWrap? wordWrap;

  const ForgeTextEditorOptions({this.tabSize, this.insertSpaces, this.wordWrap});

  /// Creates a copy with updated fields.
  ForgeTextEditorOptions copyWith({
    int? tabSize,
    bool? insertSpaces,
    ForgeWordWrap? wordWrap,
  }) {
    return ForgeTextEditorOptions(
      tabSize: tabSize ?? this.tabSize,
      insertSpaces: insertSpaces ?? this.insertSpaces,
      wordWrap: wordWrap ?? this.wordWrap,
    );
  }
}

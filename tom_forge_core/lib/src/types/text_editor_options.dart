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
///
/// These options can be applied at runtime to control both formatting behavior
/// and visual display. Null values inherit from global/theme defaults.
class ForgeTextEditorOptions {
  /// Number of spaces per tab. Null = use global default.
  final int? tabSize;

  /// Whether to insert spaces instead of tab characters.
  final bool? insertSpaces;

  /// Word wrap mode.
  final ForgeWordWrap? wordWrap;

  /// Font family for code content.
  final String? fontFamily;

  /// Base font size in logical pixels.
  final double? fontSize;

  /// Line height multiplier.
  final double? lineHeight;

  /// Whether to show line numbers in the gutter.
  final bool? showLineNumbers;

  /// Whether to highlight the current line.
  final bool? highlightCurrentLine;

  const ForgeTextEditorOptions({
    this.tabSize,
    this.insertSpaces,
    this.wordWrap,
    this.fontFamily,
    this.fontSize,
    this.lineHeight,
    this.showLineNumbers,
    this.highlightCurrentLine,
  });

  /// Creates a copy with updated fields.
  ForgeTextEditorOptions copyWith({
    int? tabSize,
    bool? insertSpaces,
    ForgeWordWrap? wordWrap,
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    bool? showLineNumbers,
    bool? highlightCurrentLine,
  }) {
    return ForgeTextEditorOptions(
      tabSize: tabSize ?? this.tabSize,
      insertSpaces: insertSpaces ?? this.insertSpaces,
      wordWrap: wordWrap ?? this.wordWrap,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      showLineNumbers: showLineNumbers ?? this.showLineNumbers,
      highlightCurrentLine: highlightCurrentLine ?? this.highlightCurrentLine,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ForgeTextEditorOptions &&
          tabSize == other.tabSize &&
          insertSpaces == other.insertSpaces &&
          wordWrap == other.wordWrap &&
          fontFamily == other.fontFamily &&
          fontSize == other.fontSize &&
          lineHeight == other.lineHeight &&
          showLineNumbers == other.showLineNumbers &&
          highlightCurrentLine == other.highlightCurrentLine;

  @override
  int get hashCode => Object.hash(
        tabSize,
        insertSpaces,
        wordWrap,
        fontFamily,
        fontSize,
        lineHeight,
        showLineNumbers,
        highlightCurrentLine,
      );
}

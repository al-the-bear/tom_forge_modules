import 'package:flutter/foundation.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import 'forge_editor.dart';

/// An editor that takes the shell's text options (tab size, font, word
/// wrap, ...): every [ForgeTextEditor], and editors that are not text
/// editors but show text, such as the YAML editor's source view.
abstract interface class ForgeTextOptionsReceiver {
  /// Update per-editor options.
  void updateOptions(ForgeTextEditorOptions options);
}

/// A text-based editor with document, cursor, selection, and decoration APIs.
abstract class ForgeTextEditor extends ForgeEditor
    implements ForgeTextOptionsReceiver {
  /// The document model backing this editor.
  ForgeDocument get document;

  /// The current cursor position (line, column).
  ValueListenable<ForgeTextPosition> get cursorPosition;

  /// The current text selection range. Null when no selection.
  ValueListenable<ForgeTextRange?> get selection;

  /// All current selections (for multi-cursor editing).
  ValueListenable<List<ForgeTextRange>> get selections;

  /// Set multiple selections (multi-cursor).
  void setSelections(List<ForgeTextRange> ranges);

  /// The currently selected text content. Empty string when no selection.
  String get selectedText;

  /// Whether there is a non-empty text selection.
  bool get hasSelection;

  /// The currently visible text range.
  ValueListenable<ForgeTextRange> get visibleRange;

  /// Replace the current selection with the given text.
  void insertText(String text);

  /// Replace text in the given range.
  void replaceRange(ForgeTextRange range, String replacement);

  /// Delete text in the given range.
  void deleteRange(ForgeTextRange range);

  /// Set the cursor position.
  void setCursorPosition(ForgeTextPosition position);

  /// Set the selection range.
  void setSelection(ForgeTextRange range);

  /// Select all text.
  void selectAll();

  /// Reveal the given position by scrolling to it.
  void revealPosition(ForgeTextPosition position);

  /// Reveal the given range by scrolling to make it visible.
  void revealRange(ForgeTextRange range);

  /// Find occurrences of a pattern in the document.
  List<ForgeTextRange> findAll(Pattern pattern);

  /// Replace all occurrences of a pattern.
  int replaceAll(Pattern pattern, String replacement);

  /// Per-editor options (tab size, insert spaces, word wrap).
  ForgeTextEditorOptions get options;

  /// Update per-editor options.
  @override
  void updateOptions(ForgeTextEditorOptions options);

  /// Apply decorations to ranges in this editor.
  void setDecorations(
      ForgeDecorationType type, List<ForgeDecorationRange> ranges);

  /// Remove all decorations of the given type.
  void clearDecorations(ForgeDecorationType type);
}

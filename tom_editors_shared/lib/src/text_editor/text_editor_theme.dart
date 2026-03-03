import 'package:flutter/material.dart';

/// Visual theme for the [TextEditorCore] widget.
class TextEditorTheme {
  /// Background color of the text editor area.
  final Color background;

  /// Default text style for code.
  final TextStyle textStyle;

  /// Text style for line numbers in the gutter.
  final TextStyle lineNumberStyle;

  /// Background color of the gutter (line number area).
  final Color gutterBackground;

  /// Color of the current-line highlight.
  final Color currentLineHighlight;

  /// Border color between gutter and text area.
  final Color gutterBorderColor;

  /// Width of the gutter in logical pixels.
  final double gutterWidth;

  /// Whether to show line numbers.
  final bool showLineNumbers;

  /// Whether to show the current-line highlight.
  final bool showCurrentLineHighlight;

  /// Padding inside the text editing area.
  final EdgeInsets contentPadding;

  const TextEditorTheme({
    this.background = const Color(0xFF1E1E1E),
    this.textStyle = const TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      color: Color(0xFFD4D4D4),
      height: 1.4,
    ),
    this.lineNumberStyle = const TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      color: Color(0xFF858585),
      height: 1.4,
    ),
    this.gutterBackground = const Color(0xFF1E1E1E),
    this.currentLineHighlight = const Color(0x15FFFFFF),
    this.gutterBorderColor = const Color(0xFF404040),
    this.gutterWidth = 48.0,
    this.showLineNumbers = true,
    this.showCurrentLineHighlight = true,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 8,
    ),
  });

  /// Returns a copy of this theme with the given fields replaced.
  TextEditorTheme copyWith({
    Color? background,
    TextStyle? textStyle,
    TextStyle? lineNumberStyle,
    Color? gutterBackground,
    Color? currentLineHighlight,
    Color? gutterBorderColor,
    double? gutterWidth,
    bool? showLineNumbers,
    bool? showCurrentLineHighlight,
    EdgeInsets? contentPadding,
  }) {
    return TextEditorTheme(
      background: background ?? this.background,
      textStyle: textStyle ?? this.textStyle,
      lineNumberStyle: lineNumberStyle ?? this.lineNumberStyle,
      gutterBackground: gutterBackground ?? this.gutterBackground,
      currentLineHighlight: currentLineHighlight ?? this.currentLineHighlight,
      gutterBorderColor: gutterBorderColor ?? this.gutterBorderColor,
      gutterWidth: gutterWidth ?? this.gutterWidth,
      showLineNumbers: showLineNumbers ?? this.showLineNumbers,
      showCurrentLineHighlight:
          showCurrentLineHighlight ?? this.showCurrentLineHighlight,
      contentPadding: contentPadding ?? this.contentPadding,
    );
  }
}

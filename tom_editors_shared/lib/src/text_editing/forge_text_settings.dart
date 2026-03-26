import 'package:flutter/widgets.dart';

/// Whether debug logging is enabled for forge_text_settings operations.
bool kForgeTextSettingsDebug = false;

void _log(String message) {
  if (kForgeTextSettingsDebug) {
    // ignore: avoid_print
    print('[ForgeTextSettings] $message');
  }
}

/// Default font settings constants.
abstract class ForgeTextDefaults {
  /// Default monospace font family.
  static const String defaultFontFamily = 'monospace';

  /// Default font size in logical pixels.
  static const double defaultFontSize = 14.0;

  /// Default line height multiplier.
  static const double defaultLineHeight = 1.4;

  /// Default tab size in spaces.
  static const int defaultTabSize = 2;

  /// Default max undo history depth.
  static const int defaultMaxUndoHistory = 100;
}

/// Unified text editor display settings.
///
/// Consolidates font and display settings from all editors into a single
/// configuration class. Can be used for default settings shared across
/// all editors, or customized per-editor.
///
/// ```dart
/// // Use defaults
/// const settings = ForgeTextSettings();
///
/// // Customize for Dart editor
/// const dartSettings = ForgeTextSettings(
///   fontFamily: 'JetBrains Mono',
///   fontSize: 13.0,
///   tabSize: 2,
///   insertSpaces: true,
/// );
///
/// // Convert to TextStyle
/// final style = settings.toTextStyle(color: Colors.white);
/// ```
class ForgeTextSettings {
  /// Font family for code/text content.
  final String fontFamily;

  /// Secondary font for UI elements (comments, labels).
  final String? uiFontFamily;

  /// Base font size in logical pixels.
  final double fontSize;

  /// Line height multiplier.
  final double lineHeight;

  /// Tab size in spaces.
  final int tabSize;

  /// Whether to insert spaces instead of tabs.
  final bool insertSpaces;

  /// Whether to show whitespace characters.
  final bool showWhitespace;

  /// Whether to enable word wrap.
  final bool wordWrap;

  /// Whether to show line numbers.
  final bool showLineNumbers;

  /// Whether to highlight the current line.
  final bool highlightCurrentLine;

  /// Maximum undo history depth.
  final int maxUndoHistory;

  const ForgeTextSettings({
    this.fontFamily = ForgeTextDefaults.defaultFontFamily,
    this.uiFontFamily,
    this.fontSize = ForgeTextDefaults.defaultFontSize,
    this.lineHeight = ForgeTextDefaults.defaultLineHeight,
    this.tabSize = ForgeTextDefaults.defaultTabSize,
    this.insertSpaces = true,
    this.showWhitespace = false,
    this.wordWrap = true,
    this.showLineNumbers = true,
    this.highlightCurrentLine = true,
    this.maxUndoHistory = ForgeTextDefaults.defaultMaxUndoHistory,
  });

  /// Creates a copy with specified fields replaced.
  ForgeTextSettings copyWith({
    String? fontFamily,
    String? uiFontFamily,
    double? fontSize,
    double? lineHeight,
    int? tabSize,
    bool? insertSpaces,
    bool? showWhitespace,
    bool? wordWrap,
    bool? showLineNumbers,
    bool? highlightCurrentLine,
    int? maxUndoHistory,
  }) {
    _log('copyWith called');
    return ForgeTextSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      uiFontFamily: uiFontFamily ?? this.uiFontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      tabSize: tabSize ?? this.tabSize,
      insertSpaces: insertSpaces ?? this.insertSpaces,
      showWhitespace: showWhitespace ?? this.showWhitespace,
      wordWrap: wordWrap ?? this.wordWrap,
      showLineNumbers: showLineNumbers ?? this.showLineNumbers,
      highlightCurrentLine: highlightCurrentLine ?? this.highlightCurrentLine,
      maxUndoHistory: maxUndoHistory ?? this.maxUndoHistory,
    );
  }

  /// Converts to a [TextStyle] for use in text widgets.
  ///
  /// [color] is required to set the text color, as settings don't
  /// include color (it's part of theming, not settings).
  TextStyle toTextStyle({Color? color}) {
    _log('toTextStyle: fontFamily=$fontFamily, fontSize=$fontSize');
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: lineHeight,
      color: color,
    );
  }

  /// Returns the indent string based on [insertSpaces] and [tabSize].
  String get indentString {
    if (insertSpaces) {
      return ' ' * tabSize;
    }
    return '\t';
  }

  @override
  bool operator ==(Object other) =>
      other is ForgeTextSettings &&
      fontFamily == other.fontFamily &&
      uiFontFamily == other.uiFontFamily &&
      fontSize == other.fontSize &&
      lineHeight == other.lineHeight &&
      tabSize == other.tabSize &&
      insertSpaces == other.insertSpaces &&
      showWhitespace == other.showWhitespace &&
      wordWrap == other.wordWrap &&
      showLineNumbers == other.showLineNumbers &&
      highlightCurrentLine == other.highlightCurrentLine &&
      maxUndoHistory == other.maxUndoHistory;

  @override
  int get hashCode => Object.hash(
        fontFamily,
        uiFontFamily,
        fontSize,
        lineHeight,
        tabSize,
        insertSpaces,
        showWhitespace,
        wordWrap,
        showLineNumbers,
        highlightCurrentLine,
        maxUndoHistory,
      );

  @override
  String toString() => 'ForgeTextSettings('
      'fontFamily=$fontFamily, '
      'fontSize=$fontSize, '
      'tabSize=$tabSize)';
}

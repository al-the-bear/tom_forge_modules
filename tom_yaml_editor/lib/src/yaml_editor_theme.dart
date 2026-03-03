import 'package:flutter/material.dart';

/// Theme configuration for the YAML schema editor.
///
/// Controls all visual aspects: colors, fonts, spacing, and embedded editor
/// styling. Provides dark and light presets, and full customization.
///
/// ```dart
/// // Use a preset
/// YamlEditorTheme.dark()
/// YamlEditorTheme.light()
///
/// // Fully customize
/// YamlEditorTheme(
///   colors: YamlEditorColors(
///     background: Colors.grey[900]!,
///     keyColor: Colors.cyan,
///   ),
/// )
/// ```
class YamlEditorTheme {
  /// Colors for the editor chrome and YAML syntax.
  final YamlEditorColors colors;

  /// Colors for structural indicators (tree lines, collapse icons).
  final YamlStructureColors structureColors;

  /// Font settings for keys, values, and embedded editors.
  final YamlEditorFontSettings fonts;

  /// Style for embedded editor containers.
  final EmbeddedEditorStyle embeddedEditorStyle;

  /// Padding around the editor.
  final EdgeInsets editorPadding;

  /// Indent width per nesting level (in pixels).
  final double indentWidth;

  /// Fixed width for key labels, or null for automatic sizing.
  ///
  /// When null, the editor measures key text per sibling group and sizes
  /// labels to the longest key in each group.
  final double? keyLabelWidth;

  /// Minimum width for auto-sized key labels (used when [keyLabelWidth] is null).
  final double keyLabelMinWidth;

  /// Whether to show tree lines connecting nested keys.
  final bool showTreeLines;

  /// Whether to show collapse/expand toggles for maps and lists.
  final bool showCollapseToggles;

  /// Whether to show schema-based add buttons.
  final bool showAddButtons;

  /// Whether to show remove buttons on optional keys.
  final bool showRemoveButtons;

  /// Whether to show validation indicators inline.
  final bool showInlineValidation;

  const YamlEditorTheme({
    this.colors = const YamlEditorColors(),
    this.structureColors = const YamlStructureColors(),
    this.fonts = const YamlEditorFontSettings(),
    this.embeddedEditorStyle = const EmbeddedEditorStyle(),
    this.editorPadding = const EdgeInsets.all(16),
    this.indentWidth = 24,
    this.keyLabelWidth,
    this.keyLabelMinWidth = 60,
    this.showTreeLines = true,
    this.showCollapseToggles = true,
    this.showAddButtons = true,
    this.showRemoveButtons = true,
    this.showInlineValidation = true,
  });

  /// Dark theme preset.
  factory YamlEditorTheme.dark() => const YamlEditorTheme(
        colors: YamlEditorColors(
          background: Color(0xFF1E1E1E),
          surface: Color(0xFF252526),
          keyColor: Color(0xFF9CDCFE),
          valueColor: Color(0xFFCE9178),
          commentColor: Color(0xFF6A9955),
          numberColor: Color(0xFFB5CEA8),
          boolColor: Color(0xFF569CD6),
          nullColor: Color(0xFF808080),
          separatorColor: Color(0xFFD4D4D4),
          errorColor: Color(0xFFF44747),
          warningColor: Color(0xFFCCA700),
          hintColor: Color(0xFF808080),
          selectionColor: Color(0x40264F78),
          hoverColor: Color(0x1AFFFFFF),
        ),
        structureColors: YamlStructureColors(
          treeLine: Color(0xFF404040),
          collapseIcon: Color(0xFF808080),
          addButton: Color(0xFF569CD6),
          removeButton: Color(0xFFF44747),
          requiredBadge: Color(0xFFCCA700),
        ),
        fonts: YamlEditorFontSettings(
          keyFontFamily: '.SF Mono',
          valueFontFamily: '.SF Mono',
          keyFontSize: 13,
          valueFontSize: 13,
        ),
      );

  /// Light theme preset.
  factory YamlEditorTheme.light() => const YamlEditorTheme(
        colors: YamlEditorColors(
          background: Color(0xFFFFFFFF),
          surface: Color(0xFFF3F3F3),
          keyColor: Color(0xFF001080),
          valueColor: Color(0xFFA31515),
          commentColor: Color(0xFF008000),
          numberColor: Color(0xFF098658),
          boolColor: Color(0xFF0000FF),
          nullColor: Color(0xFF808080),
          separatorColor: Color(0xFF000000),
          errorColor: Color(0xFFE51400),
          warningColor: Color(0xFFBF8803),
          hintColor: Color(0xFFA0A0A0),
          selectionColor: Color(0x40ADD6FF),
          hoverColor: Color(0x0A000000),
        ),
        structureColors: YamlStructureColors(
          treeLine: Color(0xFFD0D0D0),
          collapseIcon: Color(0xFF808080),
          addButton: Color(0xFF0000FF),
          removeButton: Color(0xFFE51400),
          requiredBadge: Color(0xFFBF8803),
        ),
        fonts: YamlEditorFontSettings(
          keyFontFamily: '.SF Mono',
          valueFontFamily: '.SF Mono',
          keyFontSize: 13,
          valueFontSize: 13,
        ),
      );

  /// Create a copy with overrides.
  YamlEditorTheme copyWith({
    YamlEditorColors? colors,
    YamlStructureColors? structureColors,
    YamlEditorFontSettings? fonts,
    EmbeddedEditorStyle? embeddedEditorStyle,
    EdgeInsets? editorPadding,
    double? indentWidth,
    double? keyLabelWidth,
    double? keyLabelMinWidth,
    bool? showTreeLines,
    bool? showCollapseToggles,
    bool? showAddButtons,
    bool? showRemoveButtons,
    bool? showInlineValidation,
  }) {
    return YamlEditorTheme(
      colors: colors ?? this.colors,
      structureColors: structureColors ?? this.structureColors,
      fonts: fonts ?? this.fonts,
      embeddedEditorStyle: embeddedEditorStyle ?? this.embeddedEditorStyle,
      editorPadding: editorPadding ?? this.editorPadding,
      indentWidth: indentWidth ?? this.indentWidth,
      keyLabelWidth: keyLabelWidth ?? this.keyLabelWidth,
      keyLabelMinWidth: keyLabelMinWidth ?? this.keyLabelMinWidth,
      showTreeLines: showTreeLines ?? this.showTreeLines,
      showCollapseToggles: showCollapseToggles ?? this.showCollapseToggles,
      showAddButtons: showAddButtons ?? this.showAddButtons,
      showRemoveButtons: showRemoveButtons ?? this.showRemoveButtons,
      showInlineValidation: showInlineValidation ?? this.showInlineValidation,
    );
  }
}

/// Color scheme for YAML syntax and editor chrome.
class YamlEditorColors {
  /// Background color of the editor canvas.
  final Color background;

  /// Surface color for elevated panels and cards.
  final Color surface;

  /// Color for YAML map keys.
  final Color keyColor;

  /// Color for YAML scalar values (strings).
  final Color valueColor;

  /// Color for YAML comments.
  final Color commentColor;

  /// Color for numeric values.
  final Color numberColor;

  /// Color for boolean values (`true`/`false`).
  final Color boolColor;

  /// Color for `null` values.
  final Color nullColor;

  /// Color for the `:` separator between key and value.
  final Color separatorColor;

  /// Color for validation error indicators.
  final Color errorColor;

  /// Color for validation warning indicators.
  final Color warningColor;

  /// Color for placeholder/hint text.
  final Color hintColor;

  /// Background color for selected nodes.
  final Color selectionColor;

  /// Background color for hovered nodes.
  final Color hoverColor;

  const YamlEditorColors({
    this.background = const Color(0xFF1E1E1E),
    this.surface = const Color(0xFF252526),
    this.keyColor = const Color(0xFF9CDCFE),
    this.valueColor = const Color(0xFFCE9178),
    this.commentColor = const Color(0xFF6A9955),
    this.numberColor = const Color(0xFFB5CEA8),
    this.boolColor = const Color(0xFF569CD6),
    this.nullColor = const Color(0xFF808080),
    this.separatorColor = const Color(0xFFD4D4D4),
    this.errorColor = const Color(0xFFF44747),
    this.warningColor = const Color(0xFFCCA700),
    this.hintColor = const Color(0xFF808080),
    this.selectionColor = const Color(0x40264F78),
    this.hoverColor = const Color(0x1AFFFFFF),
  });
}

/// Colors for structural UI elements (tree lines, buttons).
class YamlStructureColors {
  /// Color of tree indentation guide lines.
  final Color treeLine;

  /// Color of expand/collapse icons on container nodes.
  final Color collapseIcon;

  /// Color of the add-child button.
  final Color addButton;

  /// Color of the remove-node button.
  final Color removeButton;

  /// Color of the "required" field badge.
  final Color requiredBadge;

  const YamlStructureColors({
    this.treeLine = const Color(0xFF404040),
    this.collapseIcon = const Color(0xFF808080),
    this.addButton = const Color(0xFF569CD6),
    this.removeButton = const Color(0xFFF44747),
    this.requiredBadge = const Color(0xFFCCA700),
  });
}

/// Font settings for keys and values.
class YamlEditorFontSettings {
  /// Font family for YAML keys.
  final String keyFontFamily;

  /// Font family for YAML values and code content.
  final String valueFontFamily;

  /// Font size for keys in logical pixels.
  final double keyFontSize;

  /// Font size for values in logical pixels.
  final double valueFontSize;

  /// Font weight for keys (defaults to semi-bold).
  final FontWeight keyFontWeight;

  /// Font weight for values (defaults to normal).
  final FontWeight valueFontWeight;

  /// Line height multiplier for tree rows.
  final double lineHeight;

  const YamlEditorFontSettings({
    this.keyFontFamily = '.SF Mono',
    this.valueFontFamily = '.SF Mono',
    this.keyFontSize = 13,
    this.valueFontSize = 13,
    this.keyFontWeight = FontWeight.w600,
    this.valueFontWeight = FontWeight.normal,
    this.lineHeight = 1.5,
  });
}

/// Styling for embedded editor containers (the box around a Dart editor, etc.).
class EmbeddedEditorStyle {
  /// Inner padding of the embedded editor container.
  final EdgeInsets padding;

  /// Outer margin around the embedded editor container.
  final EdgeInsets margin;

  /// Corner radius for the container border.
  final double borderRadius;

  /// Border width of the container outline.
  final double borderWidth;

  /// Border color (null uses the editor suffix's default).
  final Color? borderColor;

  /// Background fill color (null uses a theme-derived default).
  final Color? backgroundColor;

  /// Minimum height of the editor container.
  final double? minHeight;

  /// Maximum height (null allows unlimited expansion).
  final double? maxHeight;

  const EmbeddedEditorStyle({
    this.padding = const EdgeInsets.all(8),
    this.margin = const EdgeInsets.only(top: 4, bottom: 4),
    this.borderRadius = 6,
    this.borderWidth = 1,
    this.borderColor,
    this.backgroundColor,
    this.minHeight = 80,
    this.maxHeight,
  });
}

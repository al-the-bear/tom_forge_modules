import 'package:tom_forge_core/src/types/text_range.dart';

/// Underline styles for text decorations.
enum ForgeUnderlineStyle { solid, dotted, dashed, wavy }

/// A text decoration type definition — visual markers for error
/// underlines, search highlights, git diff markers, breakpoint icons, etc.
///
/// Each type has a unique [key] so modules can update/clear their
/// own decorations independently.
class ForgeDecorationType {
  /// Unique key for this decoration type (used to update/clear).
  final String key;

  /// Background highlight color for decorated ranges.
  final int? backgroundColorValue;

  /// Underline style (e.g., wavy for errors, dotted for warnings).
  final ForgeUnderlineStyle? underlineStyle;

  /// Underline color as an ARGB integer.
  final int? underlineColorValue;

  /// Whether to render in the overview ruler (scrollbar minimap).
  final bool overviewRuler;

  /// Overview ruler color as an ARGB integer.
  final int? overviewRulerColorValue;

  const ForgeDecorationType({
    required this.key,
    this.backgroundColorValue,
    this.underlineStyle,
    this.underlineColorValue,
    this.overviewRuler = false,
    this.overviewRulerColorValue,
  });
}

/// A range with an optional hover message for a decoration.
class ForgeDecorationRange {
  final ForgeTextRange range;

  /// Optional hover message shown when the cursor is over this range.
  final String? hoverMessage;

  const ForgeDecorationRange({required this.range, this.hoverMessage});
}

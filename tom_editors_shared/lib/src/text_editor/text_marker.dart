import 'package:flutter/painting.dart';

/// The type of a text marker (underline annotation).
enum TextMarkerType {
  /// Red underline for errors.
  error,

  /// Yellow underline for warnings.
  warning,

  /// Gray underline for informational hints.
  info,
}

/// A marker annotation on a range of text.
///
/// Rendered as a colored underline (squiggly or straight) beneath the
/// affected text range, with an associated message tooltip on hover.
///
/// ```dart
/// final marker = TextMarker(
///   start: 42,
///   end: 50,
///   message: 'Expected type "string"',
///   type: TextMarkerType.error,
/// );
/// ```
class TextMarker {
  /// Offset of the first marked character (inclusive).
  final int start;

  /// Offset past the last marked character (exclusive).
  final int end;

  /// Human-readable message shown on hover.
  final String message;

  /// The marker type (determines color and style).
  final TextMarkerType type;

  /// Optional line number (1-based) where this marker appears.
  final int? line;

  /// Optional column (1-based) where this marker starts.
  final int? column;

  const TextMarker({
    required this.start,
    required this.end,
    required this.message,
    this.type = TextMarkerType.error,
    this.line,
    this.column,
  });

  /// The color to use for this marker type.
  Color get color {
    switch (type) {
      case TextMarkerType.error:
        return const Color(0xFFF44747);
      case TextMarkerType.warning:
        return const Color(0xFFCCA700);
      case TextMarkerType.info:
        return const Color(0xFF808080);
    }
  }
}

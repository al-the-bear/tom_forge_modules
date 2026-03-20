import 'package:flutter/material.dart';

import '../../theme/md_editor_theme.dart';

/// Live character count indicator for sections with min/max text constraints.
///
/// Displays the current character count relative to the allowed range,
/// with color feedback: green (within range), yellow (approaching limit),
/// red (below min or above max).
class MdCharCounter extends StatelessWidget {
  const MdCharCounter({
    super.key,
    required this.currentLength,
    required this.theme,
    this.minLength,
    this.maxLength,
    this.textRequired = false,
  });

  /// Current character count.
  final int currentLength;

  /// Minimum required characters (null = no minimum).
  final int? minLength;

  /// Maximum allowed characters (null = no maximum).
  final int? maxLength;

  /// Whether non-empty text is required.
  final bool textRequired;

  /// Editor theme.
  final MdEditorTheme theme;

  @override
  Widget build(BuildContext context) {
    final basic = theme.basic;

    // Don't show if there are no constraints.
    if (minLength == null && maxLength == null && !textRequired) {
      return const SizedBox.shrink();
    }

    final (color, icon) = _getStatusIndicator(basic);
    final rangeText = _getRangeText();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$currentLength$rangeText',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontFamily: basic.monoFontFamily,
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData) _getStatusIndicator(MdBasicTheme basic) {
    if (textRequired && currentLength == 0) {
      return (basic.error, Icons.error_outline);
    }

    if (minLength != null && currentLength < minLength!) {
      return (basic.error, Icons.arrow_downward);
    }

    if (maxLength != null && currentLength > maxLength!) {
      return (basic.error, Icons.arrow_upward);
    }

    // Warning zone: within 10% of max.
    if (maxLength != null) {
      final threshold = (maxLength! * 0.9).toInt();
      if (currentLength >= threshold) {
        return (basic.warning, Icons.warning_amber);
      }
    }

    return (Colors.green, Icons.check_circle_outline);
  }

  String _getRangeText() {
    if (minLength != null && maxLength != null) {
      return ' / $minLength–$maxLength';
    }
    if (minLength != null) {
      return ' / min $minLength';
    }
    if (maxLength != null) {
      return ' / max $maxLength';
    }
    return '';
  }
}

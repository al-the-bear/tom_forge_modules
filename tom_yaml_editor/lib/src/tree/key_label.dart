import 'package:flutter/material.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

import '../yaml_editor_theme.dart';

/// Styled label for a YAML map key.
///
/// Displays the key text with:
/// - Required badge (when the key is required by schema).
/// - Error badge (when there are validation errors at or below this node).
/// - Colon separator.
///
/// ```dart
/// KeyLabel(
///   keyName: 'name',
///   isRequired: true,
///   errorCount: 1,
///   warningCount: 0,
///   theme: YamlEditorTheme.dark(),
/// )
/// ```
class KeyLabel extends StatelessWidget {
  /// The YAML key name.
  final String keyName;

  /// Whether this key is required by the schema.
  final bool isRequired;

  /// Number of errors at or below this node.
  final int errorCount;

  /// Number of warnings at or below this node.
  final int warningCount;

  /// Whether this badge represents propagated (ancestor) errors.
  final bool isPropagated;

  /// Theme for styling.
  final YamlEditorTheme theme;

  /// Whether to show the inline validation badge.
  final bool showValidation;

  /// Whether to ellipsize long key labels.
  final bool ellipsize;

  const KeyLabel({
    super.key,
    required this.keyName,
    this.isRequired = false,
    this.errorCount = 0,
    this.warningCount = 0,
    this.isPropagated = false,
    this.theme = const YamlEditorTheme(),
    this.showValidation = true,
    this.ellipsize = true,
  });

  @override
  Widget build(BuildContext context) {
    var colors = theme.colors;
    var fonts = theme.fonts;
    var structureColors = theme.structureColors;

    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        // Required badge
        if (isRequired)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: structureColors.requiredBadge,
                shape: BoxShape.circle,
              ),
            ),
          ),

        // Key text + colon
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: keyName,
                  style: TextStyle(
                    fontFamily: fonts.keyFontFamily,
                    fontSize: fonts.keyFontSize,
                    fontWeight: fonts.keyFontWeight,
                    color: colors.keyColor,
                  ),
                ),
                TextSpan(
                  text: ':',
                  style: TextStyle(
                    fontFamily: fonts.keyFontFamily,
                    fontSize: fonts.keyFontSize,
                    color: colors.separatorColor,
                  ),
                ),
              ],
            ),
            maxLines: ellipsize ? 1 : null,
            softWrap: !ellipsize,
            overflow: ellipsize ? TextOverflow.ellipsis : TextOverflow.visible,
          ),
        ),

        // Validation badge
        if (showValidation &&
            theme.showInlineValidation &&
            (errorCount > 0 || warningCount > 0)) ...[
          const SizedBox(width: 6),
          ValidationBadge(
            errorCount: errorCount,
            warningCount: warningCount,
            isPropagated: isPropagated,
          ),
        ],
      ],
    );
  }
}

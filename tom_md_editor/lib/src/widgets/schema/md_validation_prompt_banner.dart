import 'package:flutter/material.dart';

import '../../theme/md_editor_theme.dart';

/// Banner showing the schema's validation-prompt for the current section.
///
/// Provides human-readable guidance from the schema author about what
/// the section should contain, displayed at the top of the editing area.
class MdValidationPromptBanner extends StatelessWidget {
  const MdValidationPromptBanner({
    super.key,
    required this.prompt,
    required this.theme,
    this.sectionId,
    this.onDismiss,
  });

  /// The validation prompt text from the schema.
  final String prompt;

  /// Section ID for ${parent.id} interpolation.
  final String? sectionId;

  /// Editor theme.
  final MdEditorTheme theme;

  /// Called when the user dismisses the banner.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final basic = theme.basic;
    final resolvedPrompt = _resolvePrompt();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: basic.accent.withValues(alpha: 0.08),
        border: Border(
          left: BorderSide(color: basic.accent, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, size: 14, color: basic.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              resolvedPrompt,
              style: TextStyle(
                color: basic.textSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          if (onDismiss != null)
            InkWell(
              onTap: onDismiss,
              child: Icon(Icons.close, size: 14, color: basic.textMuted),
            ),
        ],
      ),
    );
  }

  /// Resolve ${parent.id} placeholders.
  String _resolvePrompt() {
    var resolved = prompt;
    if (sectionId != null) {
      resolved = resolved.replaceAll(r'${parent.id}', sectionId!);
    }
    return resolved;
  }
}

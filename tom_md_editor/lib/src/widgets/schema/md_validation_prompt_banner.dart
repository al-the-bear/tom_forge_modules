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
    this.sectionText,
    this.sectionLineNumber,
    this.sectionTags,
    this.sectionFields,
    this.parentId,
    this.onDismiss,
  });

  /// The validation prompt text from the schema.
  final String prompt;

  /// Section ID for ${id} interpolation.
  final String? sectionId;

  /// Section body text for ${text} interpolation (used as length).
  final String? sectionText;

  /// Section line number for ${lineNumber} interpolation.
  final int? sectionLineNumber;

  /// Tags from comment metadata for ${tags} interpolation.
  final String? sectionTags;

  /// Comment metadata fields for ${fields.*} interpolation.
  final Map<String, String>? sectionFields;

  /// Parent section ID for ${parent.id} interpolation.
  final String? parentId;

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

  /// Resolve ${...} placeholders in the prompt text.
  String _resolvePrompt() {
    var resolved = prompt;
    if (sectionId != null) {
      resolved = resolved.replaceAll(r'${id}', sectionId!);
      resolved = resolved.replaceAll(r'${parent.id}', sectionId!);
    }
    if (parentId != null) {
      resolved = resolved.replaceAll(r'${parent.id}', parentId!);
    }
    if (sectionText != null) {
      resolved = resolved.replaceAll(
        r'${text}',
        '${sectionText!.length}',
      );
    }
    if (sectionLineNumber != null) {
      resolved = resolved.replaceAll(
        r'${lineNumber}',
        sectionLineNumber.toString(),
      );
    }
    if (sectionTags != null) {
      resolved = resolved.replaceAll(r'${tags}', sectionTags!);
    }
    // Resolve ${fields.*} placeholders from comment metadata.
    if (sectionFields != null) {
      resolved = resolved.replaceAllMapped(
        RegExp(r'\$\{fields\.([^}]+)\}'),
        (m) => sectionFields![m.group(1)] ?? m.group(0)!,
      );
    }
    return resolved;
  }
}

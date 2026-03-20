import 'package:flutter/material.dart';

import '../../theme/md_editor_theme.dart';

/// Chip-based tag selector for section types with allowed-tags.
///
/// Instead of requiring raw `<!-- tags: ... -->` markup, this widget
/// shows selectable chips for each allowed tag value.
class MdTagSelector extends StatelessWidget {
  const MdTagSelector({
    super.key,
    required this.allowedTags,
    required this.selectedTags,
    required this.onChanged,
    required this.theme,
    this.readOnly = false,
  });

  /// Tags allowed by the schema for this section type.
  final List<String> allowedTags;

  /// Currently selected tags.
  final List<String> selectedTags;

  /// Called when the selection changes.
  final ValueChanged<List<String>> onChanged;

  /// Editor theme.
  final MdEditorTheme theme;

  /// Whether the selector is read-only.
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final basic = theme.basic;

    if (allowedTags.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.label, size: 14, color: basic.textMuted),
          const SizedBox(width: 6),
          Text(
            'Tags:',
            style: TextStyle(
              color: basic.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: allowedTags.map((tag) {
                final isSelected = selectedTags.contains(tag);
                return _TagChip(
                  tag: tag,
                  isSelected: isSelected,
                  basic: basic,
                  onTap: readOnly
                      ? null
                      : () {
                          final updated = List<String>.from(selectedTags);
                          if (isSelected) {
                            updated.remove(tag);
                          } else {
                            updated.add(tag);
                          }
                          onChanged(updated);
                        },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Parse tags from section text HTML comments.
  ///
  /// Expects format: `<!-- tags: tag1, tag2, tag3 -->`
  static List<String> parseTags(String text) {
    final regex = RegExp(r'<!--\s*tags:\s*(.+?)\s*-->');
    final match = regex.firstMatch(text);
    if (match == null) return const [];
    return match
        .group(1)!
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Serialize tags back into the section text.
  ///
  /// Replaces existing `<!-- tags: ... -->` or appends a new one.
  static String updateTags(String text, List<String> tags) {
    final tagComment = tags.isEmpty ? '' : '<!-- tags: ${tags.join(', ')} -->';
    final regex = RegExp(r'<!--\s*tags:\s*.*?\s*-->');

    if (regex.hasMatch(text)) {
      if (tags.isEmpty) {
        return text.replaceFirst(regex, '').trim();
      }
      return text.replaceFirst(regex, tagComment);
    }

    if (tags.isEmpty) return text;
    final trimmed = text.trimRight();
    return '$trimmed\n\n$tagComment';
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.tag,
    required this.isSelected,
    required this.basic,
    this.onTap,
  });

  final String tag;
  final bool isSelected;
  final MdBasicTheme basic;
  final VoidCallback? onTap;

  Color get _chipColor {
    // Assign colors based on common tag semantics.
    final lower = tag.toLowerCase();
    if (lower == 'critical' || lower == 'error') return Colors.red;
    if (lower == 'high' || lower == 'warning') return Colors.orange;
    if (lower == 'medium' || lower == 'info') return Colors.blue;
    if (lower == 'low' || lower == 'minor') return Colors.green;
    return basic.accent;
  }

  @override
  Widget build(BuildContext context) {
    final color = _chipColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : basic.border,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Text(
          tag,
          style: TextStyle(
            color: isSelected ? color : basic.textMuted,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

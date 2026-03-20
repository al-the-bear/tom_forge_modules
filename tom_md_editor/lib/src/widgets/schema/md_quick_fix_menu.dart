import 'package:flutter/material.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

import '../../theme/md_editor_theme.dart';

/// Action for fixing a validation error.
class QuickFixAction {
  const QuickFixAction({
    required this.label,
    required this.icon,
    required this.onExecute,
  });

  final String label;
  final IconData icon;
  final VoidCallback onExecute;
}

/// Analyzes validation errors and produces quick-fix actions.
class QuickFixAnalyzer {
  /// Generate quick-fix actions for a validation error.
  static List<QuickFixAction> getFixesForError(
    ValidationError error, {
    required VoidCallback Function(String typeName) onInsertSection,
    required VoidCallback Function(String sectionId) onNavigateToSection,
    required VoidCallback Function(String sectionId) onRenameId,
    required VoidCallback Function(String sectionId) onDeleteSection,
    required VoidCallback Function(String sectionId) onMoveSection,
  }) {
    final fixes = <QuickFixAction>[];
    final msg = error.message.toLowerCase();

    // Missing required section.
    if (msg.contains('missing required') || msg.contains('not found')) {
      final typeName = _extractTypeName(error);
      if (typeName != null) {
        fixes.add(QuickFixAction(
          label: 'Insert $typeName section',
          icon: Icons.add_circle_outline,
          onExecute: onInsertSection(typeName),
        ));
      }
    }

    // Section ID pattern mismatch.
    if (msg.contains('pattern') && msg.contains('id')) {
      final sectionId = _extractSectionId(error);
      if (sectionId != null) {
        fixes.add(QuickFixAction(
          label: 'Rename section ID',
          icon: Icons.edit,
          onExecute: onRenameId(sectionId),
        ));
      }
    }

    // Count limit exceeded.
    if (msg.contains('exceeds') ||
        msg.contains('too many') ||
        msg.contains('max')) {
      final sectionId = _extractSectionId(error);
      if (sectionId != null) {
        fixes.add(QuickFixAction(
          label: 'Delete section',
          icon: Icons.delete_outline,
          onExecute: onDeleteSection(sectionId),
        ));
      }
    }

    // Text too short.
    if (msg.contains('too short') || msg.contains('minimum')) {
      final sectionId = _extractSectionId(error);
      if (sectionId != null) {
        fixes.add(QuickFixAction(
          label: 'Navigate to section',
          icon: Icons.navigate_next,
          onExecute: onNavigateToSection(sectionId),
        ));
      }
    }

    // Section not allowed at position.
    if (msg.contains('not allowed') || msg.contains('position')) {
      final sectionId = _extractSectionId(error);
      if (sectionId != null) {
        fixes.add(QuickFixAction(
          label: 'Move to valid position',
          icon: Icons.swap_vert,
          onExecute: onMoveSection(sectionId),
        ));
      }
    }

    // Always add navigating to the error location.
    final sectionId = _extractSectionId(error);
    if (sectionId != null && fixes.isNotEmpty) {
      fixes.add(QuickFixAction(
        label: 'Go to section',
        icon: Icons.location_on_outlined,
        onExecute: onNavigateToSection(sectionId),
      ));
    }

    return fixes;
  }

  static String? _extractTypeName(ValidationError error) {
    // Try to extract a type name from error path or message.
    if (error.path.isNotEmpty) {
      return error.path.first.toString();
    }
    return null;
  }

  static String? _extractSectionId(ValidationError error) {
    if (error.path.isNotEmpty) {
      return error.path.first.toString();
    }
    return null;
  }
}

/// Popup menu showing quick-fix actions for a validation error.
class MdQuickFixMenu extends StatelessWidget {
  const MdQuickFixMenu({
    super.key,
    required this.error,
    required this.fixes,
    required this.theme,
  });

  final ValidationError error;
  final List<QuickFixAction> fixes;
  final MdEditorTheme theme;

  @override
  Widget build(BuildContext context) {
    final basic = theme.basic;

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: basic.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: basic.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Error message
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _severityColor(basic).withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _severityIcon(),
                  size: 14,
                  color: _severityColor(basic),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    error.message,
                    style: TextStyle(
                      color: basic.text,
                      fontSize: 12,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (fixes.isNotEmpty) ...[
            Divider(height: 1, color: basic.border),
            // Quick fix actions
            ...fixes.map(
              (fix) => InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  fix.onExecute();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Icon(fix.icon, size: 14, color: basic.accent),
                      const SizedBox(width: 6),
                      Text(
                        fix.label,
                        style: TextStyle(
                          color: basic.accent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _severityColor(MdBasicTheme basic) {
    return switch (error.severity) {
      ValidationSeverity.error => basic.error,
      ValidationSeverity.warning => basic.warning,
      ValidationSeverity.info => basic.accent,
    };
  }

  IconData _severityIcon() {
    return switch (error.severity) {
      ValidationSeverity.error => Icons.error,
      ValidationSeverity.warning => Icons.warning_amber,
      ValidationSeverity.info => Icons.info_outline,
    };
  }
}

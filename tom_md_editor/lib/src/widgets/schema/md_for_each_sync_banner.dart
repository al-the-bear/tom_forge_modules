import 'package:flutter/material.dart';

import '../../controller/md_editor_controller.dart';
import '../../theme/md_editor_theme.dart';

/// A banner widget that detects for-each sync issues and offers
/// one-click create/remove actions.
///
/// Place this inside the editor layout (e.g., above the tree view or
/// raw editor) to alert users when registry entries and detail sections
/// are out of sync.
class MdForEachSyncBanner extends StatelessWidget {
  const MdForEachSyncBanner({
    super.key,
    required this.controller,
    required this.theme,
  });

  final MdEditorController controller;
  final MdEditorTheme theme;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final sync = controller.computeForEachSync();
        if (sync.isSynced) return const SizedBox.shrink();

        final basic = theme.basic;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: basic.warning.withValues(alpha: 0.08),
            border: Border(
              bottom: BorderSide(
                color: basic.warning.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.sync_problem, size: 16, color: basic.warning),
                  const SizedBox(width: 6),
                  Text(
                    'For-each sections out of sync',
                    style: TextStyle(
                      color: basic.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (sync.missing.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${sync.missing.length} missing '
                        '${sync.missing.length == 1 ? "section" : "sections"}',
                        style: TextStyle(
                          color: basic.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        controller.syncForEachMissing(sync.missing);
                      },
                      icon: Icon(Icons.add, size: 14, color: basic.accent),
                      label: Text(
                        'Create all',
                        style: TextStyle(fontSize: 11, color: basic.accent),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 28),
                      ),
                    ),
                  ],
                ),
              ],
              if (sync.orphaned.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${sync.orphaned.length} orphaned '
                        '${sync.orphaned.length == 1 ? "section" : "sections"}',
                        style: TextStyle(
                          color: basic.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        controller.removeForEachOrphaned(sync.orphaned);
                      },
                      icon: Icon(Icons.delete_outline,
                          size: 14, color: basic.error),
                      label: Text(
                        'Remove all',
                        style: TextStyle(fontSize: 11, color: basic.error),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 28),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

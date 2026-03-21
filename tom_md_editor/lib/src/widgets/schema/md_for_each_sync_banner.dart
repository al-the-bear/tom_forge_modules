import 'package:flutter/material.dart';

import '../../controller/md_editor_controller.dart';
import '../../theme/md_editor_theme.dart';

/// A banner widget that detects for-each sync issues and offers
/// per-entry and bulk create/remove actions.
///
/// Place this inside the editor layout (e.g., above the tree view or
/// raw editor) to alert users when registry entries and detail sections
/// are out of sync.
class MdForEachSyncBanner extends StatefulWidget {
  const MdForEachSyncBanner({
    super.key,
    required this.controller,
    required this.theme,
  });

  final MdEditorController controller;
  final MdEditorTheme theme;

  @override
  State<MdForEachSyncBanner> createState() => _MdForEachSyncBannerState();
}

class _MdForEachSyncBannerState extends State<MdForEachSyncBanner> {
  final Set<int> _selectedMissing = {};
  final Set<int> _selectedOrphaned = {};
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final sync = widget.controller.computeForEachSync();
        if (sync.isSynced) return const SizedBox.shrink();

        // Clamp selections to current list sizes.
        _selectedMissing.removeWhere((i) => i >= sync.missing.length);
        _selectedOrphaned.removeWhere((i) => i >= sync.orphaned.length);

        final basic = widget.theme.basic;
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
              // Header row with expand toggle.
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Row(
                  children: [
                    Icon(Icons.sync_problem, size: 16, color: basic.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'For-each sections out of sync',
                        style: TextStyle(
                          color: basic.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: basic.textSecondary,
                    ),
                  ],
                ),
              ),

              // Missing entries.
              if (sync.missing.isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildGroupHeader(
                  basic: basic,
                  count: sync.missing.length,
                  label: 'missing',
                  selectedCount: _selectedMissing.length,
                  onSelectAll: () => setState(() {
                    if (_selectedMissing.length == sync.missing.length) {
                      _selectedMissing.clear();
                    } else {
                      _selectedMissing.addAll(
                        List.generate(sync.missing.length, (i) => i),
                      );
                    }
                  }),
                  onAction: () {
                    final items = _selectedMissing.isEmpty
                        ? sync.missing
                        : _selectedMissing
                            .toList()
                            .map((i) => sync.missing[i])
                            .toList();
                    widget.controller.syncForEachMissing(items);
                    setState(() => _selectedMissing.clear());
                  },
                  actionLabel: _selectedMissing.isEmpty
                      ? 'Create all'
                      : 'Create ${_selectedMissing.length}',
                  actionColor: basic.accent,
                  actionIcon: Icons.add,
                ),
                if (_expanded)
                  ...sync.missing.indexed.map((e) => _buildEntryTile(
                        basic: basic,
                        index: e.$1,
                        label: e.$2.registryId,
                        subtitle: e.$2.sectionName,
                        selected: _selectedMissing.contains(e.$1),
                        onChanged: (v) => setState(() {
                          if (v) {
                            _selectedMissing.add(e.$1);
                          } else {
                            _selectedMissing.remove(e.$1);
                          }
                        }),
                      )),
              ],

              // Orphaned entries.
              if (sync.orphaned.isNotEmpty) ...[
                const SizedBox(height: 4),
                _buildGroupHeader(
                  basic: basic,
                  count: sync.orphaned.length,
                  label: 'orphaned',
                  selectedCount: _selectedOrphaned.length,
                  onSelectAll: () => setState(() {
                    if (_selectedOrphaned.length == sync.orphaned.length) {
                      _selectedOrphaned.clear();
                    } else {
                      _selectedOrphaned.addAll(
                        List.generate(sync.orphaned.length, (i) => i),
                      );
                    }
                  }),
                  onAction: () {
                    final items = _selectedOrphaned.isEmpty
                        ? sync.orphaned
                        : _selectedOrphaned
                            .toList()
                            .map((i) => sync.orphaned[i])
                            .toList();
                    widget.controller.removeForEachOrphaned(items);
                    setState(() => _selectedOrphaned.clear());
                  },
                  actionLabel: _selectedOrphaned.isEmpty
                      ? 'Remove all'
                      : 'Remove ${_selectedOrphaned.length}',
                  actionColor: basic.error,
                  actionIcon: Icons.delete_outline,
                ),
                if (_expanded)
                  ...sync.orphaned.indexed.map((e) => _buildEntryTile(
                        basic: basic,
                        index: e.$1,
                        label: e.$2.sectionId,
                        subtitle: e.$2.sectionName,
                        selected: _selectedOrphaned.contains(e.$1),
                        onChanged: (v) => setState(() {
                          if (v) {
                            _selectedOrphaned.add(e.$1);
                          } else {
                            _selectedOrphaned.remove(e.$1);
                          }
                        }),
                      )),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupHeader({
    required MdBasicTheme basic,
    required int count,
    required String label,
    required int selectedCount,
    required VoidCallback onSelectAll,
    required VoidCallback onAction,
    required String actionLabel,
    required Color actionColor,
    required IconData actionIcon,
  }) {
    return Row(
      children: [
        if (_expanded)
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: selectedCount == count && count > 0,
              tristate: true,
              onChanged: (_) => onSelectAll(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
        if (_expanded) const SizedBox(width: 4),
        Expanded(
          child: Text(
            '$count $label '
            '${count == 1 ? "section" : "sections"}',
            style: TextStyle(color: basic.textSecondary, fontSize: 11),
          ),
        ),
        TextButton.icon(
          onPressed: onAction,
          icon: Icon(actionIcon, size: 14, color: actionColor),
          label: Text(
            actionLabel,
            style: TextStyle(fontSize: 11, color: actionColor),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 28),
          ),
        ),
      ],
    );
  }

  Widget _buildEntryTile({
    required MdBasicTheme basic,
    required int index,
    required String label,
    required String subtitle,
    required bool selected,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: selected,
              onChanged: (v) => onChanged(v ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: basic.text,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (subtitle != label)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                subtitle,
                style: TextStyle(color: basic.textSecondary, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

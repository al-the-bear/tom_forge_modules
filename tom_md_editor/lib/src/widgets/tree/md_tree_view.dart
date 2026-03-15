import 'package:flutter/material.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

import '../../controller/md_editor_controller.dart';
import '../../debug/md_editor_debug.dart';
import '../../models/md_section.dart';
import '../../settings/md_editor_settings.dart';
import '../../theme/md_editor_theme.dart';

/// Tree view panel showing section hierarchy with drag-drop reordering.
class MdTreeView extends StatefulWidget {
  const MdTreeView({
    super.key,
    required this.controller,
    required this.theme,
    required this.settings,
    this.onSectionSelected,
  });

  final MdEditorController controller;
  final MdEditorTheme theme;
  final MdEditorSettings settings;
  final ValueChanged<MdSection>? onSectionSelected;

  @override
  State<MdTreeView> createState() => _MdTreeViewState();
}

class _MdTreeViewState extends State<MdTreeView> {
  late TreeController<MdSection> _treeController;

  @override
  void initState() {
    super.initState();
    _treeController = TreeController<MdSection>(
      roots: _buildTreeNodes(),
    );
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(MdTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _updateTree();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _treeController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    _updateTree();
  }

  void _updateTree() {
    try {
      _treeController.roots = _buildTreeNodes();
      setState(() {});
    } catch (e, st) {
      MdEditorDebug.logger.error('Error updating tree', e, st);
    }
  }

  List<TreeNode<MdSection>> _buildTreeNodes() {
    try {
      return widget.controller.document.sections
          .map((s) => _sectionToNode(s, 0))
          .toList();
    } catch (e, st) {
      MdEditorDebug.logger.error('Error building tree nodes', e, st);
      return [];
    }
  }

  TreeNode<MdSection> _sectionToNode(MdSection section, int depth) {
    return TreeNode<MdSection>(
      id: '${section.level}_${section.headline}_$depth',
      data: section,
      children:
          section.subsections
              .map((s) => _sectionToNode(s, depth + 1))
              .toList(),
      isExpanded: widget.settings.expandAllByDefault,
    );
  }

  @override
  Widget build(BuildContext context) {
    final basic = widget.theme.basic;

    return Container(
      color: basic.surface,
      child: Column(
        children: [
          // Title bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: basic.surfaceVariant,
              border: Border(
                bottom: BorderSide(color: basic.border, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.account_tree, size: 16, color: basic.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Document Outline',
                  style: TextStyle(
                    color: basic.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                _buildCollapseAllButton(basic),
                const SizedBox(width: 4),
                _buildExpandAllButton(basic),
              ],
            ),
          ),
          // Tree
          Expanded(
            child: TreeView<MdSection>(
              controller: _treeController,
              theme: _buildTreeTheme(basic),
              nodeBuilder: (context, node, isSelected) =>
                  _buildNode(context, node, basic, isSelected: isSelected),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapseAllButton(MdBasicTheme basic) {
    return InkWell(
      onTap: () => _treeController.collapseAll(),
      child: Tooltip(
        message: 'Collapse All',
        child: Icon(Icons.unfold_less, size: 16, color: basic.textMuted),
      ),
    );
  }

  Widget _buildExpandAllButton(MdBasicTheme basic) {
    return InkWell(
      onTap: () => _treeController.expandAll(),
      child: Tooltip(
        message: 'Expand All',
        child: Icon(Icons.unfold_more, size: 16, color: basic.textMuted),
      ),
    );
  }

  Widget _buildNode(
    BuildContext context,
    TreeNode<MdSection> node,
    MdBasicTheme basic, {
    bool isSelected = false,
  }) {
    final section = node.data;
    final number = widget.controller.computeSectionNumber(section);
    final hierarchicalId =
        widget.controller.computeHierarchicalId(section);
    final idLabel = hierarchicalId.isNotEmpty ? ' [$hierarchicalId]' : '';

    final content = GestureDetector(
      onTap: () {
        widget.controller.selectSection(section);
        widget.onSectionSelected?.call(section);
      },
      onSecondaryTapDown: (details) {
        _showContextMenu(context, details.globalPosition, section);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? basic.selection : Colors.transparent,
        ),
        child: Row(
          children: [
            // Drag handle
            if (!widget.settings.readOnly)
              MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Icon(
                  Icons.drag_indicator,
                  size: 14,
                  color: basic.textMuted,
                ),
              ),
            if (!widget.settings.readOnly) const SizedBox(width: 2),
            // Level indicator
            Icon(
              _iconForLevel(section.level),
              size: 14,
              color: isSelected ? basic.accent : basic.textMuted,
            ),
            const SizedBox(width: 4),
            // Numbering
            Text(
              number,
              style: TextStyle(
                color: basic.textMuted,
                fontSize: 11,
                fontFamily: basic.monoFontFamily,
              ),
            ),
            const SizedBox(width: 4),
            // Headline text + ID
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: section.headline,
                      style: TextStyle(
                        color: isSelected ? basic.accent : basic.text,
                        fontSize: 13,
                        fontWeight: section.level <= 2
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    if (idLabel.isNotEmpty)
                      TextSpan(
                        text: idLabel,
                        style: TextStyle(
                          color: basic.textMuted,
                          fontSize: 11,
                          fontFamily: basic.monoFontFamily,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Edit button
            if (!widget.settings.readOnly)
              InkWell(
                onTap: () => _showEditDialog(section),
                child: Tooltip(
                  message: 'Edit headline & ID',
                  child: Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: basic.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (widget.settings.readOnly) return content;

    // Wrap in Draggable + DragTarget for reordering.
    return DragTarget<MdSection>(
      onWillAcceptWithDetails: (details) {
        if (identical(details.data, section)) return false;
        return true;
      },
      onAcceptWithDetails: (details) {
        final dropped = details.data;
        // Move the dropped section after the target section at the same level.
        final parent = _findParentSection(section);
        final siblings =
            parent?.subsections ?? widget.controller.document.sections;
        final idx = siblings.indexOf(section);
        widget.controller.moveSection(
          dropped,
          newParent: parent,
          newIndex: idx + 1,
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDropTarget)
              Container(
                height: 2,
                color: basic.accent,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
            Draggable<MdSection>(
              data: section,
              feedback: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: basic.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: basic.accent),
                  ),
                  child: Text(
                    '$number ${section.headline}',
                    style: TextStyle(
                      color: basic.text,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: content,
              ),
              child: content,
            ),
          ],
        );
      },
    );
  }

  IconData _iconForLevel(int level) {
    return switch (level) {
      1 => Icons.title,
      2 => Icons.segment,
      3 => Icons.short_text,
      _ => Icons.notes,
    };
  }

  void _showContextMenu(
    BuildContext context,
    Offset position,
    MdSection section,
  ) {
    try {
      if (widget.settings.readOnly) return;

      // Check if merging is possible (needs a next sibling at the same level).
      final parent = _findParentSection(section);
      final siblings =
          parent?.subsections ?? widget.controller.document.sections;
      final idx = siblings.indexOf(section);
      final canMerge = idx >= 0 && idx + 1 < siblings.length;

      showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(
          position.dx,
          position.dy,
          position.dx,
          position.dy,
        ),
        items: [
          const PopupMenuItem(
            value: 'add_above',
            child: Text('Add Section Above'),
          ),
          const PopupMenuItem(
            value: 'add_below',
            child: Text('Add Section Below'),
          ),
          const PopupMenuItem(
            value: 'add_child',
            child: Text('Add Subsection'),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'move_up', child: Text('Move Up')),
          const PopupMenuItem(value: 'move_down', child: Text('Move Down')),
          if (section.level > 1)
            const PopupMenuItem(
              value: 'promote',
              child: Text('Promote Headline'),
            ),
          if (section.level < 6)
            const PopupMenuItem(
              value: 'demote',
              child: Text('Demote Headline'),
            ),
          if (canMerge) ...[
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'merge_next',
              child: Text('Merge with Section Below'),
            ),
          ],
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'edit',
            child: Text('Edit Headline & ID'),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Text('Delete Section'),
          ),
        ],
      ).then((value) {
        if (value == null) return;
        _handleContextAction(value, section);
      });
    } catch (e, st) {
      MdEditorDebug.logger.error('Error showing context menu', e, st);
    }
  }

  Future<void> _handleContextAction(String action, MdSection section) async {
    try {
      switch (action) {
        case 'add_above':
          final result = await _showNewSectionDialog();
          if (result == null) return;
          final parent = widget.controller.document.sections.contains(section)
              ? null
              : _findParentSection(section);
          final siblings =
              parent?.subsections ?? widget.controller.document.sections;
          final idx = siblings.indexOf(section);
          await widget.controller.insertSection(
            parent: parent,
            index: idx >= 0 ? idx : 0,
            level: section.level,
            headline: result.headline,
            id: result.id,
          );
        case 'add_below':
          final result = await _showNewSectionDialog();
          if (result == null) return;
          final parent = widget.controller.document.sections.contains(section)
              ? null
              : _findParentSection(section);
          final siblings =
              parent?.subsections ?? widget.controller.document.sections;
          final idx = siblings.indexOf(section);
          await widget.controller.insertSection(
            parent: parent,
            index: idx >= 0 ? idx + 1 : siblings.length,
            level: section.level,
            headline: result.headline,
            id: result.id,
          );
        case 'add_child':
          final result = await _showNewSectionDialog(isSubsection: true);
          if (result == null) return;
          await widget.controller.insertSection(
            parent: section,
            index: section.subsections.length,
            level: section.level + 1,
            headline: result.headline,
            id: result.id,
          );
        case 'edit':
          _showEditDialog(section);
        case 'delete':
          await widget.controller.deleteSection(section);
        case 'promote':
          await widget.controller.promoteSection(section);
        case 'demote':
          await widget.controller.demoteSection(section);
        case 'move_up':
          await widget.controller.moveSectionUp(section);
        case 'move_down':
          await widget.controller.moveSectionDown(section);
        case 'merge_next':
          await widget.controller.mergeSectionWithNext(section);
      }
    } catch (e, st) {
      MdEditorDebug.logger.error(
        'Error handling context action: $action',
        e,
        st,
      );
    }
  }

  MdSection? _findParentSection(MdSection target) {
    MdSection? find(List<MdSection> siblings, MdSection? parent) {
      for (final s in siblings) {
        if (identical(s, target)) return parent;
        final found = find(s.subsections, s);
        if (found != null) return found;
      }
      return null;
    }
    return find(widget.controller.document.sections, null);
  }

  /// Show a dialog to create a new section with headline and ID.
  Future<({String headline, String? id})?> _showNewSectionDialog({
    bool isSubsection = false,
  }) async {
    final headlineController = TextEditingController();
    final idController = TextEditingController();
    final label = isSubsection ? 'Subsection' : 'Section';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('New $label'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: headlineController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Headline'),
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: idController,
              decoration: const InputDecoration(
                labelText: 'ID (optional)',
                hintText: 'e.g. my-section-id',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    final headline = headlineController.text.trim();
    final id = idController.text.trim();
    headlineController.dispose();
    idController.dispose();
    if (result != true || headline.isEmpty) return null;
    return (headline: headline, id: id.isEmpty ? null : id);
  }

  /// Show a dialog to edit the headline and ID of a section.
  void _showEditDialog(MdSection section) {
    final headlineController = TextEditingController(text: section.headline);
    final idController = TextEditingController(text: section.id ?? '');
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Headline & ID'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: headlineController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Headline'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: idController,
              decoration: const InputDecoration(
                labelText: 'ID (optional)',
                hintText: 'e.g. my-section-id',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed != true) {
        headlineController.dispose();
        idController.dispose();
        return;
      }
      final newHeadline = headlineController.text.trim();
      final newId = idController.text.trim();
      headlineController.dispose();
      idController.dispose();
      if (newHeadline.isNotEmpty && newHeadline != section.headline) {
        widget.controller.updateSectionHeadline(section, newHeadline);
      }
      final effectiveId = newId.isEmpty ? null : newId;
      if (effectiveId != section.id) {
        widget.controller.updateSectionId(section, effectiveId);
      }
    });
  }

  TreeTheme _buildTreeTheme(MdBasicTheme basic) {
    return TreeTheme(
      treeLineColor: basic.border,
      collapsedIcon: Icons.chevron_right,
      expandedIcon: Icons.expand_more,
      hoverColor: basic.selection,
      selectionColor: basic.selection,
      focusColor: basic.accent.withValues(alpha: 0.15),
      indentWidth: 20,
      rowHeight: 32,
      showTreeLines: true,
      labelStyle: TextStyle(
        color: basic.text,
        fontSize: 13,
      ),
    );
  }
}

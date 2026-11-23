import 'package:flutter/material.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

import '../../controller/md_editor_controller.dart';
import '../../debug/md_editor_debug.dart';
import '../../models/md_section.dart';
import '../../schema/md_schema_support.dart';
import '../../settings/md_editor_settings.dart';
import '../../theme/md_editor_theme.dart';
import '../dialogs/edit_section_dialog.dart';

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
                // A narrow outline shortens the title rather than overflow.
                Expanded(
                  child: Text(
                    'Document Outline',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: basic.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
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
    final sectionId = section.id ?? '';
    final idLabel = sectionId.isNotEmpty ? ' [$sectionId]' : '';

    // Build schema type tooltip (P5.3).
    String? typeTooltip;
    final schema = widget.controller.schemaSupport;
    if (widget.settings.showSectionTypeTooltips && schema != null) {
      final typeName = schema.sectionTypeName(
        section,
        widget.controller.document,
      );
      if (typeName != null) {
        typeTooltip = schema.sectionTypeTooltip(typeName);
      }
    }

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
            // Schema validation indicator
            ..._buildValidationIndicator(section, basic),
          ],
        ),
      ),
    );

    // Wrap in schema type tooltip if available.
    final wrappedContent = typeTooltip != null
        ? Tooltip(message: typeTooltip, child: content)
        : content;

    if (widget.settings.readOnly) return wrappedContent;

    // Wrap in Draggable + DragTarget for reordering.
    return DragTarget<MdSection>(
      onWillAcceptWithDetails: (details) {
        if (identical(details.data, section)) return false;
        // Position-aware drag-drop validation.
        final schema = widget.controller.schemaSupport;
        if (widget.settings.enablePositionAwareDragDrop && schema != null) {
          final parent = _findParentSection(section);
          final siblings =
              parent?.subsections ?? widget.controller.document.sections;
          final idx = siblings.indexOf(section);
          return schema.isValidDrop(
            draggedSection: details.data,
            targetParent: parent,
            targetIndex: idx + 1,
            document: widget.controller.document,
          );
        }
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
        final isRejected = rejectedData.isNotEmpty;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDropTarget)
              Container(
                height: 2,
                color: basic.accent,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
            if (isRejected)
              Container(
                height: 2,
                color: basic.error,
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
                child: wrappedContent,
              ),
              child: wrappedContent,
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

      // Build schema-aware subsection items.
      final subsectionItems = _buildSchemaSubsectionItems(section);

      // Build typed top-level items for above/below.
      final isTopLevel =
          widget.controller.document.sections.contains(section);
      final topLevelAboveItems =
          isTopLevel ? _buildTopLevelTypeItems('above') : const <PopupMenuEntry<String>>[];
      final topLevelBelowItems =
          isTopLevel ? _buildTopLevelTypeItems('below') : const <PopupMenuEntry<String>>[];

      // Build quick-fix items.
      final quickFixItems = _buildQuickFixItems(section);

      // Build section type tooltip info.
      String? sectionTypeLabel;
      final schema = widget.controller.schemaSupport;
      if (widget.settings.showSectionTypeTooltips && schema != null) {
        sectionTypeLabel = schema.sectionTypeName(
          section,
          widget.controller.document,
        );
      }

      showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(
          position.dx,
          position.dy,
          position.dx,
          position.dy,
        ),
        items: [
          if (sectionTypeLabel != null)
            PopupMenuItem(
              enabled: false,
              child: Text(
                'Type: $sectionTypeLabel',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ),
          const PopupMenuItem(
            value: 'add_above',
            child: Text('Add Section Above'),
          ),
          ...topLevelAboveItems,
          const PopupMenuItem(
            value: 'add_below',
            child: Text('Add Section Below'),
          ),
          ...topLevelBelowItems,
          // Schema-aware subsection items or generic fallback
          ...subsectionItems,
          ...quickFixItems,
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

  /// Build schema-aware subsection menu items.
  ///
  /// If a schema is loaded and the section has defined subsection types,
  /// returns individual items for each allowed type. Uses availability
  /// filtering to exclude types that have reached their max-count.
  List<PopupMenuEntry<String>> _buildSchemaSubsectionItems(
    MdSection section,
  ) {
    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem(
        value: 'add_child',
        child: Text('Add Subsection'),
      ),
    ];

    final schema = widget.controller.schemaSupport;
    if (schema != null) {
      final allowed = schema.availableSubsections(
        section,
        widget.controller.document,
      );

      if (allowed.isNotEmpty) {
        items.add(const PopupMenuDivider());
        for (final sub in allowed) {
          final countInfo = schema.countLabel(
            sub.typeName,
            widget.controller.document,
          );
          items.add(
            PopupMenuItem(
              value: 'add_typed_child:${sub.typeName}',
              child: Tooltip(
                message: sub.description ?? '',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.subdirectory_arrow_right, size: 14),
                    const SizedBox(width: 6),
                    Text('Add ${sub.capitalizedName}'),
                    if (countInfo.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        countInfo,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }
      }
    }

    return items;
  }

  /// Build schema-aware menu items for "Add Section Above/Below" at top level.
  List<PopupMenuEntry<String>> _buildTopLevelTypeItems(String prefix) {
    final schema = widget.controller.schemaSupport;
    if (schema == null) return const [];

    final available = schema.availableTopLevelSections(
      widget.controller.document,
    );

    if (available.isEmpty) return const [];

    final items = <PopupMenuEntry<String>>[
      const PopupMenuDivider(),
    ];
    for (final entry in available) {
      final capitalName = entry.capitalizedName;
      items.add(
        PopupMenuItem(
          value: '${prefix}_typed:${entry.typeName}:${entry.name ?? entry.typeName}',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                entry.optional ? Icons.add_circle_outline : Icons.add_circle,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(capitalName),
              if (!entry.optional)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '(required)',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context)
                          .colorScheme
                          .error
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return items;
  }

  /// Stores quick-fix actions from the last context menu build, so
  /// [_handleContextAction] can execute the selected fix by index.
  List<MdSchemaAction> _lastQuickFixes = const [];

  /// Build quick-fix menu items for a section's validation errors.
  List<PopupMenuEntry<String>> _buildQuickFixItems(MdSection section) {
    if (!widget.settings.enableQuickFixes) return const [];
    final schema = widget.controller.schemaSupport;
    if (schema == null) return const [];

    final errors = _getValidationErrorsForSection(section);
    if (errors.isEmpty) return const [];

    final fixes = schema.quickFixes(
      widget.controller,
      section,
      errors,
      onRename: _showEditDialog,
    );
    if (fixes.isEmpty) return const [];
    _lastQuickFixes = fixes;

    return [
      const PopupMenuDivider(),
      ...fixes.take(5).indexed.map((e) => PopupMenuItem(
            value: 'quick_fix:${e.$1}',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(e.$2.icon, size: 14, color: Colors.amber),
                const SizedBox(width: 6),
                Flexible(child: Text(e.$2.label, maxLines: 1)),
              ],
            ),
          )),
    ];
  }

  /// Build validation indicator widgets for a section.
  List<Widget> _buildValidationIndicator(
    MdSection section,
    MdBasicTheme basic,
  ) {
    final errors = _getValidationErrorsForSection(section);
    if (errors.isEmpty) return const [];

    final worstSeverity = errors.fold<ValidationSeverity>(
      ValidationSeverity.info,
      (worst, error) =>
          error.severity.index < worst.index ? error.severity : worst,
    );

    final (icon, color) = switch (worstSeverity) {
      ValidationSeverity.error => (Icons.error, basic.error),
      ValidationSeverity.warning => (Icons.warning_amber, basic.warning),
      ValidationSeverity.info => (Icons.info_outline, basic.accent),
    };

    final tooltip = errors.map((e) => e.message).join('\n');

    return [
      const SizedBox(width: 4),
      Tooltip(
        message: tooltip,
        child: Icon(icon, size: 14, color: color),
      ),
    ];
  }

  /// Get validation errors relevant to a specific section.
  ///
  /// When [includeChildren] is true (default), also collects errors
  /// from all subsections, so parent nodes show the worst severity.
  List<ValidationError> _getValidationErrorsForSection(
    MdSection section, {
    bool includeChildren = true,
  }) {
    final allErrors = widget.controller.validationErrors;
    if (allErrors.isEmpty) return const [];

    // Collect IDs and headlines of this section and all descendants.
    final matchIds = <String>{};
    final matchHeadlines = <String>{};

    void collectMatches(MdSection s) {
      final id = s.id ?? '';
      if (id.isNotEmpty) matchIds.add(id);
      matchHeadlines.add(s.headline.toLowerCase());
      if (includeChildren) {
        for (final child in s.subsections) {
          collectMatches(child);
        }
      }
    }

    collectMatches(section);

    return allErrors.where((error) {
      if (error.path.isEmpty) return false;
      final firstPath = error.path.first.toString().toLowerCase();
      // Match by section ID or headline (including children).
      if (matchIds.any((id) => firstPath == id)) return true;
      if (matchHeadlines.any((h) => firstPath == h)) return true;
      return false;
    }).toList();
  }

  Future<void> _handleContextAction(String action, MdSection section) async {
    try {
      // Handle schema-typed subsection insertion.
      if (action.startsWith('add_typed_child:')) {
        final typeName = action.substring('add_typed_child:'.length);
        await _addTypedSubsection(section, typeName);
        return;
      }

      // Handle typed top-level section insertion (above/below).
      if (action.startsWith('above_typed:') ||
          action.startsWith('below_typed:')) {
        final isAbove = action.startsWith('above_');
        final parts = action.split(':');
        if (parts.length >= 3) {
          final typeName = parts[1];
          final sectionName = parts[2];
          await _addTypedTopLevelSection(
            section,
            typeName,
            sectionName,
            above: isAbove,
          );
        }
        return;
      }

      // Handle quick-fix actions.
      if (action.startsWith('quick_fix:')) {
        final idx = int.tryParse(action.substring('quick_fix:'.length));
        if (idx != null && idx >= 0 && idx < _lastQuickFixes.length) {
          _lastQuickFixes[idx].onExecute();
        }
        return;
      }

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

  /// Insert a typed subsection based on schema definition.
  ///
  /// Uses the schema ([MdSchemaSupport.template]) to pre-fill template content and
  /// suggested IDs based on the section type definition.
  Future<void> _addTypedSubsection(
    MdSection parentSection,
    String typeName,
  ) async {
    final schema = widget.controller.schemaSupport;
    if (schema == null) return;

    final suggestedId = schema.suggestedId(typeName);
    final capitalName = typeName
        .replaceAll('-', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');

    final idPattern = schema.idPattern(typeName);

    // Collect registry IDs for autocomplete suggestions.
    final registryIds = schema.registryIds(
      widget.controller.document,
      typeName,
    );

    final result = await _showNewSectionDialog(
      isSubsection: true,
      defaultHeadline: capitalName,
      defaultId: suggestedId,
      patternHint: idPattern,
      idSuggestions: registryIds,
    );
    if (result == null) return;

    // Generate template content for the new section.
    final template = schema.template(typeName);

    await widget.controller.insertSection(
      parent: parentSection,
      index: parentSection.subsections.length,
      level: parentSection.level + 1,
      headline: result.headline,
      id: result.id,
      text: template,
    );
  }

  /// Insert a typed top-level section above or below the reference section.
  Future<void> _addTypedTopLevelSection(
    MdSection referenceSection,
    String typeName,
    String sectionName, {
    required bool above,
  }) async {
    final schema = widget.controller.schemaSupport;
    if (schema == null) return;

    final suggestedId = schema.suggestedId(typeName);
    final capitalName = sectionName
        .replaceAll('-', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');

    final idPattern = schema.idPattern(typeName);

    // Collect registry IDs for autocomplete suggestions.
    final registryIds = schema.registryIds(
      widget.controller.document,
      typeName,
    );

    final result = await _showNewSectionDialog(
      defaultHeadline: capitalName,
      defaultId: suggestedId,
      patternHint: idPattern,
      idSuggestions: registryIds,
    );
    if (result == null) return;

    final template = schema.template(typeName);
    final siblings = widget.controller.document.sections;
    final idx = siblings.indexOf(referenceSection);

    await widget.controller.insertSection(
      index: above ? (idx >= 0 ? idx : 0) : (idx >= 0 ? idx + 1 : siblings.length),
      level: 1,
      headline: result.headline,
      id: result.id,
      text: template,
    );
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

  /// Get allowed tags for a section from the schema.
  List<String> _getAllowedTagsForSection(MdSection section) {
    final schema = widget.controller.schemaSupport;
    if (schema == null) return const [];

    final typeName = schema.sectionTypeName(
      section,
      widget.controller.document,
    );
    if (typeName == null) return const [];
    return schema.allowedTags(typeName);
  }

  /// Show a dialog to create a new section with headline and ID.
  ///
  /// When [patternHint] is provided, shows a hint below the ID field
  /// indicating the expected format (e.g., from `pattern-check`).
  ///
  /// When [idSuggestions] is provided, shows autocomplete suggestions
  /// for the ID field while still allowing free-form typing.
  Future<({String headline, String? id})?> _showNewSectionDialog({
    bool isSubsection = false,
    String? defaultHeadline,
    String? defaultId,
    String? patternHint,
    List<String> idSuggestions = const [],
  }) async {
    final headlineController = TextEditingController(
      text: defaultHeadline ?? '',
    );
    final idController = TextEditingController(text: defaultId ?? '');
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
            if (idSuggestions.isNotEmpty)
              Autocomplete<String>(
                optionsBuilder: (textEditingValue) {
                  final query = textEditingValue.text.toLowerCase();
                  if (query.isEmpty) return idSuggestions;
                  return idSuggestions.where(
                    (s) => s.toLowerCase().contains(query),
                  );
                },
                fieldViewBuilder: (ctx, controller, focusNode, onSubmit) {
                  // Sync the external idController with the autocomplete's.
                  controller.text = idController.text;
                  controller.addListener(() {
                    idController.text = controller.text;
                  });
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'ID (optional)',
                      hintText: defaultId ?? 'e.g. my-section-id',
                      suffixIcon: Icon(
                        Icons.arrow_drop_down,
                        color: Theme.of(ctx)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  );
                },
                onSelected: (value) {
                  idController.text = value;
                },
              )
            else
              TextField(
                controller: idController,
                decoration: InputDecoration(
                  labelText: 'ID (optional)',
                  hintText: defaultId ?? 'e.g. my-section-id',
                ),
              ),
            if (patternHint != null && patternHint.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Expected pattern: $patternHint',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(ctx)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
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

  /// Show a dialog to edit the headline, ID, and comment metadata of a section.
  void _showEditDialog(MdSection section) {
    final headlineController = TextEditingController(text: section.headline);
    final idController = TextEditingController(text: section.id ?? '');

    // Build context-sensitive allowed section types.
    final schema = widget.controller.schemaSupport;
    final hasSchema = schema != null;
    var allowedSectionTypes = <SectionTypeInfo>[];
    List<String> schemaFields = const [];

    if (schema != null) {
      final document = widget.controller.document;

      // A child of another section takes its allowed subsection types; a
      // top-level section the allowed top-level types of the document
      // structure.
      final parent = _findParentSection(section);
      final types = parent != null
          ? schema.allowedSubsections(parent, document)
          : schema.allowedTopLevelSections();
      allowedSectionTypes = types
          .map(
            (type) => (
              typeName: type.typeName,
              prefix: type.prefix ?? type.typeName,
              idPattern: type.idPattern,
              idPatternErrorMessage: type.idPatternErrorMessage,
            ),
          )
          .toList();

      // Get required fields for current section type.
      final typeName = schema.sectionTypeName(section, document);
      if (typeName != null) {
        schemaFields = schema.requiredFields(typeName);
      }
    }

    // Build metadata controllers from existing values + schema required fields.
    // Exclude 'tags' since it's handled separately in the dialog.
    final existingMeta = Map<String, String>.from(section.commentMetadata);
    final tagsStr = existingMeta.remove('tags') ?? '';
    final initialTags = tagsStr.isNotEmpty
        ? tagsStr.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
        : <String>[];

    final allKeys = <String>{...existingMeta.keys, ...schemaFields};
    allKeys.remove('tags'); // Ensure tags not in metadata controllers.
    final metaControllers = <String, TextEditingController>{};
    for (final key in allKeys) {
      metaControllers[key] =
          TextEditingController(text: existingMeta[key] ?? '');
    }

    // Get allowed tags from schema.
    final allowedTags = _getAllowedTagsForSection(section);

    showDialog<List<String>>(
      context: context,
      builder: (ctx) => EditSectionDialog(
        headlineController: headlineController,
        idController: idController,
        metaControllers: metaControllers,
        allowedSectionTypes: allowedSectionTypes,
        hasSchema: hasSchema,
        schemaFields: schemaFields,
        allowedTags: allowedTags,
        initialTags: initialTags,
      ),
    ).then((resultTags) {
      if (resultTags == null) {
        headlineController.dispose();
        idController.dispose();
        for (final c in metaControllers.values) {
          c.dispose();
        }
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
      // Collect updated metadata, dropping empty values.
      final newMeta = <String, String>{};
      for (final entry in metaControllers.entries) {
        final value = entry.value.text.trim();
        if (value.isNotEmpty) {
          newMeta[entry.key] = value;
        }
        entry.value.dispose();
      }
      // Add tags back to metadata if any.
      if (resultTags.isNotEmpty) {
        newMeta['tags'] = resultTags.join(',');
      }
      if (!_mapEquals(newMeta, section.commentMetadata)) {
        widget.controller.updateCommentMetadata(section, newMeta);
      }
    });
  }

  static bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  TreeTheme _buildTreeTheme(MdBasicTheme basic) {
    return TreeTheme(
      treeLineColor: basic.border,
      toggleIconColor: basic.textSecondary,
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

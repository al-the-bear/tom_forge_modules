import 'package:flutter/material.dart';

import '../../controller/md_editor_controller.dart';
import '../../debug/md_editor_debug.dart';
import '../../settings/md_editor_settings.dart';
import '../../theme/md_editor_theme.dart';

/// Toolbar widget providing markdown formatting actions.
///
/// Displays buttons for common markdown operations: text formatting,
/// structural elements, undo/redo, and save.
class MdEditorToolbar extends StatelessWidget {
  const MdEditorToolbar({
    super.key,
    required this.controller,
    required this.theme,
    required this.settings,
    this.onSave,
    this.onToggleSearch,
    this.showSearch = false,
  });

  final MdEditorController controller;
  final MdEditorTheme theme;
  final MdEditorSettings settings;
  final VoidCallback? onSave;
  final VoidCallback? onToggleSearch;
  final bool showSearch;

  @override
  Widget build(BuildContext context) {
    final basic = theme.basic;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: basic.surfaceVariant,
        border: Border(
          bottom: BorderSide(color: basic.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          if (!settings.readOnly) ...[
            _button(basic, Icons.undo, 'Undo',
                controller.canUndo ? controller.undo : null),
            _button(basic, Icons.redo, 'Redo',
                controller.canRedo ? controller.redo : null),
            _divider(basic),
            _button(basic, Icons.format_bold, 'Bold',
                () => _wrapSelection('**')),
            _button(basic, Icons.format_italic, 'Italic',
                () => _wrapSelection('*')),
            _button(basic, Icons.format_strikethrough, 'Strikethrough',
                () => _wrapSelection('~~')),
            _button(basic, Icons.code, 'Inline Code',
                () => _wrapSelection('`')),
            _divider(basic),
            _button(basic, Icons.link, 'Link', _insertLink),
            _button(basic, Icons.image, 'Image', _insertImage),
            _divider(basic),
            _headingDropdown(context, basic),
            _divider(basic),
            _button(basic, Icons.format_list_bulleted, 'Bullet List',
                () => _insertPrefix('- ')),
            _button(basic, Icons.format_list_numbered, 'Numbered List',
                () => _insertPrefix('1. ')),
            _button(basic, Icons.check_box_outlined, 'Task List',
                () => _insertPrefix('- [ ] ')),
            _divider(basic),
            _button(basic, Icons.data_object, 'Code Block',
                _insertCodeBlock),
            _button(basic, Icons.table_chart, 'Table', _insertTable),
            _button(basic, Icons.horizontal_rule, 'Horizontal Rule',
                _insertHorizontalRule),
            _divider(basic),
            _button(basic, Icons.add, 'Add Section', _addSection),
          ],
          _button(basic, Icons.search, 'Search', onToggleSearch,
              active: showSearch),
          const Spacer(),
          if (onSave != null && !settings.readOnly)
            _button(basic, Icons.save, 'Save', onSave),
        ],
      ),
    );
  }

  Widget _button(
    MdBasicTheme basic,
    IconData icon,
    String tooltip,
    VoidCallback? onTap, {
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: active ? basic.accent.withValues(alpha: 0.15) : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            size: 18,
            color: onTap != null ? basic.text : basic.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _divider(MdBasicTheme basic) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: basic.border,
    );
  }

  Widget _headingDropdown(BuildContext context, MdBasicTheme basic) {
    return PopupMenuButton<int>(
      tooltip: 'Heading Level',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Icon(Icons.title, size: 18, color: basic.text),
      ),
      onSelected: (level) => _insertHeading(level),
      itemBuilder: (_) => List.generate(6, (i) {
        final level = i + 1;
        return PopupMenuItem(
          value: level,
          child: Text('H$level — ${'#' * level}'),
        );
      }),
    );
  }

  // ── Formatting actions ──

  void _wrapSelection(String marker) {
    try {
      final section = controller.selectedSection;
      if (section == null) return;
      final text = section.text;
      final wrapped = '$marker selected text $marker';
      controller.updateSectionText(section, '$text\n$wrapped');
    } catch (e, st) {
      MdEditorDebug.logger.error('Error wrapping selection', e, st);
    }
  }

  void _insertLink() {
    try {
      final section = controller.selectedSection;
      if (section == null) return;
      controller.updateSectionText(
        section,
        '${section.text}\n[link text](url)',
      );
    } catch (e, st) {
      MdEditorDebug.logger.error('Error inserting link', e, st);
    }
  }

  void _insertImage() {
    try {
      final section = controller.selectedSection;
      if (section == null) return;
      controller.updateSectionText(
        section,
        '${section.text}\n![alt text](image-url)',
      );
    } catch (e, st) {
      MdEditorDebug.logger.error('Error inserting image', e, st);
    }
  }

  void _insertHeading(int level) {
    try {
      final prefix = '#' * level;
      controller.insertSection(
        parent: null,
        index: controller.document.sections.length,
        level: level,
        headline: '$prefix New Heading',
      );
    } catch (e, st) {
      MdEditorDebug.logger.error('Error inserting heading', e, st);
    }
  }

  void _insertPrefix(String prefix) {
    try {
      final section = controller.selectedSection;
      if (section == null) return;
      controller.updateSectionText(
        section,
        '${section.text}\n${prefix}item',
      );
    } catch (e, st) {
      MdEditorDebug.logger.error('Error inserting prefix', e, st);
    }
  }

  void _insertCodeBlock() {
    try {
      final section = controller.selectedSection;
      if (section == null) return;
      controller.updateSectionText(
        section,
        '${section.text}\n\n```\ncode here\n```',
      );
    } catch (e, st) {
      MdEditorDebug.logger.error('Error inserting code block', e, st);
    }
  }

  void _insertTable() {
    try {
      final section = controller.selectedSection;
      if (section == null) return;
      const table = '\n| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |';
      controller.updateSectionText(section, '${section.text}$table');
    } catch (e, st) {
      MdEditorDebug.logger.error('Error inserting table', e, st);
    }
  }

  void _insertHorizontalRule() {
    try {
      final section = controller.selectedSection;
      if (section == null) return;
      controller.updateSectionText(section, '${section.text}\n\n---');
    } catch (e, st) {
      MdEditorDebug.logger.error('Error inserting rule', e, st);
    }
  }

  void _addSection() {
    try {
      controller.insertSection(
        parent: null,
        index: controller.document.sections.length,
        level: 1,
        headline: 'New Section',
      );
    } catch (e, st) {
      MdEditorDebug.logger.error('Error adding section', e, st);
    }
  }
}

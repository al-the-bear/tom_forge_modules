import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/md_constants.dart';
import '../../controller/md_editor_controller.dart';
import '../../debug/md_editor_debug.dart';
import '../../models/md_section.dart';
import '../../plugins/md_content_plugin.dart';
import '../../settings/md_editor_settings.dart';
import '../../theme/md_editor_theme.dart';
import 'md_syntax_highlight_controller.dart';

/// Raw text editor panel for editing markdown source.
///
/// Provides line numbers, syntax highlighting, headline marker detection
/// warnings, and live preview updates.
class MdRawTextEditor extends StatefulWidget {
  const MdRawTextEditor({
    super.key,
    required this.controller,
    required this.theme,
    required this.settings,
    this.rawPosition = RawEditorPosition.below,
    this.onTogglePosition,
    this.onShowFullDocument,
    this.pluginRegistry,
  });

  final MdEditorController controller;
  final MdEditorTheme theme;
  final MdEditorSettings settings;
  final RawEditorPosition rawPosition;
  final VoidCallback? onTogglePosition;
  final VoidCallback? onShowFullDocument;

  /// Plugin registry for the insert context menu. If null, no context menu.
  final MdPluginRegistry? pluginRegistry;

  @override
  State<MdRawTextEditor> createState() => _MdRawTextEditorState();
}

class _MdRawTextEditorState extends State<MdRawTextEditor> {
  /// Standard markdown indentation for nested lists (2 spaces).
  static const _indent = '  ';

  late MdSyntaxHighlightController _textController;
  late final FocusNode _focusNode;
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  bool _isUpdating = false;
  bool _headlineWarningDismissed = false;
  bool _isSyncingCursor = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);
    final basic = widget.theme.basic;
    _textController = MdSyntaxHighlightController(
      text: _getEditableText(),
      headingColor: basic.accent,
      boldColor: basic.text,
      italicColor: basic.textSecondary,
      codeColor: basic.success,
      linkColor: basic.linkColor,
      listMarkerColor: basic.textMuted,
      defaultColor: basic.text,
      fontFamily: basic.monoFontFamily,
      fontSize: basic.baseFontSize,
      lineHeight: basic.lineHeight,
    );
    _textController.addListener(_onCursorChanged);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(MdRawTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _syncText();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _textController.removeListener(_onCursorChanged);
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Tab / Shift-Tab indentation handling ──

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.tab) {
      return KeyEventResult.ignored;
    }
    if (widget.settings.readOnly) return KeyEventResult.ignored;

    final isShift = HardwareKeyboard.instance.isShiftPressed;
    if (isShift) {
      _handleUnindent();
    } else {
      _handleIndent();
    }
    return KeyEventResult.handled;
  }

  void _handleIndent() {
    final selection = _textController.selection;
    final text = _textController.text;
    if (!selection.isValid) return;

    if (selection.isCollapsed) {
      // No selection — insert indent at cursor.
      final offset = selection.baseOffset;
      final newText =
          text.substring(0, offset) + _indent + text.substring(offset);
      _textController.value = TextEditingValue(
        text: newText,
        selection:
            TextSelection.collapsed(offset: offset + _indent.length),
      );
    } else {
      // Selection — indent every selected line.
      final start = selection.start;
      final end = selection.end;
      final lineStart =
          start > 0 ? text.lastIndexOf('\n', start - 1) : -1;
      final effectiveStart = lineStart == -1 ? 0 : lineStart + 1;

      final before = text.substring(0, effectiveStart);
      final selectedBlock = text.substring(effectiveStart, end);
      final after = text.substring(end);
      final lines = selectedBlock.split('\n');
      final indented = lines.map((l) => '$_indent$l').join('\n');
      final added = lines.length * _indent.length;

      _textController.value = TextEditingValue(
        text: '$before$indented$after',
        selection: TextSelection(
          baseOffset: start + _indent.length,
          extentOffset: end + added,
        ),
      );
    }
    _onTextChanged(_textController.text);
  }

  void _handleUnindent() {
    final selection = _textController.selection;
    final text = _textController.text;
    if (!selection.isValid) return;

    if (selection.isCollapsed) {
      // No selection — remove leading spaces from current line.
      final offset = selection.baseOffset;
      final lineStart =
          offset > 0 ? text.lastIndexOf('\n', offset - 1) : -1;
      final effectiveStart = lineStart == -1 ? 0 : lineStart + 1;

      int remove = 0;
      for (var i = 0;
          i < _indent.length && effectiveStart + i < text.length;
          i++) {
        if (text[effectiveStart + i] == ' ') {
          remove++;
        } else {
          break;
        }
      }
      if (remove > 0) {
        final newText = text.substring(0, effectiveStart) +
            text.substring(effectiveStart + remove);
        _textController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(
            offset: (offset - remove).clamp(effectiveStart, newText.length),
          ),
        );
        _onTextChanged(_textController.text);
      }
    } else {
      // Selection — unindent every selected line.
      final start = selection.start;
      final end = selection.end;
      final lineStart =
          start > 0 ? text.lastIndexOf('\n', start - 1) : -1;
      final effectiveStart = lineStart == -1 ? 0 : lineStart + 1;

      final before = text.substring(0, effectiveStart);
      final selectedBlock = text.substring(effectiveStart, end);
      final after = text.substring(end);
      final lines = selectedBlock.split('\n');
      int totalRemoved = 0;
      int firstRemoved = 0;
      final unindented = <String>[];

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        int remove = 0;
        for (var j = 0; j < _indent.length && j < line.length; j++) {
          if (line[j] == ' ') {
            remove++;
          } else {
            break;
          }
        }
        unindented.add(line.substring(remove));
        totalRemoved += remove;
        if (i == 0) firstRemoved = remove;
      }

      final newText = '$before${unindented.join('\n')}$after';
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset:
              (start - firstRemoved).clamp(effectiveStart, newText.length),
          extentOffset: (end - totalRemoved).clamp(0, newText.length),
        ),
      );
      _onTextChanged(_textController.text);
    }
  }

  /// Called when the text controller's cursor position changes.
  void _onCursorChanged() {
    if (_isSyncingCursor || _isUpdating) return;
    final selection = _textController.selection;
    if (!selection.isValid) return;

    // Convert the local cursor offset to a global markdown offset.
    final selected = widget.controller.selectedSection;
    int globalOffset;
    if (selected != null) {
      // The raw editor is showing a single section's text.
      // Find that section's position in the full markdown.
      final sectionStart = _findSectionTextStart(selected);
      globalOffset = sectionStart + selection.baseOffset;
    } else {
      globalOffset = selection.baseOffset;
    }
    widget.controller.setCursorOffset(globalOffset, notify: false);
  }

  /// Find the character offset where [section]'s text starts in the full
  /// markdown.
  int _findSectionTextStart(MdSection section) {
    final markdown = widget.controller.markdown;
    final headingPrefix = '${'#' * section.level} ${section.headline}';
    final headingIdx = markdown.indexOf(headingPrefix);
    if (headingIdx < 0) return 0;
    // The text begins after the heading line.
    final afterHeading = markdown.indexOf('\n', headingIdx);
    return afterHeading >= 0 ? afterHeading + 1 : headingIdx;
  }

  void _onControllerChanged() {
    if (!_isUpdating) {
      _syncText();
      _syncCursorFromController();
    }
  }

  /// Sync the raw editor cursor to match the controller's cursorOffset.
  void _syncCursorFromController() {
    // Only sync if this widget doesn't have focus (to avoid fighting
    // with the user's cursor).
    if (_focusNode.hasFocus) return;

    final globalOffset = widget.controller.cursorOffset;
    final selected = widget.controller.selectedSection;
    int localOffset;
    if (selected != null) {
      final sectionStart = _findSectionTextStart(selected);
      localOffset = globalOffset - sectionStart;
    } else {
      localOffset = globalOffset;
    }
    final text = _textController.text;
    localOffset = localOffset.clamp(0, text.length);

    if (_textController.selection.baseOffset != localOffset ||
        _textController.selection.extentOffset != localOffset) {
      _isSyncingCursor = true;
      _textController.selection = TextSelection.collapsed(offset: localOffset);
      _isSyncingCursor = false;
      // Scroll to make cursor visible.
      _scrollToCursorOffset(localOffset);
    }
  }

  /// Scroll the raw editor to make the given local offset visible.
  void _scrollToCursorOffset(int localOffset) {
    if (!_scrollController.hasClients) return;
    final text = _textController.text;
    if (text.isEmpty) return;
    // Estimate position as fraction of text.
    final fraction = localOffset / text.length;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final target = (fraction * maxScroll).clamp(0.0, maxScroll);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  void _syncText() {
    final newText = _getEditableText();
    if (_textController.text != newText) {
      final selection = _textController.selection;
      _textController.text = newText;
      // Try to preserve cursor position.
      if (selection.isValid && selection.end <= newText.length) {
        _textController.selection = selection;
      }
    }
  }

  String _getEditableText() {
    // If a section is selected, show only that section's text.
    final selected = widget.controller.selectedSection;
    if (selected != null) {
      return selected.text;
    }
    return widget.controller.markdown;
  }

  void _onTextChanged(String value) {
    try {
      _debounce?.cancel();
      final ms = widget.settings.livePreviewDebounceMs;
      _debounce = Timer(Duration(milliseconds: ms), () {
        _applyChanges(value);
      });
    } catch (e, st) {
      MdEditorDebug.logger.error('Error in text change handler', e, st);
    }
  }

  void _applyChanges(String value) {
    try {
      _isUpdating = true;
      final selected = widget.controller.selectedSection;
      if (selected != null) {
        widget.controller.updateSectionText(selected, value);
      } else {
        widget.controller.markdown = value;
      }
      _isUpdating = false;
    } catch (e, st) {
      _isUpdating = false;
      MdEditorDebug.logger.error('Error applying changes', e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final basic = widget.theme.basic;
    final selected = widget.controller.selectedSection;

    return Container(
      color: basic.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title bar
          _buildTitleBar(basic, selected),
          // Headline marker warning
          if (_hasHeadlineMarker && !_headlineWarningDismissed)
            _buildHeadlineWarning(basic),
          // Editor area
          Expanded(child: _buildEditor(basic)),
        ],
      ),
    );
  }

  /// Whether the current section text contains headline markers.
  bool get _hasHeadlineMarker {
    final selected = widget.controller.selectedSection;
    if (selected == null) return false;
    return MdConstants.headlineMarkerPattern.hasMatch(selected.text);
  }

  Widget _buildTitleBar(MdBasicTheme basic, MdSection? selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: basic.surfaceVariant,
        border: Border(
          bottom: BorderSide(color: basic.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.code, size: 14, color: basic.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              selected != null
                  ? 'Editing: ${selected.headline}'
                  : 'Raw Markdown',
              style: TextStyle(
                color: basic.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (selected != null)
            InkWell(
              onTap: () => widget.controller.selectSection(null),
              child: Tooltip(
                message: 'Show full document',
                child: Icon(
                  Icons.fullscreen_exit,
                  size: 16,
                  color: basic.textMuted,
                ),
              ),
            ),
          if (selected == null && widget.onShowFullDocument != null)
            InkWell(
              onTap: widget.onShowFullDocument,
              child: Tooltip(
                message: 'Full document',
                child: Icon(
                  Icons.article_outlined,
                  size: 16,
                  color: basic.textMuted,
                ),
              ),
            ),
          if (widget.onTogglePosition != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: widget.onTogglePosition,
              child: Tooltip(
                message: widget.rawPosition == RawEditorPosition.below
                    ? 'Move to right'
                    : 'Move to bottom',
                child: Icon(
                  widget.rawPosition == RawEditorPosition.below
                      ? Icons.vertical_split
                      : Icons.horizontal_split,
                  size: 16,
                  color: basic.textMuted,
                ),
              ),
            ),
          ],
          if (widget.controller.canUndo) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: widget.controller.undo,
              child: Tooltip(
                message: 'Undo',
                child: Icon(Icons.undo, size: 16, color: basic.textMuted),
              ),
            ),
          ],
          if (widget.controller.canRedo) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: widget.controller.redo,
              child: Tooltip(
                message: 'Redo',
                child: Icon(Icons.redo, size: 16, color: basic.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditor(MdBasicTheme basic) {
    try {
      return Scrollbar(
        controller: _scrollController,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Line numbers
            if (widget.settings.showLineNumbers) _buildLineNumbers(basic),
            // Text field with syntax highlighting
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  readOnly: widget.settings.readOnly,
                  maxLines: null,
                  minLines: 10,
                  onChanged: _onTextChanged,
                  contextMenuBuilder: _contextMenuBuilder,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(basic.blockPadding),
                  ),
                  style: TextStyle(
                    fontFamily: basic.monoFontFamily,
                    fontSize: basic.baseFontSize,
                    color: basic.text,
                    height: basic.lineHeight,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e, st) {
      MdEditorDebug.logger.error('Error building editor', e, st);
      return Center(
        child: Text('Editor error', style: TextStyle(color: basic.error)),
      );
    }
  }

  /// Build the context menu for the text field, appending insert actions
  /// from registered plugins and section operations to the default edit
  /// actions.
  Widget _contextMenuBuilder(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final registry = widget.pluginRegistry;
    final defaultItems = editableTextState.contextMenuButtonItems;

    if (widget.settings.readOnly) {
      return AdaptiveTextSelectionToolbar.buttonItems(
        anchors: editableTextState.contextMenuAnchors,
        buttonItems: defaultItems,
      );
    }

    final basic = widget.theme.basic;
    final extraItems = <ContextMenuButtonItem>[];

    // Plugin insert items.
    if (registry != null) {
      for (final plugin in registry.insertable) {
        extraItems.add(ContextMenuButtonItem(
          label: 'Insert ${plugin.displayName}',
          onPressed: () {
            ContextMenuController.removeAny();
            if (plugin.id == 'code') {
              _showLanguagePicker(Offset.zero, basic);
            } else {
              _insertContent(plugin.insertTemplate);
            }
          },
        ));
      }
    }

    // Section insertion items.
    final selected = widget.controller.selectedSection;
    if (selected != null) {
      extraItems.addAll([
        ContextMenuButtonItem(
          label: 'Insert Section Here',
          onPressed: () {
            ContextMenuController.removeAny();
            _showSectionInsertDialog(
              mode: _SectionInsertMode.sameHere,
              section: selected,
            );
          },
        ),
        ContextMenuButtonItem(
          label: 'Insert Section Below',
          onPressed: () {
            ContextMenuController.removeAny();
            _showSectionInsertDialog(
              mode: _SectionInsertMode.sameBelow,
              section: selected,
            );
          },
        ),
        ContextMenuButtonItem(
          label: 'Insert Subsection Here',
          onPressed: () {
            ContextMenuController.removeAny();
            _showSectionInsertDialog(
              mode: _SectionInsertMode.subHere,
              section: selected,
            );
          },
        ),
        ContextMenuButtonItem(
          label: 'Insert Subsection Below',
          onPressed: () {
            ContextMenuController.removeAny();
            _showSectionInsertDialog(
              mode: _SectionInsertMode.subBelow,
              section: selected,
            );
          },
        ),
      ]);
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: [...defaultItems, ...extraItems],
    );
  }

  /// Show a dialog to create a new section, then insert it based on [mode].
  Future<void> _showSectionInsertDialog({
    required _SectionInsertMode mode,
    required MdSection section,
  }) async {
    final headlineController = TextEditingController();
    final idController = TextEditingController();
    final isSubsection =
        mode == _SectionInsertMode.subHere ||
        mode == _SectionInsertMode.subBelow;
    final label = isSubsection ? 'Subsection' : 'Section';

    final confirmed = await showDialog<bool>(
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
    if (confirmed != true || headline.isEmpty) return;

    final effectiveId = id.isEmpty ? null : id;
    final level =
        isSubsection ? (section.level + 1).clamp(1, 6) : section.level;

    switch (mode) {
      case _SectionInsertMode.sameHere:
      case _SectionInsertMode.subHere:
        // Split the current section at cursor position and insert the new
        // section between the two halves.
        final cursorPos = _textController.selection.isValid
            ? _textController.selection.baseOffset
            : _textController.text.length;
        final text = _textController.text;
        final before = text.substring(0, cursorPos).trimRight();
        final after = text.substring(cursorPos).trimLeft();

        // Update the current section's text to only contain the "before" part.
        widget.controller.updateSectionText(section, before);
        // Insert new section after current section with the "after" text as
        // body of the new section.
        await widget.controller.addSectionAfter(
          afterSection: section,
          level: level,
          headline: headline,
          id: effectiveId,
          text: after,
        );

      case _SectionInsertMode.sameBelow:
      case _SectionInsertMode.subBelow:
        if (isSubsection) {
          await widget.controller.insertSection(
            parent: section,
            index: section.subsections.length,
            level: level,
            headline: headline,
            id: effectiveId,
          );
        } else {
          await widget.controller.addSectionAfter(
            afterSection: section,
            level: level,
            headline: headline,
            id: effectiveId,
          );
        }
    }
  }

  /// Common languages offered in the code block language picker.
  static const _commonLanguages = [
    '',
    'dart',
    'yaml',
    'json',
    'javascript',
    'typescript',
    'python',
    'c',
    'cpp',
    'java',
    'kotlin',
    'swift',
    'rust',
    'go',
    'ruby',
    'php',
    'html',
    'css',
    'sql',
    'bash',
    'markdown',
    'xml',
  ];

  /// Show a language picker for code block insertion.
  void _showLanguagePicker(Offset position, MdBasicTheme basic) {
    final controller = TextEditingController();
    showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final filter = controller.text.toLowerCase();
            final filtered = _commonLanguages.where((lang) {
              if (filter.isEmpty) return true;
              return lang.contains(filter);
            }).toList();
            // If the typed text doesn't match any common language, show it as
            // a custom option.
            final hasExactMatch = _commonLanguages.contains(filter);
            return AlertDialog(
              backgroundColor: basic.surface,
              title: Text(
                'Select Language',
                style: TextStyle(color: basic.text, fontSize: 16),
              ),
              content: SizedBox(
                width: 280,
                height: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      style: TextStyle(color: basic.text),
                      decoration: InputDecoration(
                        hintText: 'Type or select language...',
                        hintStyle: TextStyle(color: basic.textMuted),
                        prefixIcon: Icon(
                          Icons.search,
                          color: basic.textMuted,
                          size: 18,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            basic.borderRadius,
                          ),
                        ),
                        isDense: true,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                      onSubmitted: (value) {
                        Navigator.of(ctx).pop(value.trim());
                      },
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: [
                          if (filter.isNotEmpty && !hasExactMatch)
                            _buildLanguageTile(
                              ctx,
                              basic,
                              filter,
                              isCustom: true,
                            ),
                          for (final lang in filtered)
                            _buildLanguageTile(ctx, basic, lang),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((language) {
      if (language != null) {
        final lang = language.isEmpty ? '' : language;
        _insertContent('```$lang\n\n```');
      }
    });
  }

  Widget _buildLanguageTile(
    BuildContext ctx,
    MdBasicTheme basic,
    String language, {
    bool isCustom = false,
  }) {
    final label = language.isEmpty ? '(no language)' : language;
    return ListTile(
      dense: true,
      title: Text(
        isCustom ? '"$language" (custom)' : label,
        style: TextStyle(
          color: basic.text,
          fontStyle: language.isEmpty ? FontStyle.italic : FontStyle.normal,
        ),
      ),
      leading: Icon(
        isCustom ? Icons.add : Icons.code,
        size: 16,
        color: basic.textSecondary,
      ),
      onTap: () => Navigator.of(ctx).pop(language),
    );
  }

  /// Insert markdown content at the current cursor position in the raw editor.
  void _insertContent(String template) {
    final text = _textController.text;
    final selection = _textController.selection;
    final offset = selection.isValid ? selection.baseOffset : text.length;

    // Build the inserted text with surrounding newlines.
    final before = text.substring(0, offset);
    final after = text.substring(offset);
    final separator = before.isEmpty || before.endsWith('\n') ? '' : '\n';
    final trailing = after.isEmpty || after.startsWith('\n') ? '' : '\n';
    final newText = '$before$separator$template$trailing$after';

    _isUpdating = true;
    _textController.text = newText;
    // Place cursor at end of inserted template.
    final newOffset = before.length + separator.length + template.length;
    _textController.selection = TextSelection.collapsed(offset: newOffset);
    _isUpdating = false;

    _applyChanges(newText);
  }

  /// Warning banner shown when section text contains headline markers.
  Widget _buildHeadlineWarning(MdBasicTheme basic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: basic.warning.withAlpha(30),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: basic.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Section text contains headline markers (# ). '
              'These may create unintended subsections.',
              style: TextStyle(color: basic.warning, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _buildWarningAction(
            basic,
            'Insert Section',
            Icons.add,
            _insertSectionFromMarker,
          ),
          const SizedBox(width: 4),
          _buildWarningAction(
            basic,
            'Escape',
            Icons.code,
            _escapeHeadlineMarker,
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => setState(() => _headlineWarningDismissed = true),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 14, color: basic.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningAction(
    MdBasicTheme basic,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: basic.border, width: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: basic.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: basic.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  /// Insert a new section below the current one from the detected marker.
  void _insertSectionFromMarker() {
    try {
      final selected = widget.controller.selectedSection;
      if (selected == null) return;

      final match = MdConstants.headlineMarkerPattern
          .firstMatch(selected.text);
      if (match == null) return;

      // Extract the headline text after the marker
      final markerLine = selected.text.substring(match.start, match.end);
      final level = markerLine.indexOf(' ');
      final lineEnd = selected.text.indexOf('\n', match.start);
      final headlineText = lineEnd > 0
          ? selected.text.substring(match.end, lineEnd).trim()
          : selected.text.substring(match.end).trim();

      // Remove the marker line from original section text
      final beforeMarker = selected.text.substring(0, match.start);
      final afterLine = lineEnd > 0
          ? selected.text.substring(lineEnd + 1)
          : '';
      widget.controller.updateSectionText(
        selected,
        beforeMarker.trimRight(),
      );

      // Add new section after current
      widget.controller.addSectionAfter(
        afterSection: selected,
        level: level.clamp(1, 6),
        headline: headlineText.isNotEmpty ? headlineText : 'New Section',
        text: afterLine,
      );

      setState(() => _headlineWarningDismissed = false);
    } catch (e, st) {
      MdEditorDebug.logger.error('Error inserting section from marker', e, st);
    }
  }

  /// Escape headline markers by prefixing with backslash.
  void _escapeHeadlineMarker() {
    try {
      final selected = widget.controller.selectedSection;
      if (selected == null) return;

      final escaped = selected.text.replaceAllMapped(
        MdConstants.headlineMarkerPattern,
        (m) => '\\${m.group(0)}',
      );
      widget.controller.updateSectionText(selected, escaped);
      setState(() => _headlineWarningDismissed = false);
    } catch (e, st) {
      MdEditorDebug.logger.error('Error escaping headline marker', e, st);
    }
  }

  Widget _buildLineNumbers(MdBasicTheme basic) {
    final lineCount = _textController.text.split('\n').length;
    return Container(
      width: 48,
      color: basic.surfaceVariant,
      padding: EdgeInsets.only(
        top: basic.blockPadding,
        right: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(
          lineCount,
          (i) => SizedBox(
            height: basic.baseFontSize * basic.lineHeight,
            child: Text(
              '${i + 1}',
              style: TextStyle(
                fontFamily: basic.monoFontFamily,
                fontSize: basic.baseFontSize,
                color: basic.textMuted,
                height: basic.lineHeight,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ),
      ),
    );
  }
}

enum _SectionInsertMode { sameHere, sameBelow, subHere, subBelow }

import 'dart:async';

import 'package:flutter/material.dart';

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
  late MdSyntaxHighlightController _textController;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  bool _isUpdating = false;
  bool _headlineWarningDismissed = false;
  bool _isSyncingCursor = false;

  @override
  void initState() {
    super.initState();
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
      return GestureDetector(
        onSecondaryTapUp: !widget.settings.readOnly &&
                widget.pluginRegistry != null
            ? (details) => _showInsertMenu(details.globalPosition)
            : null,
        child: Scrollbar(
          controller: _scrollController,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Line numbers
              if (widget.settings.showLineNumbers)
                _buildLineNumbers(basic),
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
        ),
      );
    } catch (e, st) {
      MdEditorDebug.logger.error('Error building editor', e, st);
      return Center(
        child: Text('Editor error', style: TextStyle(color: basic.error)),
      );
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

  /// Show a context menu for inserting content blocks at cursor position.
  void _showInsertMenu(Offset position) {
    final registry = widget.pluginRegistry;
    if (registry == null) return;
    final insertable = registry.insertable;
    if (insertable.isEmpty) return;

    final basic = widget.theme.basic;
    showMenu<MdContentPlugin>(
      context: context,
      color: basic.surface,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: insertable.map((plugin) {
        return PopupMenuItem<MdContentPlugin>(
          value: plugin,
          child: Row(
            children: [
              Icon(plugin.icon, size: 18, color: basic.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Insert ${plugin.displayName}',
                style: TextStyle(color: basic.text),
              ),
            ],
          ),
        );
      }).toList(),
    ).then((plugin) {
      if (plugin != null) {
        if (plugin.id == 'code') {
          _showLanguagePicker(position, basic);
        } else {
          _insertContent(plugin.insertTemplate);
        }
      }
    });
  }

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

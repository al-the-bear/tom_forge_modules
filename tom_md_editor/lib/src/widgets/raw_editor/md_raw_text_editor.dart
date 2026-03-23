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
import '../../validation/schema_section_helper.dart';
import '../../validation/schema_template_helper.dart';
import '../schema/md_char_counter.dart';
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

  /// When true the raw editor shows the section's heading line (including
  /// HTML comment metadata) instead of the body text.
  bool _editingHeadline = false;

  /// Track the selected section to reset [_editingHeadline] on change.
  MdSection? _lastSelectedSection;

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
    // Recreate syntax controller when the theme changes so that
    // highlight colors match the new dark/light palette.
    if (oldWidget.theme != widget.theme) {
      _rebuildSyntaxController();
    }
  }

  void _rebuildSyntaxController() {
    final basic = widget.theme.basic;
    final oldSelection = _textController.selection;
    final oldText = _textController.text;
    _textController.removeListener(_onCursorChanged);
    _textController.dispose();
    _textController = MdSyntaxHighlightController(
      text: oldText,
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
    // Restore cursor position.
    if (oldSelection.isValid &&
        oldSelection.end <= oldText.length) {
      _textController.selection = oldSelection;
    }
    _textController.addListener(_onCursorChanged);
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
      // Reset headline editing mode when a truly different section is
      // selected.  After _rebuildMarkdown() the controller creates new
      // MdSection objects, so compare by headline + level instead of
      // identity to avoid resetting on every notification.
      final current = widget.controller.selectedSection;
      final sectionChanged = !_isSameSection(current, _lastSelectedSection);
      if (sectionChanged) {
        _editingHeadline = false;
      }
      _lastSelectedSection = current;
      _syncText(resetCursor: sectionChanged);
      if (sectionChanged) {
        // Flutter's EditableText schedules _showCaretOnScreen as a
        // post-frame callback whenever the selection or text changes.
        // That callback reads the current caret rect after layout and
        // calls ensureVisible → animateTo, overriding any jumpTo we
        // do synchronously here.  Schedule our own post-frame reset
        // so it runs AFTER Flutter's internal caret scrolling by
        // nesting a second post-frame callback.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(0);
            }
          });
        });
      } else {
        _syncCursorFromController();
      }
    }
  }

  /// Compare two sections by content rather than identity.
  static bool _isSameSection(MdSection? a, MdSection? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a.headline == b.headline && a.level == b.level;
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

  void _syncText({bool resetCursor = false}) {
    final newText = _getEditableText();
    if (_textController.text != newText) {
      // Suppress the debounced _applyChanges that would otherwise fire
      // from the TextField.onChanged callback.  Programmatic text updates
      // should not trigger a round-trip through updateSectionText.
      _isUpdating = true;
      final selection = _textController.selection;
      _textController.text = newText;
      // Cancel the debounce AFTER setting text — the setter synchronously
      // fires TextField.onChanged which creates a new debounce timer.
      _debounce?.cancel();
      if (resetCursor) {
        // On section change, place cursor at the start so Flutter's
        // internal _showCaretOnScreen scrolls to the top, not the end.
        _textController.selection =
            const TextSelection.collapsed(offset: 0);
      } else if (selection.isValid && selection.end <= newText.length) {
        // Same-section update: try to preserve cursor position.
        _textController.selection = selection;
      }
      _isUpdating = false;
    }
  }

  String _getEditableText() {
    // If a section is selected, show only that section's text.
    final selected = widget.controller.selectedSection;
    if (selected != null) {
      if (_editingHeadline) {
        return _getRawHeadingLine(selected);
      }
      return selected.text;
    }
    return widget.controller.markdown;
  }

  /// Extract the original heading line from the source markdown using
  /// the section's [sourceLineStart].  Falls back to the reconstructed
  /// heading when line info is unavailable.
  String _getRawHeadingLine(MdSection section) {
    final lineStart = section.sourceLineStart;
    if (lineStart != null) {
      final lines = widget.controller.markdown.split('\n');
      if (lineStart < lines.length) {
        return lines[lineStart];
      }
    }
    return section.toHeadlineMarkdown();
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
        if (_editingHeadline) {
          _applyHeadlineChanges(selected, value);
        } else {
          widget.controller.updateSectionText(selected, value);
        }
      } else {
        widget.controller.markdown = value;
      }
      _isUpdating = false;
    } catch (e, st) {
      _isUpdating = false;
      MdEditorDebug.logger.error('Error applying changes', e, st);
    }
  }

  /// Replace the heading line in the source markdown with the edited text.
  void _applyHeadlineChanges(MdSection section, String editedLine) {
    final lineStart = section.sourceLineStart;
    if (lineStart == null) return;
    final md = widget.controller.markdown;
    final lines = md.split('\n');
    if (lineStart >= lines.length) return;
    lines[lineStart] = editedLine;
    widget.controller.markdown = lines.join('\n');
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

  /// Build a compact character counter for the selected section.
  Widget _buildCharCounter(MdSection section) {
    final schema = widget.controller.schema;
    if (schema == null || !widget.settings.showCharCounter) {
      return const SizedBox.shrink();
    }

    final helper = SchemaSectionHelper(schema);
    final tmpl = SchemaTemplateHelper(schema);
    final typeName = helper.getSectionTypeName(
      section,
      document: widget.controller.document,
    );
    if (typeName == null) return const SizedBox.shrink();

    final constraints = tmpl.getTextConstraints(typeName);
    if (constraints.min == null &&
        constraints.max == null &&
        !constraints.required) {
      return const SizedBox.shrink();
    }

    return MdCharCounter(
      currentLength: section.text.length,
      minLength: constraints.min,
      maxLength: constraints.max,
      textRequired: constraints.required,
      theme: widget.theme,
    );
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
            child: selected != null
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        _editingHeadline = !_editingHeadline;
                        _syncText();
                      });
                    },
                    child: Tooltip(
                      message: _editingHeadline
                          ? 'Click to edit section text'
                          : 'Click to edit heading',
                      child: Text(
                        _editingHeadline
                            ? 'Heading: ${selected.headline}'
                            : 'Editing: ${selected.headline}',
                        style: TextStyle(
                          color: _editingHeadline
                              ? basic.accent
                              : basic.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                          decorationStyle: TextDecorationStyle.dotted,
                          decorationColor: basic.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                : Text(
                    'Raw Markdown',
                    style: TextStyle(
                      color: basic.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          if (selected != null) _buildCharCounter(selected),
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

    // Collect prefix suggestions from schema section types.
    final schema = widget.controller.schema;
    final prefixSuggestions = <String>[];
    if (schema != null) {
      for (final entry in schema.sectionTypes.entries) {
        final prefix = entry.value.prefix;
        if (prefix != null && prefix.isNotEmpty) {
          prefixSuggestions.add(prefix);
        }
      }
    }

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
            if (prefixSuggestions.isNotEmpty)
              Autocomplete<String>(
                optionsBuilder: (textEditingValue) {
                  final query = textEditingValue.text.toLowerCase();
                  if (query.isEmpty) return prefixSuggestions;
                  return prefixSuggestions.where(
                    (s) => s.toLowerCase().contains(query),
                  );
                },
                fieldViewBuilder: (ctx, controller, focusNode, onSubmit) {
                  controller.text = idController.text;
                  controller.addListener(() {
                    idController.text = controller.text;
                  });
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'ID (optional)',
                      hintText: 'e.g. my-section-id',
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
  ///
  /// When the current section has a schema type with `format: code lang1|lang2`,
  /// the allowed languages are promoted to the top and others are shown in a
  /// separate "Other" group. The user can always type a custom language.
  void _showLanguagePicker(Offset position, MdBasicTheme basic) {
    // Determine schema-allowed languages for the selected section.
    List<String> schemaLanguages = const [];
    final schema = widget.controller.schema;
    final selected = widget.controller.selectedSection;
    if (schema != null && selected != null) {
      final sectionHelper = SchemaSectionHelper(schema);
      final typeName = sectionHelper.getSectionTypeName(
        selected,
        document: widget.controller.document,
      );
      if (typeName != null) {
        final tmplHelper = SchemaTemplateHelper(schema);
        schemaLanguages = tmplHelper.getCodeLanguages(typeName);
      }
    }
    final hasSchemaFilter = schemaLanguages.isNotEmpty;

    final controller = TextEditingController();
    showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final filter = controller.text.toLowerCase();

            // Build the primary list: schema languages first if available.
            List<String> primaryLanguages;
            List<String> otherLanguages;
            if (hasSchemaFilter) {
              primaryLanguages = schemaLanguages.where((lang) {
                if (filter.isEmpty) return true;
                return lang.toLowerCase().contains(filter);
              }).toList();
              otherLanguages = _commonLanguages.where((lang) {
                if (schemaLanguages.contains(lang)) return false;
                if (filter.isEmpty) return true;
                return lang.contains(filter);
              }).toList();
            } else {
              primaryLanguages = _commonLanguages.where((lang) {
                if (filter.isEmpty) return true;
                return lang.contains(filter);
              }).toList();
              otherLanguages = const [];
            }

            final hasExactMatch =
                _commonLanguages.contains(filter) ||
                schemaLanguages.contains(filter);

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
                          for (final lang in primaryLanguages)
                            _buildLanguageTile(ctx, basic, lang),
                          if (hasSchemaFilter &&
                              otherLanguages.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 8,
                                bottom: 4,
                                left: 16,
                              ),
                              child: Text(
                                'Other languages',
                                style: TextStyle(
                                  color: basic.textMuted,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            for (final lang in otherLanguages)
                              _buildLanguageTile(
                                ctx,
                                basic,
                                lang,
                                isOther: true,
                              ),
                          ],
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
    bool isOther = false,
  }) {
    final label = language.isEmpty ? '(no language)' : language;
    return ListTile(
      dense: true,
      title: Text(
        isCustom ? '"$language" (custom)' : label,
        style: TextStyle(
          color: isOther ? basic.textMuted : basic.text,
          fontStyle: language.isEmpty ? FontStyle.italic : FontStyle.normal,
        ),
      ),
      leading: Icon(
        isCustom ? Icons.add : Icons.code,
        size: 16,
        color: isOther ? basic.textMuted : basic.textSecondary,
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

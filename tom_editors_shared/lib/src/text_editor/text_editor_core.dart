import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_text_highlight/tom_text_highlight.dart';

import '../text_editing/forge_editor_integration.dart';
import '../text_editing/history/forge_editor_owns_undo.dart';
import '../text_editing/standard_editing_actions.dart';
import 'text_editor_theme.dart';
import 'text_marker.dart';

/// A code editor widget with syntax highlighting, line numbers,
/// and inline error/warning markers.
///
/// This is a shared foundation widget — format-specific behavior is
/// injected via [SyntaxHighlighter] and [TextMarker] lists.
///
/// ```dart
/// TextEditorCore(
///   text: yamlContent,
///   highlighter: YamlSyntaxHighlighter(),
///   markers: schemaErrors,
///   onTextChanged: (newText) => controller.setYaml(newText),
///   readOnly: false,
/// )
/// ```
class TextEditorCore extends StatefulWidget {
  /// The text content to display.
  final String text;

  /// Syntax highlighter for the text content.
  final SyntaxHighlighter? highlighter;

  /// Error/warning markers to render as underlines.
  final List<TextMarker> markers;

  /// Callback when text is edited by the user.
  final ValueChanged<String>? onTextChanged;

  /// Whether the editor is read-only.
  final bool readOnly;

  /// Visual theme.
  final TextEditorTheme theme;

  /// Initial cursor offset.
  final int? initialCursorOffset;

  /// Optional editor integration for line-editing action dispatch.
  ///
  /// When provided, the widget registers standard line-editing handlers
  /// (delete line, duplicate line, move line up/down, toggle comment) so
  /// that shortcut-driven dispatch operates on the internal controller.
  final ForgeEditorIntegration? integration;

  /// Comment prefix used by the toggle-comment action.
  ///
  /// Defaults to `# ` (YAML-style). Callers may pass a different prefix
  /// for other languages.
  final String commentPrefix;

  /// Callback when the text selection changes.
  final ValueChanged<TextSelection>? onSelectionChanged;

  /// Called on every change of the text or the selection, with both — for a
  /// host that keeps the document's history and must tell typing from a
  /// caret move.
  final ValueChanged<TextEditingValue>? onValueChanged;

  /// Whether the host keeps the document's history (the default): Flutter's
  /// own text undo is then off ([ForgeEditorOwnsUndo]). A host editing a
  /// scratch draft with no history of its own passes false and keeps it.
  final bool hostOwnsUndo;

  /// The selection to show with [text] when the text arrives from outside
  /// (an undo restoring the caret); null keeps the caret where it was.
  final TextSelection? selection;

  const TextEditorCore({
    super.key,
    required this.text,
    this.highlighter,
    this.markers = const [],
    this.onTextChanged,
    this.onSelectionChanged,
    this.onValueChanged,
    this.selection,
    this.hostOwnsUndo = true,
    this.readOnly = false,
    this.theme = const TextEditorTheme(),
    this.initialCursorOffset,
    this.integration,
    this.commentPrefix = '# ',
  });

  @override
  State<TextEditorCore> createState() => _TextEditorCoreState();
}

class _TextEditorCoreState extends State<TextEditorCore> {
  late _HighlightedTextController _textController;
  late FocusNode _focusNode;
  int _currentLine = 0;

  @override
  void initState() {
    super.initState();
    _textController = _HighlightedTextController(
      text: widget.text,
      baseStyle: widget.theme.textStyle,
      highlighter: widget.highlighter,
      markers: widget.markers,
    );
    _focusNode = FocusNode();
    _textController.addListener(_onTextChanged);

    if (widget.initialCursorOffset != null) {
      _textController.selection = TextSelection.collapsed(
        offset: widget.initialCursorOffset!,
      );
    }

    _registerLineEditingActions();
  }

  // ── Line editing actions ──────────────────────────────────────────────

  void _registerLineEditingActions() {
    final integration = widget.integration;
    if (integration == null) return;

    bool isEditable() => !widget.readOnly;
    bool hasNonCollapsedSelection() =>
        _textController.selection.isValid &&
        !_textController.selection.isCollapsed;

    // ── Clipboard actions ──

    integration.registerAction(
      StandardEditingActions.cutActionId,
      _doCut,
      isEnabled: () => isEditable() && hasNonCollapsedSelection(),
    );
    integration.registerAction(
      StandardEditingActions.copyActionId,
      _doCopy,
      isEnabled: hasNonCollapsedSelection,
    );
    integration.registerAction(
      StandardEditingActions.pasteActionId,
      _doPaste,
      isEnabled: isEditable,
    );
    integration.registerAction(
      StandardEditingActions.selectAllActionId,
      _doSelectAll,
      isEnabled: () => _textController.text.isNotEmpty,
    );

    // ── Line editing actions ──

    integration.registerAction(
      StandardEditingActions.deleteLineActionId,
      _doDeleteLine,
      isEnabled: isEditable,
    );
    integration.registerAction(
      StandardEditingActions.duplicateLineActionId,
      _doDuplicateLine,
      isEnabled: isEditable,
    );
    integration.registerAction(
      StandardEditingActions.moveLineUpActionId,
      _doMoveLineUp,
      isEnabled: isEditable,
    );
    integration.registerAction(
      StandardEditingActions.moveLineDownActionId,
      _doMoveLineDown,
      isEnabled: isEditable,
    );
    integration.registerAction(
      StandardEditingActions.toggleCommentActionId,
      _doToggleComment,
      isEnabled: isEditable,
    );
  }

  ({int start, int end}) _getLineRange(String text, int offset) {
    final clamped = offset.clamp(0, text.length);
    int start = clamped;
    while (start > 0 && text[start - 1] != '\n') {
      start--;
    }
    int end = clamped;
    while (end < text.length && text[end] != '\n') {
      end++;
    }
    return (start: start, end: end);
  }

  void _doDeleteLine() {
    final text = _textController.text;
    final cursor = _textController.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) return;

    final lineRange = _getLineRange(text, cursor);
    int deleteStart = lineRange.start;
    int deleteEnd = lineRange.end;
    if (deleteEnd < text.length && text[deleteEnd] == '\n') {
      deleteEnd++;
    } else if (deleteStart > 0 && text[deleteStart - 1] == '\n') {
      deleteStart--;
    }

    final newText = text.substring(0, deleteStart) + text.substring(deleteEnd);
    _textController.text = newText;
    _textController.selection = TextSelection.collapsed(
      offset: deleteStart.clamp(0, newText.length),
    );
  }

  void _doDuplicateLine() {
    final text = _textController.text;
    final cursor = _textController.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) return;

    final lineRange = _getLineRange(text, cursor);
    final line = text.substring(lineRange.start, lineRange.end);
    final columnOffset = cursor - lineRange.start;

    final newText =
        '${text.substring(0, lineRange.end)}\n$line${text.substring(lineRange.end)}';
    _textController.text = newText;
    _textController.selection = TextSelection.collapsed(
      offset: (lineRange.end + 1 + columnOffset).clamp(0, newText.length),
    );
  }

  void _doMoveLineUp() {
    final text = _textController.text;
    final cursor = _textController.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) return;

    final currentRange = _getLineRange(text, cursor);
    if (currentRange.start == 0) return;

    final prevRange = _getLineRange(text, currentRange.start - 1);
    final currentLine = text.substring(currentRange.start, currentRange.end);
    final prevLine = text.substring(prevRange.start, prevRange.end);
    final columnOffset = cursor - currentRange.start;

    final newText =
        '${text.substring(0, prevRange.start)}$currentLine\n$prevLine${text.substring(currentRange.end)}';
    _textController.text = newText;
    _textController.selection = TextSelection.collapsed(
      offset: (prevRange.start + columnOffset).clamp(0, newText.length),
    );
  }

  void _doMoveLineDown() {
    final text = _textController.text;
    final cursor = _textController.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) return;

    final currentRange = _getLineRange(text, cursor);
    if (currentRange.end >= text.length) return;

    final nextRange = _getLineRange(text, currentRange.end + 1);
    final currentLine = text.substring(currentRange.start, currentRange.end);
    final nextLine = text.substring(nextRange.start, nextRange.end);
    final columnOffset = cursor - currentRange.start;

    final newText =
        '${text.substring(0, currentRange.start)}$nextLine\n$currentLine${text.substring(nextRange.end)}';
    _textController.text = newText;
    _textController.selection = TextSelection.collapsed(
      offset: (currentRange.start + nextLine.length + 1 + columnOffset)
          .clamp(0, newText.length),
    );
  }

  void _doToggleComment() {
    final text = _textController.text;
    final cursor = _textController.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) return;

    final prefix = widget.commentPrefix;
    final lineRange = _getLineRange(text, cursor);
    final line = text.substring(lineRange.start, lineRange.end);
    final trimmed = line.trimLeft();
    final indent = line.length - trimmed.length;

    String newLine;
    if (trimmed.startsWith(prefix)) {
      newLine = line.substring(0, indent) + trimmed.substring(prefix.length);
    } else if (prefix.endsWith(' ') && trimmed.startsWith(prefix.trimRight())) {
      newLine = line.substring(0, indent) +
          trimmed.substring(prefix.trimRight().length);
    } else {
      newLine = '${line.substring(0, indent)}$prefix$trimmed';
    }

    final newText = text.substring(0, lineRange.start) +
        newLine +
        text.substring(lineRange.end);
    final cursorDelta = newLine.length - line.length;

    _textController.text = newText;
    _textController.selection = TextSelection.collapsed(
      offset: (cursor + cursorDelta).clamp(0, newText.length),
    );
  }

  // ── Clipboard actions ──

  void _doCut() {
    final sel = _textController.selection;
    if (!sel.isValid || sel.isCollapsed) return;
    final text = _textController.text;
    final selected = sel.textInside(text);
    Clipboard.setData(ClipboardData(text: selected));
    _textController.text = sel.textBefore(text) + sel.textAfter(text);
    _textController.selection = TextSelection.collapsed(offset: sel.start);
  }

  void _doCopy() {
    final sel = _textController.selection;
    if (!sel.isValid || sel.isCollapsed) return;
    final selected = sel.textInside(_textController.text);
    Clipboard.setData(ClipboardData(text: selected));
  }

  void _doPaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    final sel = _textController.selection;
    final text = _textController.text;
    final newText = sel.textBefore(text) + data!.text! + sel.textAfter(text);
    _textController.text = newText;
    _textController.selection = TextSelection.collapsed(
      offset: sel.start + data.text!.length,
    );
  }

  void _doSelectAll() {
    _textController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _textController.text.length,
    );
  }

  @override
  void didUpdateWidget(TextEditorCore oldWidget) {
    super.didUpdateWidget(oldWidget);
    _textController.baseStyle = widget.theme.textStyle;
    _textController.highlighter = widget.highlighter;
    _textController.markers = widget.markers;

    if (oldWidget.text != widget.text && widget.text != _textController.text) {
      // The text arrived from outside: show it with the host's selection, or
      // keep the caret where it was. The host hears nothing of it.
      final selection = widget.selection;
      final offset = _textController.selection.baseOffset;
      _textController.removeListener(_onTextChanged);
      _textController.value = TextEditingValue(
        text: widget.text,
        selection: selection != null && selection.end <= widget.text.length
            ? selection
            : TextSelection.collapsed(
                offset: offset.clamp(0, widget.text.length),
              ),
      );
      _textController.addListener(_onTextChanged);
    }

    if (oldWidget.highlighter != widget.highlighter ||
        oldWidget.markers != widget.markers ||
        oldWidget.theme.textStyle != widget.theme.textStyle) {
      _textController.refreshHighlighting();
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // Update current line tracking
    var text = _textController.text;
    final selection = _textController.selection;
    var offset = selection.baseOffset;
    _currentLine = _lineAtOffset(text, offset);

    widget.onSelectionChanged?.call(selection);
    widget.onValueChanged?.call(_textController.value);

    if (text != widget.text) {
      widget.onTextChanged?.call(text);
    }
  }

  int _lineAtOffset(String text, int offset) {
    if (offset <= 0) return 0;
    var clamped = offset.clamp(0, text.length);
    return '\n'.allMatches(text.substring(0, clamped)).length;
  }

  @override
  Widget build(BuildContext context) {
    var lineCount = '\n'.allMatches(widget.text).length + 1;

    return Container(
      color: widget.theme.background,
      child: SingleChildScrollView(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gutter (line numbers)
              if (widget.theme.showLineNumbers) _buildGutter(lineCount),

              // Separator
              if (widget.theme.showLineNumbers)
                Container(
                  width: 1,
                  color: widget.theme.gutterBorderColor,
                ),

              // Main text area
              Expanded(
                child: _buildTextArea(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGutter(int lineCount) {
    return Container(
      width: widget.theme.gutterWidth,
      color: widget.theme.gutterBackground,
      padding: widget.theme.contentPadding.copyWith(left: 0, right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < lineCount; i++)
            SizedBox(
              height: _lineHeight,
              child: Text(
                '${i + 1}',
                style: (i == _currentLine &&
                        widget.theme.showCurrentLineHighlight)
                    ? widget.theme.lineNumberStyle.copyWith(
                        color:
                            widget.theme.lineNumberStyle.color?.withAlpha(255),
                      )
                    : widget.theme.lineNumberStyle,
                textAlign: TextAlign.right,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextArea() {
    final field = TextField(
      controller: _textController,
      focusNode: _focusNode,
      style: widget.theme.textStyle,
      cursorColor: Colors.white,
      maxLines: null,
      readOnly: widget.readOnly,
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        isDense: true,
      ),
      strutStyle: StrutStyle.fromTextStyle(widget.theme.textStyle),
      // TextField provides mouse selection, context menu, and Ctrl+C/V/A
      // automatically — unlike EditableText which is lower-level.
      enableInteractiveSelection: true,
      contextMenuBuilder: (context, editableTextState) {
        return AdaptiveTextSelectionToolbar.editableText(
          editableTextState: editableTextState,
        );
      },
    );
    return Padding(
      padding: widget.theme.contentPadding,
      // A host that keeps the history turns Flutter's own text undo off.
      child: widget.hostOwnsUndo ? ForgeEditorOwnsUndo(child: field) : field,
    );
  }

  double get _lineHeight =>
      (widget.theme.textStyle.fontSize ?? 13) *
      (widget.theme.textStyle.height ?? 1.4);
}

class _HighlightedTextController extends TextEditingController {
  _HighlightedTextController({
    required super.text,
    required this.baseStyle,
    this.highlighter,
    this.markers = const [],
  });

  TextStyle baseStyle;
  SyntaxHighlighter? highlighter;
  List<TextMarker> markers;

  void refreshHighlighting() {
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final source = text;
    final effectiveBase = baseStyle.merge(style);
    if (source.isEmpty) {
      return TextSpan(style: effectiveBase, text: source);
    }

    if (highlighter == null && markers.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: effectiveBase,
        withComposing: withComposing,
      );
    }

    final length = source.length;
    final styles =
        List<TextStyle>.filled(length, effectiveBase, growable: false);

    final spans = highlighter?.highlight(source) ?? const <HighlightSpan>[];
    for (final span in spans) {
      final start = span.start.clamp(0, length);
      final end = span.end.clamp(0, length);
      if (end <= start) continue;
      final highlighted = effectiveBase.merge(span.style);
      for (var i = start; i < end; i++) {
        styles[i] = highlighted;
      }
    }

    for (final marker in markers) {
      final start = marker.start.clamp(0, length);
      final end = marker.end.clamp(0, length);
      if (end <= start) continue;
      final markerStyle = TextStyle(
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.wavy,
        decorationColor: _markerColor(marker.type),
      );
      for (var i = start; i < end; i++) {
        styles[i] = styles[i].merge(markerStyle);
      }
    }

    if (withComposing && value.composing.isValid) {
      final composingStyle =
          const TextStyle(decoration: TextDecoration.underline);
      final start = value.composing.start.clamp(0, length);
      final end = value.composing.end.clamp(0, length);
      for (var i = start; i < end; i++) {
        styles[i] = styles[i].merge(composingStyle);
      }
    }

    final children = <TextSpan>[];
    var runStart = 0;
    var runStyle = styles[0];
    for (var i = 1; i < length; i++) {
      if (styles[i] != runStyle) {
        children.add(TextSpan(
          text: source.substring(runStart, i),
          style: runStyle,
        ));
        runStart = i;
        runStyle = styles[i];
      }
    }
    children.add(TextSpan(text: source.substring(runStart), style: runStyle));

    return TextSpan(style: effectiveBase, children: children);
  }

  Color _markerColor(TextMarkerType type) {
    switch (type) {
      case TextMarkerType.error:
        return const Color(0xFFF44747);
      case TextMarkerType.warning:
        return const Color(0xFFCCA700);
      case TextMarkerType.info:
        return const Color(0xFF569CD6);
    }
  }
}

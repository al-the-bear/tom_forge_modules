import 'package:flutter/material.dart';

import 'syntax_highlighter.dart';
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

  const TextEditorCore({
    super.key,
    required this.text,
    this.highlighter,
    this.markers = const [],
    this.onTextChanged,
    this.readOnly = false,
    this.theme = const TextEditorTheme(),
    this.initialCursorOffset,
  });

  @override
  State<TextEditorCore> createState() => _TextEditorCoreState();
}

class _TextEditorCoreState extends State<TextEditorCore> {
  late TextEditingController _textController;
  late FocusNode _focusNode;
  int _currentLine = 0;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.text);
    _focusNode = FocusNode();
    _textController.addListener(_onTextChanged);

    if (widget.initialCursorOffset != null) {
      _textController.selection = TextSelection.collapsed(
        offset: widget.initialCursorOffset!,
      );
    }
  }

  @override
  void didUpdateWidget(TextEditorCore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text && widget.text != _textController.text) {
      // Preserve cursor position when text changes externally
      var offset = _textController.selection.baseOffset;
      _textController.text = widget.text;
      if (offset <= widget.text.length) {
        _textController.selection = TextSelection.collapsed(offset: offset);
      }
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
    var offset = _textController.selection.baseOffset;
    _currentLine = _lineAtOffset(text, offset);

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
    return SingleChildScrollView(
      padding: widget.theme.contentPadding,
      child: EditableText(
        controller: _textController,
        focusNode: _focusNode,
        style: widget.theme.textStyle,
        cursorColor: Colors.white,
        backgroundCursorColor: Colors.grey,
        maxLines: null,
        readOnly: widget.readOnly,
        strutStyle: StrutStyle.fromTextStyle(widget.theme.textStyle),
      ),
    );
  }

  double get _lineHeight =>
      (widget.theme.textStyle.fontSize ?? 13) *
      (widget.theme.textStyle.height ?? 1.4);
}

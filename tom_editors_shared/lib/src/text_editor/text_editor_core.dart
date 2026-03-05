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
  }

  @override
  void didUpdateWidget(TextEditorCore oldWidget) {
    super.didUpdateWidget(oldWidget);
    _textController.baseStyle = widget.theme.textStyle;
    _textController.highlighter = widget.highlighter;
    _textController.markers = widget.markers;

    if (oldWidget.text != widget.text && widget.text != _textController.text) {
      // Preserve cursor position when text changes externally
      var offset = _textController.selection.baseOffset;
      _textController.text = widget.text;
      if (offset <= widget.text.length) {
        _textController.selection = TextSelection.collapsed(offset: offset);
      }
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
    final styles = List<TextStyle>.filled(length, effectiveBase, growable: false);

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
      final composingStyle = const TextStyle(decoration: TextDecoration.underline);
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

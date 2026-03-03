import 'package:flutter/material.dart';

import '../../schema/yaml_schema.dart';
import '../../yaml_editor_theme.dart';

/// Inline editor for string scalar values.
///
/// Features:
/// - Single-line by default; expands to multi-line when the value
///   contains newlines or the schema description hints at long text.
/// - Placeholder text from `SchemaNode.description`.
/// - Pattern validation indicator (border turns red when the current
///   value doesn't match `SchemaNode.pattern`).
///
/// ```dart
/// StringEditor(
///   value: 'hello',
///   schemaNode: SchemaNode(type: SchemaType.string, pattern: r'^[a-z]+$'),
///   onChanged: (v) => controller.setValue(path, v),
///   theme: YamlEditorTheme.dark(),
/// )
/// ```
class StringEditor extends StatefulWidget {
  /// Current string value (may be null for absent values).
  final String? value;

  /// Schema node for this field (provides description, pattern, etc.).
  final SchemaNode? schemaNode;

  /// Callback when the value changes.
  final ValueChanged<Object?>? onChanged;

  /// Whether the editor is read-only.
  final bool readOnly;

  /// Theme for styling.
  final YamlEditorTheme theme;

  const StringEditor({
    super.key,
    this.value,
    this.schemaNode,
    this.onChanged,
    this.readOnly = false,
    this.theme = const YamlEditorTheme(),
  });

  @override
  State<StringEditor> createState() => _StringEditorState();
}

class _StringEditorState extends State<StringEditor> {
  late TextEditingController _textController;
  bool _patternValid = true;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.value ?? '');
    _validatePattern(_textController.text);
  }

  @override
  void didUpdateWidget(StringEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      var newText = widget.value ?? '';
      if (_textController.text != newText) {
        _textController.text = newText;
      }
      _validatePattern(newText);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _validatePattern(String text) {
    var pattern = widget.schemaNode?.pattern;
    if (pattern == null || text.isEmpty) {
      _patternValid = true;
      return;
    }
    try {
      _patternValid = RegExp(pattern).hasMatch(text);
    } catch (_) {
      _patternValid = true; // invalid pattern → don't flag
    }
  }

  void _onChanged(String text) {
    _validatePattern(text);
    setState(() {});
    widget.onChanged?.call(text);
  }

  bool get _isMultiLine {
    var value = widget.value ?? '';
    if (value.contains('\n')) return true;
    // Heuristic: if description suggests long text, allow multi-line
    var desc = widget.schemaNode?.description?.toLowerCase() ?? '';
    return desc.contains('multi') || desc.contains('paragraph');
  }

  @override
  Widget build(BuildContext context) {
    var colors = widget.theme.colors;
    var fonts = widget.theme.fonts;

    var borderColor = _patternValid ? colors.surface : colors.errorColor;

    return TextField(
      controller: _textController,
      onChanged: widget.readOnly ? null : _onChanged,
      readOnly: widget.readOnly,
      maxLines: _isMultiLine ? null : 1,
      minLines: _isMultiLine ? 2 : 1,
      style: TextStyle(
        fontFamily: fonts.valueFontFamily,
        fontSize: fonts.valueFontSize,
        fontWeight: fonts.valueFontWeight,
        color: colors.valueColor,
        height: fonts.lineHeight,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        hintText: widget.schemaNode?.description ?? widget.schemaNode?.title,
        hintStyle: TextStyle(
          fontFamily: fonts.valueFontFamily,
          fontSize: fonts.valueFontSize,
          color: colors.hintColor,
        ),
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(
            color: _patternValid ? colors.keyColor : colors.errorColor,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

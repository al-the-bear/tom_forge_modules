import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../schema/yaml_schema.dart';
import '../../yaml_editor_theme.dart';

/// Inline editor for integer scalar values.
///
/// Features:
/// - Numeric-only text field with integer input filter.
/// - Optional ± stepper buttons when not read-only.
/// - Min/max validation from `SchemaNode.minimum` / `SchemaNode.maximum`.
///
/// ```dart
/// IntegerEditor(
///   value: 42,
///   schemaNode: SchemaNode(type: SchemaType.integer, minimum: 0, maximum: 100),
///   onChanged: (v) => controller.setValue(path, v),
///   theme: YamlEditorTheme.dark(),
/// )
/// ```
class IntegerEditor extends StatefulWidget {
  /// Current integer value (may be null for absent values).
  final Object? value;

  /// Schema node for this field (provides min, max, description).
  final SchemaNode? schemaNode;

  /// Callback when the value changes.
  final ValueChanged<Object?>? onChanged;

  /// Whether the editor is read-only.
  final bool readOnly;

  /// Theme for styling.
  final YamlEditorTheme theme;

  /// Whether to show ± stepper buttons.
  final bool showStepper;

  const IntegerEditor({
    super.key,
    this.value,
    this.schemaNode,
    this.onChanged,
    this.readOnly = false,
    this.theme = const YamlEditorTheme(),
    this.showStepper = true,
  });

  @override
  State<IntegerEditor> createState() => _IntegerEditorState();
}

class _IntegerEditorState extends State<IntegerEditor> {
  late TextEditingController _textController;
  bool _isInRange = true;

  int? get _currentInt => int.tryParse(_textController.text);

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: _formatValue(widget.value));
    _validateRange(_currentInt);
  }

  @override
  void didUpdateWidget(IntegerEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      var formatted = _formatValue(widget.value);
      if (_textController.text != formatted) {
        _textController.text = formatted;
      }
      _validateRange(_currentInt);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String _formatValue(Object? value) {
    if (value == null) return '';
    if (value is int) return value.toString();
    if (value is num) return value.toInt().toString();
    return value.toString();
  }

  void _validateRange(int? value) {
    if (value == null) {
      _isInRange = true;
      return;
    }
    var min = widget.schemaNode?.minimum;
    var max = widget.schemaNode?.maximum;
    _isInRange = true;
    if (min != null && value < min) _isInRange = false;
    if (max != null && value > max) _isInRange = false;
  }

  void _onChanged(String text) {
    var parsed = int.tryParse(text);
    _validateRange(parsed);
    setState(() {});
    widget.onChanged?.call(parsed);
  }

  void _step(int delta) {
    var current = _currentInt ?? 0;
    var next = current + delta;
    // Do NOT clamp to schema min/max here. The schema minimum is for
    // validation (shown via border colour), not for restricting the stepper.
    // This allows the user to step to 0 or negative values; the field will
    // show an error highlight if the value falls outside the schema range.
    _textController.text = next.toString();
    _validateRange(next);
    setState(() {});
    widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    var colors = widget.theme.colors;
    var fonts = widget.theme.fonts;
    var borderColor = _isInRange ? colors.surface : colors.errorColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: TextField(
            controller: _textController,
            onChanged: widget.readOnly ? null : _onChanged,
            readOnly: widget.readOnly,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^-?\d*$')),
            ],
            style: TextStyle(
              fontFamily: fonts.valueFontFamily,
              fontSize: fonts.valueFontSize,
              fontWeight: fonts.valueFontWeight,
              color: colors.numberColor,
              height: fonts.lineHeight,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              hintText: _hintText,
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
                  color: _isInRange ? colors.keyColor : colors.errorColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        if (widget.showStepper && !widget.readOnly) ...[
          const SizedBox(width: 4),
          _StepperButton(
            icon: Icons.remove,
            onPressed: () => _step(-1),
            color: colors.numberColor,
            hoverColor: colors.hoverColor,
          ),
          const SizedBox(width: 2),
          _StepperButton(
            icon: Icons.add,
            onPressed: () => _step(1),
            color: colors.numberColor,
            hoverColor: colors.hoverColor,
          ),
        ],
      ],
    );
  }

  String? get _hintText {
    var parts = <String>[];
    var min = widget.schemaNode?.minimum;
    var max = widget.schemaNode?.maximum;
    if (min != null) parts.add('min: ${min.toInt()}');
    if (max != null) parts.add('max: ${max.toInt()}');
    if (parts.isNotEmpty) return parts.join(', ');
    return widget.schemaNode?.description;
  }
}

class _StepperButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final Color hoverColor;

  const _StepperButton({
    required this.icon,
    required this.onPressed,
    required this.color,
    required this.hoverColor,
  });

  @override
  State<_StepperButton> createState() => _StepperButtonState();
}

class _StepperButtonState extends State<_StepperButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _hovered ? widget.hoverColor : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(widget.icon, size: 14, color: widget.color),
        ),
      ),
    );
  }
}

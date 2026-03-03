import 'package:flutter/material.dart';

import '../../schema/yaml_schema.dart';
import '../../yaml_editor_theme.dart';

/// Inline editor for boolean scalar values.
///
/// Renders a toggle switch with true/false labels.
/// Supports keyboard activation (Space/Enter).
///
/// ```dart
/// BooleanEditor(
///   value: true,
///   onChanged: (v) => controller.setValue(path, v),
///   theme: YamlEditorTheme.dark(),
/// )
/// ```
class BooleanEditor extends StatelessWidget {
  /// Current boolean value.
  final Object? value;

  /// Schema node for this field.
  final SchemaNode? schemaNode;

  /// Callback when the value changes.
  final ValueChanged<Object?>? onChanged;

  /// Whether the editor is read-only.
  final bool readOnly;

  /// Theme for styling.
  final YamlEditorTheme theme;

  const BooleanEditor({
    super.key,
    this.value,
    this.schemaNode,
    this.onChanged,
    this.readOnly = false,
    this.theme = const YamlEditorTheme(),
  });

  bool get _boolValue {
    if (value is bool) return value as bool;
    if (value is String) {
      return (value as String).toLowerCase() == 'true';
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    var colors = theme.colors;
    var fonts = theme.fonts;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 32,
          height: 18,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Switch.adaptive(
              value: _boolValue,
              onChanged: readOnly ? null : (v) => onChanged?.call(v),
              activeTrackColor: colors.boolColor,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          _boolValue ? 'true' : 'false',
          style: TextStyle(
            fontFamily: fonts.valueFontFamily,
            fontSize: fonts.valueFontSize,
            fontWeight: fonts.valueFontWeight,
            color: colors.boolColor,
          ),
        ),
      ],
    );
  }
}

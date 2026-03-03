import 'package:flutter/material.dart';

import '../../schema/yaml_schema.dart';
import '../../yaml_editor_theme.dart';

/// Inline editor for null scalar values.
///
/// Displays a "null" chip with an optional type conversion popup that lets
/// the user change the value to a different type (string, integer, boolean,
/// etc.) based on the schema or a default set.
///
/// ```dart
/// NullEditor(
///   onChanged: (v) => controller.setValue(path, v),
///   theme: YamlEditorTheme.dark(),
/// )
/// ```
class NullEditor extends StatelessWidget {
  /// Current value (should be null, but accepted as Object? for generality).
  final Object? value;

  /// Schema node for this field.
  final SchemaNode? schemaNode;

  /// Callback when the value changes (e.g. converting to a different type).
  final ValueChanged<Object?>? onChanged;

  /// Whether the editor is read-only.
  final bool readOnly;

  /// Theme for styling.
  final YamlEditorTheme theme;

  const NullEditor({
    super.key,
    this.value,
    this.schemaNode,
    this.onChanged,
    this.readOnly = false,
    this.theme = const YamlEditorTheme(),
  });

  @override
  Widget build(BuildContext context) {
    var colors = theme.colors;
    var fonts = theme.fonts;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colors.nullColor.withAlpha(25),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: colors.nullColor.withAlpha(80),
              width: 0.5,
            ),
          ),
          child: Text(
            'null',
            style: TextStyle(
              fontFamily: fonts.valueFontFamily,
              fontSize: fonts.valueFontSize,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              color: colors.nullColor,
            ),
          ),
        ),
        if (!readOnly && onChanged != null) ...[
          const SizedBox(width: 6),
          PopupMenuButton<_TypeConversion>(
            tooltip: 'Convert to type',
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 0),
            icon: Icon(
              Icons.swap_horiz,
              size: 16,
              color: colors.hintColor,
            ),
            onSelected: (conversion) {
              onChanged?.call(conversion.defaultValue);
            },
            itemBuilder: (context) {
              return _availableConversions.map((c) {
                return PopupMenuItem<_TypeConversion>(
                  value: c,
                  height: 32,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(c.icon, size: 14, color: colors.hintColor),
                      const SizedBox(width: 8),
                      Text(c.label, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ],
    );
  }

  List<_TypeConversion> get _availableConversions {
    // If schema specifies a type, only show that conversion
    var node = schemaNode;
    if (node != null && node.type != SchemaType.object) {
      return [_conversionForType(node.type)];
    }
    // Otherwise show all common types
    return const [
      _TypeConversion('String', '', Icons.text_fields),
      _TypeConversion('Integer', 0, Icons.tag),
      _TypeConversion('Number', 0.0, Icons.looks_one),
      _TypeConversion('Boolean', false, Icons.toggle_on_outlined),
    ];
  }

  static _TypeConversion _conversionForType(SchemaType type) {
    switch (type) {
      case SchemaType.string:
        return const _TypeConversion('String', '', Icons.text_fields);
      case SchemaType.integer:
        return const _TypeConversion('Integer', 0, Icons.tag);
      case SchemaType.number:
        return const _TypeConversion('Number', 0.0, Icons.looks_one);
      case SchemaType.boolean:
        return const _TypeConversion(
            'Boolean', false, Icons.toggle_on_outlined);
      case SchemaType.array:
        return const _TypeConversion('List', null, Icons.list);
      case SchemaType.object:
        return const _TypeConversion('Map', null, Icons.data_object);
    }
  }
}

class _TypeConversion {
  final String label;
  final Object? defaultValue;
  final IconData icon;

  const _TypeConversion(this.label, this.defaultValue, this.icon);
}

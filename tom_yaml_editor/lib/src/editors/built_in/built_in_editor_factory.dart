import 'package:flutter/widgets.dart';

import '../../schema/yaml_schema.dart';
import '../../yaml_editor_theme.dart';
import 'boolean_editor.dart';
import 'enum_editor.dart';
import 'integer_editor.dart';
import 'null_editor.dart';
import 'number_editor.dart';
import 'string_editor.dart';

/// Factory that maps a [SchemaType] + [SchemaNode] to the correct
/// built-in scalar editor widget.
///
/// Resolution priority:
/// 1. If the schema node has `enumValues`, use [EnumEditor].
/// 2. Match by `SchemaNode.type`:
///    - `string` → [StringEditor]
///    - `integer` → [IntegerEditor]
///    - `number` → [NumberEditor]
///    - `boolean` → [BooleanEditor]
/// 3. If the value is `null`, use [NullEditor].
/// 4. Falls back to [StringEditor] for unknown types.
///
/// ```dart
/// var editor = BuiltInEditorFactory.build(
///   value: 'hello',
///   schemaNode: SchemaNode(type: SchemaType.string),
///   onChanged: (v) => controller.setValue(path, v),
///   theme: YamlEditorTheme.dark(),
/// );
/// ```
class BuiltInEditorFactory {
  const BuiltInEditorFactory._();

  /// Build the appropriate built-in editor for the given value and schema.
  static Widget build({
    required Object? value,
    required SchemaNode? schemaNode,
    required ValueChanged<Object?>? onChanged,
    required YamlEditorTheme theme,
    bool readOnly = false,
  }) {
    // 1. Enum values take precedence
    if (schemaNode?.enumValues != null && schemaNode!.enumValues!.isNotEmpty) {
      return EnumEditor(
        value: value,
        schemaNode: schemaNode,
        onChanged: onChanged,
        readOnly: readOnly,
        theme: theme,
      );
    }

    // 2. Null value with no known type → NullEditor
    if (value == null && schemaNode == null) {
      return NullEditor(
        value: value,
        onChanged: onChanged,
        readOnly: readOnly,
        theme: theme,
      );
    }

    // 3. Schema type-based dispatching
    var type = schemaNode?.type;
    if (type != null) {
      switch (type) {
        case SchemaType.string:
          return StringEditor(
            value: value?.toString(),
            schemaNode: schemaNode,
            onChanged: onChanged,
            readOnly: readOnly,
            theme: theme,
          );
        case SchemaType.integer:
          return IntegerEditor(
            value: value,
            schemaNode: schemaNode,
            onChanged: onChanged,
            readOnly: readOnly,
            theme: theme,
          );
        case SchemaType.number:
          return NumberEditor(
            value: value,
            schemaNode: schemaNode,
            onChanged: onChanged,
            readOnly: readOnly,
            theme: theme,
          );
        case SchemaType.boolean:
          return BooleanEditor(
            value: value,
            schemaNode: schemaNode,
            onChanged: onChanged,
            readOnly: readOnly,
            theme: theme,
          );
        case SchemaType.object:
        case SchemaType.array:
          // Object/array types are handled by the tree layer, not scalar editors;
          // if somehow reached here, fall through to value-based inference.
          break;
      }
    }

    // 4. Value-based type inference (no schema)
    if (value == null) {
      return NullEditor(
        value: value,
        schemaNode: schemaNode,
        onChanged: onChanged,
        readOnly: readOnly,
        theme: theme,
      );
    }

    if (value is bool) {
      return BooleanEditor(
        value: value,
        schemaNode: schemaNode,
        onChanged: onChanged,
        readOnly: readOnly,
        theme: theme,
      );
    }

    if (value is int) {
      return IntegerEditor(
        value: value,
        schemaNode: schemaNode,
        onChanged: onChanged,
        readOnly: readOnly,
        theme: theme,
      );
    }

    if (value is double || value is num) {
      return NumberEditor(
        value: value,
        schemaNode: schemaNode,
        onChanged: onChanged,
        readOnly: readOnly,
        theme: theme,
      );
    }

    // 5. Default fallback → StringEditor
    return StringEditor(
      value: value.toString(),
      schemaNode: schemaNode,
      onChanged: onChanged,
      readOnly: readOnly,
      theme: theme,
    );
  }
}

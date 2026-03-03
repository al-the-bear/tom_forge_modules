import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:yaml/yaml.dart';

import '../model/yaml_document_model.dart';

/// Represents a JSON Schema for YAML document validation and construction help.
///
/// This is a lightweight schema representation — not a full JSON Schema
/// implementation, but enough to:
/// - Validate documents structurally
/// - Suggest available keys at any nesting level
/// - Determine value types and constraints
/// - Detect required vs optional properties
class YamlSchema {
  /// The root schema node.
  final SchemaNode root;

  /// The raw JSON Schema map (preserved for reference).
  final Map<String, dynamic> rawSchema;

  const YamlSchema({required this.root, required this.rawSchema});

  /// Parse a JSON Schema map into a [YamlSchema].
  factory YamlSchema.fromJson(Map<String, dynamic> json) {
    return YamlSchema(
      root: SchemaNode.fromJson(json),
      rawSchema: json,
    );
  }

  /// Validate a document against this schema.
  ///
  /// Returns a list of [ValidationError]s (empty if valid).
  List<ValidationError> validate(YamlDocumentModel document) {
    var errors = <ValidationError>[];
    _validateNode(root, document.rootNode, [], errors);
    return errors;
  }

  /// Recursively validate a YAML node against a schema node.
  void _validateNode(
    SchemaNode schema,
    YamlNode? node,
    List<Object> path,
    List<ValidationError> errors,
  ) {
    // Null/missing node — only an error if something more specific is expected
    if (node == null || node.value == null) {
      return;
    }

    var value = node.value;

    // Type checking
    if (!_typeMatches(schema.type, value)) {
      errors.add(ValidationError(
        path: path,
        message:
            'Expected type "${schema.type.name}", got "${_dartTypeLabel(value)}"',
        severity: ValidationSeverity.error,
        code: 'type_mismatch',
      ));
      return; // Don't recurse into a wrong-type node
    }

    // Enum validation
    if (schema.enumValues != null && schema.enumValues!.isNotEmpty) {
      if (!schema.enumValues!.contains(value)) {
        errors.add(ValidationError(
          path: path,
          message:
              'Value "$value" is not one of the allowed values: ${schema.enumValues!.join(", ")}',
          severity: ValidationSeverity.error,
          code: 'enum_violation',
        ));
      }
    }

    // String-specific validations
    if (schema.type == SchemaType.string && value is String) {
      if (schema.pattern != null) {
        var regex = RegExp(schema.pattern!);
        if (!regex.hasMatch(value)) {
          errors.add(ValidationError(
            path: path,
            message: 'String does not match pattern "${schema.pattern}"',
            severity: ValidationSeverity.warning,
            code: 'pattern_mismatch',
          ));
        }
      }
    }

    // Numeric validations
    if (value is num) {
      if (schema.minimum != null && value < schema.minimum!) {
        errors.add(ValidationError(
          path: path,
          message: 'Value $value is less than minimum ${schema.minimum}',
          severity: ValidationSeverity.error,
          code: 'minimum_violation',
        ));
      }
      if (schema.maximum != null && value > schema.maximum!) {
        errors.add(ValidationError(
          path: path,
          message: 'Value $value exceeds maximum ${schema.maximum}',
          severity: ValidationSeverity.error,
          code: 'maximum_violation',
        ));
      }
    }

    // Object validation — required keys and property recursion
    if (schema.type == SchemaType.object && node is YamlMap) {
      // Check required properties
      for (var entry in schema.properties.entries) {
        if (entry.value.required) {
          var childNode = node.nodes[entry.key];
          if (childNode == null || childNode.value == null) {
            errors.add(ValidationError(
              path: [...path, entry.key],
              message: 'Required property "${entry.key}" is missing',
              severity: ValidationSeverity.error,
              code: 'required_missing',
            ));
          }
        }
      }

      // Recurse into defined properties
      for (var entry in node.nodes.entries) {
        var key = entry.key.toString();
        var propSchema = schema.properties[key];
        if (propSchema != null) {
          _validateNode(propSchema, entry.value, [...path, key], errors);
        }
        // Unknown properties are allowed (no additionalProperties: false yet)
      }
    }

    // Array validation — items recursion
    if (schema.type == SchemaType.array && node is YamlList) {
      var itemSchema = schema.items;
      if (itemSchema != null) {
        for (var i = 0; i < node.nodes.length; i++) {
          _validateNode(itemSchema, node.nodes[i], [...path, i], errors);
        }
      }
    }
  }

  /// Check whether a Dart value matches the expected JSON Schema type.
  bool _typeMatches(SchemaType expected, Object? value) {
    switch (expected) {
      case SchemaType.string:
        return value is String;
      case SchemaType.integer:
        return value is int;
      case SchemaType.number:
        return value is num;
      case SchemaType.boolean:
        return value is bool;
      case SchemaType.object:
        return value is YamlMap || value is Map;
      case SchemaType.array:
        return value is YamlList || value is List;
    }
  }

  /// Human-readable label for a Dart value's type.
  String _dartTypeLabel(Object? value) {
    if (value is String) return 'string';
    if (value is int) return 'integer';
    if (value is double) return 'number';
    if (value is bool) return 'boolean';
    if (value is YamlMap || value is Map) return 'object';
    if (value is YamlList || value is List) return 'array';
    if (value == null) return 'null';
    return value.runtimeType.toString();
  }

  /// Get suggested keys that can be added at a specific path.
  ///
  /// Returns keys defined in the schema that are not yet present in the document.
  List<String> suggestedKeysAt(
    List<String> parentPath,
    YamlDocumentModel document,
  ) {
    var schemaNode = nodeAt(parentPath);
    if (schemaNode == null || schemaNode.type != SchemaType.object) return [];

    var existingNode = document.nodeAt(parentPath.cast<Object>());
    var existingKeys = <String>{};
    if (existingNode is YamlMap) {
      existingKeys = existingNode.keys.map((k) => k.toString()).toSet();
    }

    return schemaNode.properties.keys
        .where((key) => !existingKeys.contains(key))
        .toList();
  }

  /// Get the schema node at a specific path.
  SchemaNode? nodeAt(List<String> path) {
    SchemaNode? current = root;
    for (var key in path) {
      if (current == null) return null;
      current = current.properties[key];
    }
    return current;
  }
}

/// A node in the schema tree representing a type definition.
class SchemaNode {
  /// The JSON Schema type.
  final SchemaType type;

  /// Human-readable title.
  final String? title;

  /// Description text.
  final String? description;

  /// Default value.
  final Object? defaultValue;

  /// Whether this property is required in its parent.
  final bool required;

  /// Properties (for object type).
  final Map<String, SchemaNode> properties;

  /// Items schema (for array type).
  final SchemaNode? items;

  /// Enum values (for constrained strings/ints).
  final List<Object>? enumValues;

  /// Minimum value (for number/integer types).
  final num? minimum;

  /// Maximum value (for number/integer types).
  final num? maximum;

  /// Pattern (for string types).
  final String? pattern;

  /// The editor type suffix override (e.g. "dart", "markdown").
  ///
  /// If set in the schema via `x-editor-type`, overrides the key suffix
  /// convention for determining the embedded editor.
  final String? editorType;

  const SchemaNode({
    required this.type,
    this.title,
    this.description,
    this.defaultValue,
    this.required = false,
    this.properties = const {},
    this.items,
    this.enumValues,
    this.minimum,
    this.maximum,
    this.pattern,
    this.editorType,
  });

  /// Parse a JSON Schema node.
  factory SchemaNode.fromJson(Map<String, dynamic> json) {
    var typeStr = json['type'] as String? ?? 'object';
    var requiredList =
        (json['required'] as List?)?.cast<String>() ?? <String>[];

    var properties = <String, SchemaNode>{};
    var propsJson = json['properties'] as Map<String, dynamic>?;
    if (propsJson != null) {
      for (var entry in propsJson.entries) {
        var propJson = entry.value as Map<String, dynamic>;
        var node = SchemaNode.fromJson(propJson);
        properties[entry.key] = SchemaNode(
          type: node.type,
          title: node.title,
          description: node.description,
          defaultValue: node.defaultValue,
          required: requiredList.contains(entry.key),
          properties: node.properties,
          items: node.items,
          enumValues: node.enumValues,
          minimum: node.minimum,
          maximum: node.maximum,
          pattern: node.pattern,
          editorType: node.editorType,
        );
      }
    }

    SchemaNode? items;
    if (json['items'] is Map<String, dynamic>) {
      items = SchemaNode.fromJson(json['items'] as Map<String, dynamic>);
    }

    return SchemaNode(
      type: SchemaType.fromString(typeStr),
      title: json['title'] as String?,
      description: json['description'] as String?,
      defaultValue: json['default'],
      properties: properties,
      items: items,
      enumValues: (json['enum'] as List?)?.cast<Object>(),
      minimum: json['minimum'] as num?,
      maximum: json['maximum'] as num?,
      pattern: json['pattern'] as String?,
      editorType: json['x-editor-type'] as String?,
    );
  }
}

/// JSON Schema types.
enum SchemaType {
  /// A string value.
  string,

  /// An integer value (whole number).
  integer,

  /// A numeric value (integer or floating-point).
  number,

  /// A boolean value (`true` or `false`).
  boolean,

  /// An object (map) with named properties.
  object,

  /// An array (list) of ordered items.
  array,
  ;

  static SchemaType fromString(String s) {
    return SchemaType.values.firstWhere(
      (v) => v.name == s,
      orElse: () => SchemaType.string,
    );
  }
}

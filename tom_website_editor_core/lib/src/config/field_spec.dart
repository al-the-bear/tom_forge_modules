import 'config_issue.dart';

/// A declarative description of one node in the `tom.website-editor.yaml`
/// structure.
///
/// This is the **single source of truth** for the config format: both the
/// runtime validator ([validateNode]) and the JSON Schema generator
/// ([toJsonSchema]) are derived from the same [FieldSpec] tree, so editor and
/// runtime can never disagree about what a valid config is.
sealed class FieldSpec {
  const FieldSpec({this.description});

  /// Optional human description, emitted into the JSON Schema.
  final String? description;

  /// Emits the JSON Schema fragment for this node (draft-07 compatible).
  Map<String, dynamic> toJsonSchema();

  /// Validates [value] at [path], appending any problems to [issues].
  void validateNode(Object? value, String path, List<ConfigIssue> issues);

  /// Helper: a base schema map seeded with the optional description.
  Map<String, dynamic> _schemaBase(Map<String, dynamic> body) => {
        if (description != null) 'description': description,
        ...body,
      };
}

/// A string value.
class StringSpec extends FieldSpec {
  const StringSpec({super.description});

  @override
  Map<String, dynamic> toJsonSchema() => _schemaBase({'type': 'string'});

  @override
  void validateNode(Object? value, String path, List<ConfigIssue> issues) {
    if (value is! String) {
      issues.add(ConfigIssue(
          path: path, message: 'expected a string, got ${_typeName(value)}'));
    }
  }
}

/// An integer value, optionally pinned to a [constValue].
class IntSpec extends FieldSpec {
  const IntSpec({this.constValue, super.description});

  /// If set, the value must equal this constant.
  final int? constValue;

  @override
  Map<String, dynamic> toJsonSchema() => _schemaBase({
        'type': 'integer',
        if (constValue != null) 'const': constValue,
      });

  @override
  void validateNode(Object? value, String path, List<ConfigIssue> issues) {
    if (value is! int) {
      issues.add(ConfigIssue(
          path: path, message: 'expected an integer, got ${_typeName(value)}'));
      return;
    }
    if (constValue != null && value != constValue) {
      issues.add(ConfigIssue(path: path, message: 'must be $constValue'));
    }
  }
}

/// A list whose items all match [items], with an optional [minItems] floor.
class ListSpec extends FieldSpec {
  const ListSpec(this.items, {this.minItems, super.description});

  final FieldSpec items;
  final int? minItems;

  @override
  Map<String, dynamic> toJsonSchema() => _schemaBase({
        'type': 'array',
        'items': items.toJsonSchema(),
        if (minItems != null) 'minItems': minItems,
      });

  @override
  void validateNode(Object? value, String path, List<ConfigIssue> issues) {
    if (value is! List) {
      issues.add(ConfigIssue(
          path: path, message: 'expected a list, got ${_typeName(value)}'));
      return;
    }
    if (minItems != null && value.length < minItems!) {
      issues.add(ConfigIssue(
          path: path, message: 'must contain at least $minItems item(s)'));
    }
    for (var i = 0; i < value.length; i++) {
      items.validateNode(value[i], '$path[$i]', issues);
    }
  }
}

/// A string-keyed map whose values all match [values]
/// (JSON Schema: an object with only `additionalProperties`).
class MapSpec extends FieldSpec {
  const MapSpec(this.values, {super.description});

  final FieldSpec values;

  @override
  Map<String, dynamic> toJsonSchema() => _schemaBase({
        'type': 'object',
        'additionalProperties': values.toJsonSchema(),
      });

  @override
  void validateNode(Object? value, String path, List<ConfigIssue> issues) {
    if (value is! Map) {
      issues.add(ConfigIssue(
          path: path, message: 'expected a map, got ${_typeName(value)}'));
      return;
    }
    for (final entry in value.entries) {
      values.validateNode(entry.value, '$path.${entry.key}', issues);
    }
  }
}

/// An object with a fixed set of [properties], a [required] subset, and an
/// optional [additionalProperties] spec (null forbids unknown keys).
class ObjectSpec extends FieldSpec {
  const ObjectSpec({
    required this.properties,
    this.required = const {},
    this.additionalProperties,
    super.description,
  });

  final Map<String, FieldSpec> properties;
  final Set<String> required;

  /// Spec applied to keys outside [properties]; `null` forbids them.
  final FieldSpec? additionalProperties;

  @override
  Map<String, dynamic> toJsonSchema() => _schemaBase({
        'type': 'object',
        'properties': {
          for (final entry in properties.entries)
            entry.key: entry.value.toJsonSchema(),
        },
        if (required.isNotEmpty) 'required': required.toList(),
        'additionalProperties':
            additionalProperties?.toJsonSchema() ?? false,
      });

  @override
  void validateNode(Object? value, String path, List<ConfigIssue> issues) {
    if (value is! Map) {
      issues.add(ConfigIssue(
          path: path, message: 'expected a map, got ${_typeName(value)}'));
      return;
    }
    for (final key in required) {
      if (!value.containsKey(key)) {
        issues.add(ConfigIssue(
            path: path.isEmpty ? key : '$path.$key',
            message: 'missing required key "$key"'));
      }
    }
    for (final entry in value.entries) {
      final key = entry.key.toString();
      final childPath = path.isEmpty ? key : '$path.$key';
      final spec = properties[key];
      if (spec != null) {
        spec.validateNode(entry.value, childPath, issues);
      } else if (additionalProperties != null) {
        additionalProperties!.validateNode(entry.value, childPath, issues);
      } else {
        issues.add(
            ConfigIssue(path: childPath, message: 'unknown key "$key"'));
      }
    }
  }
}

/// Matches any value (JSON Schema: `{}`); used for forward-compatible blocks
/// not yet pinned down (e.g. the §6a `content:` block).
class AnySpec extends FieldSpec {
  const AnySpec({super.description});

  @override
  Map<String, dynamic> toJsonSchema() => _schemaBase({});

  @override
  void validateNode(Object? value, String path, List<ConfigIssue> issues) {}
}

String _typeName(Object? value) {
  if (value == null) return 'null';
  if (value is String) return 'string';
  if (value is int) return 'integer';
  if (value is num) return 'number';
  if (value is bool) return 'boolean';
  if (value is List) return 'list';
  if (value is Map) return 'map';
  return value.runtimeType.toString();
}

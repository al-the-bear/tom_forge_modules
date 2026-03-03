import 'yaml_schema.dart';

/// Walks a [YamlSchema] to provide context-aware assistance during editing.
///
/// Given a path in the document, the walker can:
/// - Determine what type of value is expected
/// - List available keys for insertion
/// - Check if a key is required or optional
/// - Determine the appropriate editor type (from suffix or schema metadata)
class SchemaWalker {
  /// The schema being walked.
  final YamlSchema schema;

  const SchemaWalker(this.schema);

  /// Get the schema node at a specific path.
  SchemaNode? nodeAt(List<String> path) => schema.nodeAt(path);

  /// Get the expected type at a path.
  SchemaType? expectedTypeAt(List<String> path) {
    return nodeAt(path)?.type;
  }

  /// Check if a specific key is required at a parent path.
  bool isRequired(List<String> parentPath, String key) {
    var node = nodeAt([...parentPath, key]);
    return node?.required ?? false;
  }

  /// Get all properties defined at a path (for object types).
  Map<String, SchemaNode> propertiesAt(List<String> path) {
    return nodeAt(path)?.properties ?? {};
  }

  /// Determine the editor type for a key.
  ///
  /// Priority:
  /// 1. Schema `x-editor-type` metadata
  /// 2. Key suffix convention (`key-dart` → "dart")
  /// 3. Schema type (string → text, integer → number, etc.)
  String? editorTypeForKey(List<String> path) {
    var node = nodeAt(path);

    // 1. Explicit schema override
    if (node?.editorType != null) return node!.editorType;

    // 2. Key suffix convention
    var key = path.isNotEmpty ? path.last : null;
    if (key != null) {
      var suffix = extractSuffix(key);
      if (suffix != null) return suffix;
    }

    // 3. Fall back to schema type
    return null;
  }

  /// Extract the type suffix from a key name.
  ///
  /// `script-dart` → `dart`
  /// `description-markdown` → `markdown`
  /// `pattern-regex` → `regex`
  /// `name` → `null` (no suffix)
  static String? extractSuffix(String key) {
    var lastDash = key.lastIndexOf('-');
    if (lastDash <= 0 || lastDash == key.length - 1) return null;
    return key.substring(lastDash + 1);
  }
}

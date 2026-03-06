import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Non-destructive YAML document model.
///
/// Wraps `package:yaml_edit` to provide comment-and-whitespace-preserving
/// edits. Every mutation returns a **new** [YamlDocumentModel]; the original
/// instance is never modified.
///
/// Preserved across edits:
/// - Comments (inline and block)
/// - Original formatting and whitespace
/// - Key ordering
/// - Blank lines
class YamlDocumentModel {
  /// The underlying yaml_edit editor (mutable internally but we treat each
  /// [YamlDocumentModel] as a snapshot — mutations create new instances).
  final YamlEditor _editor;

  YamlDocumentModel._(this._editor);

  /// Parse a YAML string into a non-destructive document model.
  factory YamlDocumentModel.parse(String yaml) {
    return YamlDocumentModel._(YamlEditor(yaml));
  }

  /// Serialize back to YAML string, preserving original formatting.
  String toYamlString() => _normalizeMultilineScalars(_editor.toString());

  String _normalizeMultilineScalars(String yaml) {
    if (!yaml.contains(r'\n')) return yaml;

    final lines = yaml.split('\n');
    final normalized = <String>[];

    final keyValuePattern = RegExp(
      r'''^(\s*)([^:#\n][^:\n]*):(\s*)(["'])(.*)\4\s*$''',
    );
    final listValuePattern = RegExp(
      r'''^(\s*)-(\s*)(["'])(.*)\3\s*$''',
    );

    for (final line in lines) {
      final keyMatch = keyValuePattern.firstMatch(line);
      if (keyMatch != null) {
        final indent = keyMatch.group(1)!;
        final key = keyMatch.group(2)!;
        final spacing = keyMatch.group(3)!;
        final rawValue = keyMatch.group(5)!;
        final unescaped = _decodeEscapedNewlines(rawValue);
        if (unescaped.contains('\n')) {
          normalized.add('$indent$key:$spacing|');
          for (final blockLine in unescaped.split('\n')) {
            normalized.add('$indent  $blockLine');
          }
          continue;
        }
      }

      final listMatch = listValuePattern.firstMatch(line);
      if (listMatch != null) {
        final indent = listMatch.group(1)!;
        final spacing = listMatch.group(2)!;
        final rawValue = listMatch.group(4)!;
        final unescaped = _decodeEscapedNewlines(rawValue);
        if (unescaped.contains('\n')) {
          normalized.add('$indent-$spacing|');
          for (final blockLine in unescaped.split('\n')) {
            normalized.add('$indent  $blockLine');
          }
          continue;
        }
      }

      normalized.add(line);
    }

    return normalized.join('\n');
  }

  String _decodeEscapedNewlines(String value) {
    return value
      .replaceAll('\\r\\n', '\n')
      .replaceAll('\\n', '\n')
      .replaceAll('\\\\', '\\');
  }

  /// The parsed YAML root node (from `package:yaml`).
  ///
  /// This is the structured representation; use it for reading values,
  /// iterating keys, etc. For edits, use the `with*` methods instead.
  YamlNode get rootNode {
    try {
      return _editor.parseAt([]);
    } catch (_) {
      return wrapAsYamlNode(null);
    }
  }

  /// Get the parsed YAML node at a specific [path].
  ///
  /// Path is a list of keys (for maps) or indices (for lists).
  /// Returns `null` if the path does not exist.
  YamlNode? nodeAt(List<Object> path) {
    try {
      return _editor.parseAt(path);
    } catch (_) {
      return null;
    }
  }

  /// Get the Dart value at a specific [path].
  ///
  /// Returns `null` if the path does not exist.
  Object? valueOf(List<Object> path) {
    return nodeAt(path)?.value;
  }

  /// Whether a node exists at [path].
  bool hasPath(List<Object> path) => nodeAt(path) != null;

  // ---------------------------------------------------------------------------
  // Edit operations — each returns a NEW document model
  // ---------------------------------------------------------------------------

  /// Create a new document with a value set at the given [path].
  ///
  /// The surrounding YAML is preserved; only the target value is replaced.
  YamlDocumentModel withValueAt(List<Object> path, Object? value) {
    var copy = YamlEditor(_editor.toString());
    copy.update(path, value);
    return YamlDocumentModel._(copy);
  }

  /// Create a new document with a key inserted at the given [parentPath].
  ///
  /// The new key is added after existing keys in the map.
  YamlDocumentModel withInsertedKey(
    List<Object> parentPath,
    String key,
    Object? defaultValue,
  ) {
    var copy = YamlEditor(_editor.toString());
    copy.update([...parentPath, key], defaultValue);
    return YamlDocumentModel._(copy);
  }

  /// Create a new document with a key removed at the given [path].
  ///
  /// The last element in [path] is the key to remove.
  YamlDocumentModel withRemovedKey(List<Object> path) {
    var copy = YamlEditor(_editor.toString());
    copy.remove(path);
    return YamlDocumentModel._(copy);
  }

  /// Create a new document with a value appended to the list at [listPath].
  YamlDocumentModel withAppendedToList(List<Object> listPath, Object? value) {
    var copy = YamlEditor(_editor.toString());
    copy.appendToList(listPath, value);
    return YamlDocumentModel._(copy);
  }

  /// Create a new document with a value inserted into the list at [listPath]
  /// at [index].
  YamlDocumentModel withInsertedIntoList(
    List<Object> listPath,
    int index,
    Object? value,
  ) {
    var copy = YamlEditor(_editor.toString());
    copy.insertIntoList(listPath, index, value);
    return YamlDocumentModel._(copy);
  }

  /// Create a new document with an item removed from the list at [path].
  ///
  /// The last element in [path] should be the integer index.
  YamlDocumentModel withRemovedFromList(List<Object> path) {
    var copy = YamlEditor(_editor.toString());
    copy.remove(path);
    return YamlDocumentModel._(copy);
  }

  /// Extract the YAML subtree at [path] as a standalone YAML string.
  ///
  /// Returns `null` if the path does not exist.
  ///
  /// ```dart
  /// var subtree = model.subtreeYamlAt(['prompt', 'meta-data']);
  /// // Returns the YAML text for just the meta-data subtree
  /// ```
  String? subtreeYamlAt(List<Object> path) {
    var node = nodeAt(path);
    if (node == null) return null;
    // For scalar values, return the string representation.
    // For maps/lists, serialize through a temporary YamlEditor.
    var value = node.value;
    if (value is String || value is num || value is bool || value == null) {
      return value?.toString();
    }
    // Use yaml_edit to serialize the subtree preserving structure
    var tempEditor = YamlEditor('');
    tempEditor.update([], value);
    return _normalizeMultilineScalars(tempEditor.toString());
  }

  /// Replace the subtree at [path] with a new [yamlFragment].
  ///
  /// Parses [yamlFragment] and sets it as the value at [path], preserving
  /// the rest of the document.
  YamlDocumentModel replaceSubtreeAt(List<Object> path, String yamlFragment) {
    // Parse the fragment to get the Dart value
    var parsed = loadYaml(yamlFragment);
    return withValueAt(path, parsed);
  }

  // ---------------------------------------------------------------------------
  // Convenience accessors
  // ---------------------------------------------------------------------------

  /// All top-level keys (if root is a map).
  Iterable<String> get topLevelKeys {
    var root = rootNode;
    if (root is YamlMap) {
      return root.keys.map((k) => k.toString());
    }
    return const [];
  }

  /// Walk all keys in the document depth-first, yielding paths.
  Iterable<List<String>> allPaths() sync* {
    yield* _walkPaths(rootNode, []);
  }

  Iterable<List<String>> _walkPaths(
    YamlNode node,
    List<String> prefix,
  ) sync* {
    if (node is YamlMap) {
      for (var entry in node.nodes.entries) {
        var key = entry.key.toString();
        var path = [...prefix, key];
        yield path;
        yield* _walkPaths(entry.value, path);
      }
    } else if (node is YamlList) {
      for (var i = 0; i < node.nodes.length; i++) {
        var path = [...prefix, i.toString()];
        yield path;
        yield* _walkPaths(node.nodes[i], path);
      }
    }
  }
}

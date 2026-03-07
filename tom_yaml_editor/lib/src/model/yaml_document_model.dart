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
  ///
  /// Multiline string scalars that `yaml_edit` serializes as escaped quoted
  /// strings (e.g. `"line1\nline2"`) are converted to block scalar (`|`)
  /// format using proper YAML library APIs.
  String toYamlString() => _formatBlockScalars(_editor.toString());

  /// Convert multiline string scalars from quoted/escaped format to
  /// block scalar (literal `|`) format using proper YAML library APIs.
  ///
  /// Walks the parsed YAML tree to find string scalars containing newlines
  /// that are not already in block scalar style, and converts them using
  /// [yaml_edit]'s [wrapAsYamlNode] with [ScalarStyle.LITERAL].
  String _formatBlockScalars(String yaml) {
    YamlNode root;
    try {
      root = loadYamlNode(yaml);
    } catch (_) {
      return yaml;
    }

    // Collect paths of multiline scalars that need converting.
    var paths = <List<Object>>[];
    var values = <String>[];
    _findMultilineScalars(root, [], paths, values);

    if (paths.isEmpty) return yaml;

    // Apply conversions using yaml_edit — each update properly adjusts
    // internal offsets so subsequent edits remain valid.
    var editor = YamlEditor(yaml);
    for (var i = 0; i < paths.length; i++) {
      editor.update(
        paths[i],
        wrapAsYamlNode(values[i], scalarStyle: ScalarStyle.LITERAL),
      );
    }
    return editor.toString();
  }

  /// Recursively walk the YAML tree collecting paths and values of string
  /// scalars that contain newlines but are not already in block style.
  void _findMultilineScalars(
    YamlNode node,
    List<Object> currentPath,
    List<List<Object>> paths,
    List<String> values,
  ) {
    if (node is YamlMap) {
      for (var entry in node.nodes.entries) {
        var key = (entry.key as YamlScalar).value;
        _findMultilineScalars(
          entry.value,
          [...currentPath, key],
          paths,
          values,
        );
      }
    } else if (node is YamlList) {
      for (var i = 0; i < node.nodes.length; i++) {
        _findMultilineScalars(
          node.nodes[i],
          [...currentPath, i],
          paths,
          values,
        );
      }
    } else if (node is YamlScalar) {
      var value = node.value;
      if (value is String &&
          value.contains('\n') &&
          node.style != ScalarStyle.LITERAL &&
          node.style != ScalarStyle.FOLDED) {
        paths.add(currentPath);
        values.add(value);
      }
    }
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

    // Try to extract the original source text via span — this preserves
    // the exact formatting and quoting from the document.
    var span = node.span;
    var source = _editor.toString();
    var start = span.start.offset;
    var end = span.end.offset;
    if (start >= 0 && end <= source.length && end > start) {
      var extracted = source.substring(start, end);

      // The span starts mid-line (at the first content character), so the
      // first line is missing its leading indentation while subsequent lines
      // retain their full absolute indent. Re-add the first-line indent so
      // _dedent can strip uniformly across all lines.
      var firstLineIndent = ' ' * span.start.column;
      extracted = firstLineIndent + extracted;

      // Ensure trailing newline — block scalars at the end of the extracted
      // region need it for proper termination when parsed standalone.
      if (!extracted.endsWith('\n')) {
        extracted += '\n';
      }

      return _dedent(extracted);
    }

    // Fallback: re-serialize for scalar values or if span extraction failed.
    var value = node.value;
    if (value is String || value is num || value is bool || value == null) {
      return value?.toString();
    }
    var tempEditor = YamlEditor('');
    tempEditor.update([], value);
    return _formatBlockScalars(tempEditor.toString());
  }

  /// Remove common leading indentation from a multiline YAML fragment.
  String _dedent(String text) {
    var lines = text.split('\n');
    if (lines.length <= 1) return text;

    // Find the minimum indentation across non-empty lines (skip first line
    // which may have zero indent if the node starts at column 0).
    int? minIndent;
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      if (line.trimLeft().isEmpty) continue;
      var indent = line.length - line.trimLeft().length;
      if (minIndent == null || indent < minIndent) {
        minIndent = indent;
      }
    }

    if (minIndent == null || minIndent == 0) return text;

    return lines.map((line) {
      if (line.trimLeft().isEmpty) return '';
      return line.length >= minIndent! ? line.substring(minIndent) : line;
    }).join('\n');
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

  /// Replace the subtree at [path] with [yamlFragment], **preserving its
  /// exact YAML formatting** (block scalars, quoting, etc.).
  ///
  /// Unlike [replaceSubtreeAt], this method splices the raw fragment text
  /// directly into the document at the node's source span, so multiline
  /// block scalars (`|`, `>`) and other formatting are kept intact.
  ///
  /// The fragment is expected to be de-dented (base indent at column 0).
  /// It is automatically re-indented to match the original node's column
  /// before splicing.
  YamlDocumentModel replaceSubtreeRaw(List<Object> path, String yamlFragment) {
    if (path.isEmpty) return YamlDocumentModel.parse(yamlFragment);

    var node = nodeAt(path);
    if (node == null) return this;

    var source = _editor.toString();
    var span = node.span;
    var startOffset = span.start.offset;
    var endOffset = span.end.offset;
    var indent = span.start.column;

    // Re-indent: the document already contains `indent` spaces before
    // startOffset on the same line, so the first line needs no prefix.
    // Every subsequent non-empty line gets `indent` spaces prepended so
    // it aligns with the node's original column.
    var reindented = _reindentFragment(yamlFragment, indent);

    var newSource =
        source.substring(0, startOffset) + reindented + source.substring(endOffset);
    return YamlDocumentModel.parse(newSource);
  }

  /// Re-indent a de-dented YAML fragment for splicing back into a document.
  ///
  /// [indent] is the column of the target node (span.start.column).
  /// The first line is left unchanged (it will be placed at [indent] by the
  /// existing document text before the splice point). Every subsequent
  /// non-empty line gets [indent] spaces prepended.
  String _reindentFragment(String fragment, int indent) {
    var lines = fragment.split('\n');
    // Remove trailing empty element produced by a final '\n'
    if (lines.isNotEmpty && lines.last.isEmpty) {
      lines = lines.sublist(0, lines.length - 1);
    }
    if (lines.isEmpty) return '\n';
    if (indent == 0) {
      return '${lines.join('\n')}\n';
    }
    var prefix = ' ' * indent;
    var buf = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      if (i == 0) {
        buf.write(lines[i]);
      } else {
        buf.write(lines[i].isEmpty ? '' : '$prefix${lines[i]}');
      }
      buf.write('\n');
    }
    return buf.toString();
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

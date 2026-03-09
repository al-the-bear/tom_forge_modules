import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../tree/editor_trail.dart';

/// Convert a value to plain Dart objects (Map<String, ...>, List, scalars).
///
/// yaml_edit sometimes has issues when updating with values that contain
/// YamlNode references or non-String map keys. This helper ensures values
/// are fully "plain" before passing to yaml_edit.
Object? _toPlainDart(Object? value) {
  if (value is YamlMap) {
    return {
      for (var e in value.entries) e.key.toString(): _toPlainDart(e.value),
    };
  }
  if (value is YamlList) {
    return [for (var item in value) _toPlainDart(item)];
  }
  if (value is Map) {
    return {
      for (var e in value.entries) e.key.toString(): _toPlainDart(e.value),
    };
  }
  if (value is List) {
    return [for (var item in value) _toPlainDart(item)];
  }
  // Scalars (String, int, double, bool, null) pass through
  return value;
}

/// Wrap a value as a YamlNode with block collection style for maps/lists.
/// Used by [_normalizeYamlStyles] when converting flow-style to block-style.
YamlNode _wrapWithBlockStyle(Object? value) {
  if (value is Map) {
    // Recursively wrap map values
    final wrappedMap = <dynamic, YamlNode>{};
    for (var entry in value.entries) {
      wrappedMap[entry.key] = _wrapWithBlockStyle(entry.value);
    }
    return wrapAsYamlNode(wrappedMap, collectionStyle: CollectionStyle.BLOCK);
  } else if (value is List) {
    // Recursively wrap list items
    final wrappedList = value.map((e) => _wrapWithBlockStyle(e)).toList();
    return wrapAsYamlNode(wrappedList, collectionStyle: CollectionStyle.BLOCK);
  } else {
    return wrapAsYamlNode(value);
  }
}

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
  /// Normalize YAML output: multiline strings use literal block style (`|`),
  /// maps and lists use block style (key-per-line, item-per-line).
  String toYamlString() => _normalizeYamlStyles(_editor.toString());

  /// Normalize YAML styles for human readability:
  /// - Multiline strings → literal block scalar (`|`)
  /// - Flow-style maps `{key: value}` → block style
  /// - Flow-style lists `[a, b]` → block style
  ///
  /// Walks the parsed YAML tree to find nodes that need converting.
  String _normalizeYamlStyles(String yaml) {
    YamlNode root;
    try {
      root = loadYamlNode(yaml);
    } catch (_) {
      return yaml;
    }

    // Collect paths and wrapped values for nodes that need converting.
    var paths = <List<Object>>[];
    var wrappedValues = <YamlNode>[];
    _findNodesToNormalize(root, [], paths, wrappedValues);

    if (paths.isEmpty) return yaml;

    // Apply conversions using yaml_edit — each update properly adjusts
    // internal offsets so subsequent edits remain valid.
    var editor = YamlEditor(yaml);
    for (var i = 0; i < paths.length; i++) {
      editor.update(paths[i], wrappedValues[i]);
    }
    return editor.toString();
  }

  /// Recursively walk the YAML tree collecting paths and wrapped values
  /// for nodes that need style normalization.
  void _findNodesToNormalize(
    YamlNode node,
    List<Object> currentPath,
    List<List<Object>> paths,
    List<YamlNode> wrappedValues,
  ) {
    if (node is YamlMap) {
      // Check if this map is flow style and needs converting
      if (node.style == CollectionStyle.FLOW) {
        paths.add(currentPath);
        wrappedValues.add(_wrapWithBlockStyle(node.value));
        return; // Children are included in the wrapped value
      }
      // Recurse into children
      for (var entry in node.nodes.entries) {
        var key = (entry.key as YamlScalar).value;
        _findNodesToNormalize(
          entry.value,
          [...currentPath, key],
          paths,
          wrappedValues,
        );
      }
    } else if (node is YamlList) {
      // Check if this list is flow style and needs converting
      if (node.style == CollectionStyle.FLOW) {
        paths.add(currentPath);
        wrappedValues.add(_wrapWithBlockStyle(node.value));
        return; // Children are included in the wrapped value
      }
      // Recurse into children
      for (var i = 0; i < node.nodes.length; i++) {
        _findNodesToNormalize(
          node.nodes[i],
          [...currentPath, i],
          paths,
          wrappedValues,
        );
      }
    } else if (node is YamlScalar) {
      var value = node.value;
      if (value is String &&
          value.contains('\n') &&
          node.style != ScalarStyle.LITERAL &&
          node.style != ScalarStyle.FOLDED) {
        paths.add(currentPath);
        wrappedValues.add(wrapAsYamlNode(value, scalarStyle: ScalarStyle.LITERAL));
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
  /// String segments that represent valid integers are automatically coerced
  /// to [int] so that list items accessed via string indices (as stored in
  /// [YamlTreeData.path]) are resolved correctly by `yaml_edit`.
  /// Returns `null` if the path does not exist.
  YamlNode? nodeAt(List<Object> path) {
    try {
      return _editor.parseAt(_normalizePath(path));
    } catch (_) {
      return null;
    }
  }

  /// Convert any string segments in [path] that are valid non-negative
  /// integers to [int].  This allows callers to pass `List<String>` paths
  /// (as produced by [YamlTreeNodeBuilder]) and still reach list items whose
  /// `yaml_edit` path segments must be [int].
  List<Object> _normalizePath(List<Object> path) {
    return path.map<Object>((segment) {
      if (segment is String) {
        final index = int.tryParse(segment);
        if (index != null && index >= 0) return index;
      }
      return segment;
    }).toList();
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
    copy.update(_normalizePath(path), value);
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
    copy.update([..._normalizePath(parentPath), key], defaultValue);
    return YamlDocumentModel._(copy);
  }

  /// Create a new document with a key inserted adjacent to [siblingKey] in the
  /// map at [parentPath].
  ///
  /// If [above] is true, the new key is inserted before [siblingKey];
  /// otherwise it is inserted after.
  YamlDocumentModel withInsertedKeyAdjacent(
    List<Object> parentPath,
    String siblingKey,
    String newKey,
    Object? value, {
    required bool above,
  }) {
    trailEvent(
        'model: withInsertedKeyAdjacent parent=$parentPath sibling=$siblingKey '
        'newKey=$newKey above=$above');
    var node = nodeAt(parentPath);
    if (node == null || node.value is! Map) {
      // Parent doesn't exist or isn't a map - fall back to normal insert
      return withInsertedKey(parentPath, newKey, value);
    }
    var map = node.value as Map;
    var entries = map.entries.toList();
    var siblingIndex = entries.indexWhere((e) => e.key.toString() == siblingKey);
    if (siblingIndex < 0) {
      // Sibling not found - fall back to normal insert
      return withInsertedKey(parentPath, newKey, value);
    }

    // Build new map with key at desired position
    var insertIndex = above ? siblingIndex : siblingIndex + 1;
    var newEntries = <MapEntry<String, Object?>>[];
    for (var i = 0; i < entries.length; i++) {
      if (i == insertIndex) {
        newEntries.add(MapEntry(newKey, value));
      }
      newEntries.add(MapEntry(entries[i].key.toString(), entries[i].value));
    }
    // Handle insert at end
    if (insertIndex >= entries.length) {
      newEntries.add(MapEntry(newKey, value));
    }

    final newMap = {for (var e in newEntries) e.key: e.value};
    trailEvent('model: withInsertedKeyAdjacent newMap keys=${newMap.keys.toList()}');
    return withValueAt(parentPath, newMap);
  }

  /// Create a new document with a key removed at the given [path].
  ///
  /// The last element in [path] is the key to remove.
  YamlDocumentModel withRemovedKey(List<Object> path) {
    var copy = YamlEditor(_editor.toString());
    copy.remove(_normalizePath(path));
    return YamlDocumentModel._(copy);
  }

  /// Create a new document with the map key at [fromIndex] moved to [toIndex]
  /// within the map at [mapPath].
  ///
  /// The surrounding YAML formatting is not preserved for the map's values
  /// (they are re-serialized) but the overall document structure is intact.
  YamlDocumentModel withReorderedMapKey(
    List<Object> mapPath,
    int fromIndex,
    int toIndex,
  ) {
    var node = nodeAt(mapPath);
    if (node == null || node.value is! Map) return this;
    var entries = (node.value as Map).entries.toList();
    if (fromIndex == toIndex) return this;
    if (fromIndex < 0 ||
        fromIndex >= entries.length ||
        toIndex < 0 ||
        toIndex >= entries.length) {
      return this;
    }
    var moved = entries.removeAt(fromIndex);
    entries.insert(toIndex, moved);
    final newMap = {
      for (var e in entries) e.key.toString(): e.value,
    };
    return withValueAt(mapPath, newMap);
  }

  /// Create a new document with a value appended to the list at [listPath].
  YamlDocumentModel withAppendedToList(List<Object> listPath, Object? value) {
    trailEvent('model: withAppendedToList path=$listPath');
    try {
      var copy = YamlEditor(_editor.toString());
      copy.appendToList(_normalizePath(listPath), value);
      return YamlDocumentModel._(copy);
    } catch (e, st) {
      trailEvent('model: withAppendedToList EXCEPTION: $e');
      trailEvent('model: stack: ${st.toString().split('\n').take(5).join(' | ')}');
      rethrow;
    }
  }

  /// Create a new document with a value inserted into the list at [listPath]
  /// at [index].
  YamlDocumentModel withInsertedIntoList(
    List<Object> listPath,
    int index,
    Object? value,
  ) {
    trailEvent('model: withInsertedIntoList path=$listPath index=$index');
    try {
      var copy = YamlEditor(_editor.toString());
      var normalizedPath = _normalizePath(listPath);
      
      // Get current list length for validation
      var listNode = copy.parseAt(normalizedPath);
      var currentLength = listNode.value is List ? (listNode.value as List).length : 0;
      trailEvent('model: withInsertedIntoList listLength=$currentLength');
      
      // Clamp index to valid range: 0..currentLength (inclusive for append)
      var safeIndex = index.clamp(0, currentLength);
      trailEvent('model: withInsertedIntoList safeIndex=$safeIndex');
      
      // Work around yaml_edit bug: appendToList/insertIntoList at end fails.
      // Rebuild entire list with new item at correct position.
      if (safeIndex == currentLength && currentLength > 0) {
        trailEvent('model: using list-rebuild workaround for end insert');
        // Extract all existing items as plain Dart values
        var items = <Object?>[];
        for (var i = 0; i < currentLength; i++) {
          var itemNode = copy.parseAt([...normalizedPath, i]);
          items.add(_toPlainDart(itemNode.value));
        }
        // Append the new value
        items.add(_toPlainDart(value));
        // Replace entire list
        copy.update(normalizedPath, items);
        trailEvent('model: withInsertedIntoList rebuild done');
      } else if (currentLength == 0) {
        // Empty list - appendToList should work for empty lists
        trailEvent('model: using appendToList for empty list');
        copy.appendToList(normalizedPath, value);
      } else {
        trailEvent('model: using insertIntoList at $safeIndex');
        copy.insertIntoList(normalizedPath, safeIndex, value);
      }
      return YamlDocumentModel._(copy);
    } catch (e, st) {
      trailEvent('model: withInsertedIntoList EXCEPTION: $e');
      trailEvent('model: stack: ${st.toString().split('\n').take(5).join(' | ')}');
      rethrow;
    }
  }

  /// Create a new document with an item removed from the list at [path].
  ///
  /// The last element in [path] should be the integer index.
  YamlDocumentModel withRemovedFromList(List<Object> path) {
    trailEvent('model: withRemovedFromList path=$path');
    try {
      var copy = YamlEditor(_editor.toString());
      copy.remove(_normalizePath(path));
      return YamlDocumentModel._(copy);
    } catch (e, st) {
      trailEvent('model: withRemovedFromList EXCEPTION: $e');
      trailEvent('model: stack: ${st.toString().split('\n').take(5).join(' | ')}');
      rethrow;
    }
  }

  /// Move a list item from [oldIndex] to [newIndex] by rebuilding the list.
  ///
  /// This avoids yaml_edit's buggy update/swap operations by extracting all
  /// items, reordering them in Dart, and replacing the entire list.
  YamlDocumentModel withMovedListItem(
    List<Object> listPath,
    int oldIndex,
    int newIndex,
  ) {
    trailEvent('model: withMovedListItem path=$listPath old=$oldIndex new=$newIndex');
    try {
      var normalizedPath = _normalizePath(listPath);
      
      // Get current list
      var listNode = _editor.parseAt(normalizedPath);
      if (listNode.value is! List) {
        trailEvent('model: withMovedListItem ERROR not a list');
        return this;
      }
      var list = listNode.value as List;
      var length = list.length;
      
      // Validate indices
      if (oldIndex < 0 || oldIndex >= length) {
        trailEvent('model: withMovedListItem ERROR invalid oldIndex');
        return this;
      }
      
      // Clamp newIndex to valid target range (0..length-1 for existing positions)
      var targetIndex = newIndex.clamp(0, length - 1);
      if (newIndex >= length) {
        targetIndex = length - 1; // Move to last position
      }
      trailEvent('model: withMovedListItem targetIndex=$targetIndex');
      
      if (oldIndex == targetIndex) {
        trailEvent('model: withMovedListItem no-op same index');
        return this;
      }
      
      // Extract all items as plain Dart values
      var items = <Object?>[];
      for (var i = 0; i < length; i++) {
        var itemNode = _editor.parseAt([...normalizedPath, i]);
        items.add(_toPlainDart(itemNode.value));
      }
      
      // Reorder: remove from old position, insert at new position
      var movedItem = items.removeAt(oldIndex);
      items.insert(targetIndex, movedItem);
      
      // Replace entire list with reordered items
      var editor = YamlEditor(_editor.toString());
      editor.update(normalizedPath, items);
      
      trailEvent('model: withMovedListItem done');
      return YamlDocumentModel._(editor);
    } catch (e, st) {
      trailEvent('model: withMovedListItem EXCEPTION: $e');
      trailEvent('model: stack: ${st.toString().split('\n').take(5).join(' | ')}');
      rethrow;
    }
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

      // Normalize YAML styles (multiline strings → literal block, flow → block)
      // then dedent to remove leading whitespace.
      return _dedent(_normalizeYamlStyles(extracted));
    }

    // Fallback: re-serialize for scalar values or if span extraction failed.
    var value = node.value;
    if (value is String || value is num || value is bool || value == null) {
      return value?.toString();
    }
    var tempEditor = YamlEditor('');
    tempEditor.update([], value);
    return _normalizeYamlStyles(tempEditor.toString());
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
    var indent = span.start.column;

    // Determine the end of this node's block by scanning source lines forward
    // from span.start.line.
    //
    // We cannot rely on span.end.offset for multi-key block mappings because
    // the yaml package's span may only cover the last *value* in the map, not
    // all the preceding sibling keys. Using span.end would leave the original
    // keys in the document and then the fragment re-adds them → duplicate key.
    //
    // Rule: collect every line after startLine that is either blank or has
    // indentation >= indent. The block ends just before the first non-blank
    // line with indentation < indent.
    var sourceLines = source.split('\n');
    var startLine = span.start.line; // 0-based
    var lastBlockLine = startLine;
    for (var i = startLine + 1; i < sourceLines.length; i++) {
      var line = sourceLines[i];
      if (line.trim().isEmpty) continue; // blank line — tentatively skip
      var lineIndent = line.length - line.trimLeft().length;
      if (lineIndent >= indent) {
        lastBlockLine = i;
      } else {
        break;
      }
    }

    // Character offset of the start of the line AFTER lastBlockLine.
    var endOffset = 0;
    for (var i = 0; i <= lastBlockLine; i++) {
      endOffset += sourceLines[i].length + 1; // +1 for the '\n'
    }
    if (endOffset > source.length) endOffset = source.length;

    // Normalise the fragment to column-0 before re-indenting, in case the
    // caller passes text that still carries leading whitespace (safety net;
    // SubtreeInspector already dedents via subtreeYamlAt).
    var dedented = _dedent(yamlFragment);

    // Re-indent: the document already contains `indent` spaces before
    // startOffset on the same line, so the first line needs no prefix.
    // Every subsequent non-empty line gets `indent` spaces prepended so
    // it aligns with the node's original column.
    var reindented = _reindentFragment(dedented, indent);

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

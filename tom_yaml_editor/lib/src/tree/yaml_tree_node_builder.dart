import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:yaml/yaml.dart';

import '../model/yaml_document_model.dart';
import '../schema/schema_walker.dart';
import '../schema/yaml_schema.dart';

/// Data payload stored in each [TreeNode] for the YAML tree.
///
/// Carries all context needed to render a node: its path, key, YAML node,
/// schema information, and precomputed validation errors.
class YamlTreeData {
  /// Full path from the document root (e.g. `['prompt', 'meta-data', 'name']`).
  final List<String> path;

  /// The key name in the parent map, or the list index as string.
  final String key;

  /// The YAML node at this path (map, list, or scalar).
  final YamlNode? yamlNode;

  /// Schema node at this path (null when no schema is available).
  final SchemaNode? schemaNode;

  /// Direct validation errors at this exact path.
  final List<ValidationError> directErrors;

  /// Whether this is a map entry, list item, or root.
  final YamlNodeKind kind;

  const YamlTreeData({
    required this.path,
    required this.key,
    this.yamlNode,
    this.schemaNode,
    this.directErrors = const [],
    this.kind = YamlNodeKind.mapEntry,
  });

  /// The Dart value of this node (unwrapped from YamlNode).
  Object? get value => yamlNode?.value;

  /// Whether this node represents a container (map or list).
  bool get isContainer => yamlNode is YamlMap || yamlNode is YamlList;

  /// Whether this node is a leaf (scalar value).
  bool get isScalar => !isContainer;

  /// Whether this key is required by the schema.
  bool get isRequired => schemaNode?.required ?? false;

  /// Path as a joined string key (for hash lookups).
  String get pathKey => path.join('>');
}

/// Classification of a YAML node in the tree.
enum YamlNodeKind {
  /// A key/value pair in a YAML map.
  mapEntry,

  /// An item in a YAML list.
  listItem,

  /// The document root.
  root,
}

/// Walks a [YamlDocumentModel] and optional [SchemaWalker] to produce
/// a list of [TreeNode<YamlTreeData>] for rendering in a [TreeView].
///
/// Each node carries its path, key, YAML data, schema data, and validation
/// errors. Container nodes (maps, lists) have their children built
/// recursively.
///
/// ```dart
/// var builder = YamlTreeNodeBuilder(
///   document: controller.document,
///   schemaWalker: SchemaWalker(mySchema),
///   errors: controller.errors,
/// );
/// var roots = builder.build();
/// ```
class YamlTreeNodeBuilder {
  /// The YAML document model.
  final YamlDocumentModel document;

  /// Schema walker for type and constraint resolution (optional).
  final SchemaWalker? schemaWalker;

  /// Current validation errors (for decorating nodes).
  final List<ValidationError> errors;

  const YamlTreeNodeBuilder({
    required this.document,
    this.schemaWalker,
    this.errors = const [],
  });

  /// Build the tree node list from the root of the document.
  ///
  /// Returns a list of root-level tree nodes. For a typical YAML document
  /// with a single map root, this returns one node per top-level key.
  List<TreeNode<YamlTreeData>> build() {
    var root = document.rootNode;
    if (root is YamlMap) {
      return _buildMapChildren(root, [], schemaWalker?.schema.root);
    }
    if (root is YamlList) {
      return _buildListChildren(root, [], schemaWalker?.schema.root);
    }
    // Scalar root — single node
    return [
      TreeNode<YamlTreeData>(
        id: '',
        data: YamlTreeData(
          path: [],
          key: '',
          yamlNode: root,
          schemaNode: schemaWalker?.schema.root,
          directErrors: _directErrorsAt([]),
          kind: YamlNodeKind.root,
        ),
      ),
    ];
  }

  List<TreeNode<YamlTreeData>> _buildMapChildren(
    YamlMap map,
    List<String> parentPath,
    SchemaNode? parentSchema,
  ) {
    var nodes = <TreeNode<YamlTreeData>>[];

    for (var entry in map.nodes.entries) {
      var key = entry.key.toString();
      var path = [...parentPath, key];
      var childSchema = parentSchema?.properties[key];
      var yamlNode = entry.value;

      var data = YamlTreeData(
        path: path,
        key: key,
        yamlNode: yamlNode,
        schemaNode: childSchema,
        directErrors: _directErrorsAt(path),
        kind: YamlNodeKind.mapEntry,
      );

      var children = <TreeNode<YamlTreeData>>[];
      if (yamlNode is YamlMap) {
        children = _buildMapChildren(yamlNode, path, childSchema);
      } else if (yamlNode is YamlList) {
        children = _buildListChildren(yamlNode, path, childSchema);
      }

      nodes.add(TreeNode<YamlTreeData>(
        id: path.join('.'),
        data: data,
        children: children,
        isExpanded: children.isNotEmpty,
      ));
    }

    return nodes;
  }

  List<TreeNode<YamlTreeData>> _buildListChildren(
    YamlList list,
    List<String> parentPath,
    SchemaNode? parentSchema,
  ) {
    var nodes = <TreeNode<YamlTreeData>>[];
    var itemSchema = parentSchema?.items;

    for (var i = 0; i < list.nodes.length; i++) {
      var key = i.toString();
      var path = [...parentPath, key];
      var yamlNode = list.nodes[i];

      var data = YamlTreeData(
        path: path,
        key: key,
        yamlNode: yamlNode,
        schemaNode: itemSchema,
        directErrors: _directErrorsAt(path),
        kind: YamlNodeKind.listItem,
      );

      var children = <TreeNode<YamlTreeData>>[];
      if (yamlNode is YamlMap) {
        children = _buildMapChildren(yamlNode, path, itemSchema);
      } else if (yamlNode is YamlList) {
        children = _buildListChildren(yamlNode, path, itemSchema);
      }

      nodes.add(TreeNode<YamlTreeData>(
        id: path.join('.'),
        data: data,
        children: children,
        isExpanded: children.isNotEmpty,
      ));
    }

    return nodes;
  }

  List<ValidationError> _directErrorsAt(List<String> path) {
    var key = path.join('>');
    return errors
        .where((e) => e.path.map((p) => p.toString()).join('>') == key)
        .toList();
  }
}

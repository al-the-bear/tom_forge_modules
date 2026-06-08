/// The kind of a node in the §6b website-structure tree.
enum StructureNodeKind {
  /// A real filesystem directory (e.g. `components/`, or a grouped component).
  directory,

  /// A synthetic grouping node that has no file of its own (e.g. `areas`).
  group,

  /// A leaf file the user can open in an editor.
  file,
}

/// Which forge editor a file routes to in the structure explorer (§6b):
/// `.yaml`/`.yml` open the YAML editor, `.md`/`.markdown` the Markdown editor.
enum FileEditorKind {
  /// Opens in `tom_yaml_editor`.
  yaml,

  /// Opens in `tom_md_editor`.
  markdown,

  /// No specialized editor (e.g. an SVG diagram) — shown read-only.
  other,
}

/// A node in the website-structure tree (§6b).
///
/// Pure data, no Flutter dependency, so it is unit-testable. The controller
/// builds the tree; the explorer view renders it. A node with a non-null [uri]
/// is openable; [editorKind] names the editor it routes to.
class StructureNode {
  const StructureNode({
    required this.label,
    required this.kind,
    this.uri,
    this.editorKind,
    this.children = const [],
  });

  /// The display label (file name, or the slug for a grouped component/module).
  final String label;

  /// The node's role in the tree.
  final StructureNodeKind kind;

  /// The file/directory this node points to, or `null` for a pure [group].
  final Uri? uri;

  /// The editor a [file] node routes to, or `null` for directories/groups.
  final FileEditorKind? editorKind;

  /// Child nodes (modules under a component, files under a directory, …).
  final List<StructureNode> children;

  /// Whether this node points to a file the user can open.
  bool get isOpenable => uri != null && kind == StructureNodeKind.file;
}

/// Routes a file [uri] to the editor that opens it (§6b): `.yaml`/`.yml` → YAML,
/// `.md`/`.markdown` → Markdown, everything else → [FileEditorKind.other].
FileEditorKind editorKindForFile(Uri uri) {
  final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
  final lower = name.toLowerCase();
  if (lower.endsWith('.yaml') || lower.endsWith('.yml')) {
    return FileEditorKind.yaml;
  }
  if (lower.endsWith('.md') || lower.endsWith('.markdown')) {
    return FileEditorKind.markdown;
  }
  return FileEditorKind.other;
}

/// Builds a [StructureNode] leaf for a file [uri], routed by its extension.
StructureNode fileNode(Uri uri, {String? label}) => StructureNode(
      label: label ??
          (uri.pathSegments.isEmpty ? uri.toString() : uri.pathSegments.last),
      kind: StructureNodeKind.file,
      uri: uri,
      editorKind: editorKindForFile(uri),
    );

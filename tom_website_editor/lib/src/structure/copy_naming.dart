import 'website_structure_node.dart';

/// The kind of an external editorial copy file (website §16).
///
/// Copy lives as one Markdown file per component/module/submodule/area/home
/// under `content/copy/`, named by a fixed convention:
///
/// - `home.md`
/// - `<A>_area.md`
/// - `<C>_component.md`
/// - `<C>_<M>_module.md`
/// - `<C>_<M>_<S>_submodule.md`
enum CopyFileKind {
  /// The site home copy (`home.md`).
  home,

  /// An area copy (`<A>_area.md`).
  area,

  /// A component copy (`<C>_component.md`).
  component,

  /// A module copy (`<C>_<M>_module.md`).
  module,

  /// A submodule copy (`<C>_<M>_<S>_submodule.md`).
  submodule,
}

/// A parsed copy file name: its [kind] and the hierarchy [parts] before the
/// keyword (e.g. `['auth', 'login']` for `auth_login_module.md`). [home] has no
/// parts.
class CopyName {
  const CopyName(this.kind, this.parts);

  /// Which copy file this is.
  final CopyFileKind kind;

  /// The slug segments before the keyword (component / module / submodule /
  /// area names), in hierarchy order. Empty for [CopyFileKind.home].
  final List<String> parts;
}

/// The keyword suffix each non-home kind ends with, and how many slug [parts]
/// it requires before that keyword.
const Map<String, (CopyFileKind, int)> _keywords = {
  'area': (CopyFileKind.area, 1),
  'component': (CopyFileKind.component, 1),
  'module': (CopyFileKind.module, 2),
  'submodule': (CopyFileKind.submodule, 3),
};

/// Parses a §16 copy [fileName] (with its `.md` extension), or returns `null`
/// when it does not follow the convention (so the caller can keep it as a plain
/// file rather than dropping it).
CopyName? parseCopyFileName(String fileName) {
  if (!fileName.endsWith('.md')) return null;
  final stem = fileName.substring(0, fileName.length - '.md'.length);
  if (stem.isEmpty) return null;
  if (stem == 'home') return const CopyName(CopyFileKind.home, []);

  final segments = stem.split('_');
  final keyword = segments.last;
  final entry = _keywords[keyword];
  if (entry == null) return null;

  final (kind, expectedParts) = entry;
  final parts = segments.sublist(0, segments.length - 1);
  if (parts.length != expectedParts || parts.any((p) => p.isEmpty)) {
    return null;
  }
  return CopyName(kind, parts);
}

/// Encodes a §16 copy file name from its [kind] and slug [parts].
///
/// Throws [ArgumentError] when [parts] does not match the kind's arity, so a
/// malformed new-file request fails loudly rather than writing a bad path.
String copyFileName(CopyFileKind kind, {List<String> parts = const []}) {
  switch (kind) {
    case CopyFileKind.home:
      _requireParts(kind, parts, 0);
      return 'home.md';
    case CopyFileKind.area:
      _requireParts(kind, parts, 1);
      return '${parts[0]}_area.md';
    case CopyFileKind.component:
      _requireParts(kind, parts, 1);
      return '${parts[0]}_component.md';
    case CopyFileKind.module:
      _requireParts(kind, parts, 2);
      return '${parts.join('_')}_module.md';
    case CopyFileKind.submodule:
      _requireParts(kind, parts, 3);
      return '${parts.join('_')}_submodule.md';
  }
}

void _requireParts(CopyFileKind kind, List<String> parts, int expected) {
  if (parts.length != expected || parts.any((p) => p.isEmpty)) {
    throw ArgumentError(
        '${kind.name} copy file requires $expected non-empty part(s), '
        'got ${parts.length}: $parts');
  }
}

/// Groups a flat list of `content/copy/*.md` file [uris] into the §16
/// component → module → submodule tree, plus an `areas` group and the `home`
/// file. Files that do not follow the convention are surfaced verbatim as
/// top-level file nodes (never dropped).
List<StructureNode> groupCopyFiles(List<Uri> uris) {
  final components = <String, _Component>{};
  final areas = <String, Uri>{};
  final loose = <Uri>[];
  Uri? home;

  for (final uri in uris) {
    final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final parsed = parseCopyFileName(name);
    if (parsed == null) {
      loose.add(uri);
      continue;
    }
    switch (parsed.kind) {
      case CopyFileKind.home:
        home = uri;
      case CopyFileKind.area:
        areas[parsed.parts[0]] = uri;
      case CopyFileKind.component:
        components.putIfAbsent(parsed.parts[0], _Component.new).file = uri;
      case CopyFileKind.module:
        components
            .putIfAbsent(parsed.parts[0], _Component.new)
            .modules
            .putIfAbsent(parsed.parts[1], _Module.new)
            .file = uri;
      case CopyFileKind.submodule:
        components
            .putIfAbsent(parsed.parts[0], _Component.new)
            .modules
            .putIfAbsent(parsed.parts[1], _Module.new)
            .submodules[parsed.parts[2]] = uri;
    }
  }

  final nodes = <StructureNode>[];

  for (final name in components.keys.toList()..sort()) {
    nodes.add(_componentNode(name, components[name]!));
  }

  if (areas.isNotEmpty) {
    nodes.add(StructureNode(
      label: 'areas',
      kind: StructureNodeKind.group,
      children: [
        for (final name in areas.keys.toList()..sort())
          fileNode(areas[name]!, label: name),
      ],
    ));
  }

  if (home != null) nodes.add(fileNode(home, label: 'home'));

  for (final uri in loose..sort((a, b) => a.path.compareTo(b.path))) {
    nodes.add(fileNode(uri));
  }

  return nodes;
}

StructureNode _componentNode(String name, _Component component) {
  final children = <StructureNode>[
    for (final moduleName in component.modules.keys.toList()..sort())
      _moduleNode(moduleName, component.modules[moduleName]!),
  ];
  return StructureNode(
    label: name,
    kind:
        children.isEmpty ? StructureNodeKind.file : StructureNodeKind.directory,
    uri: component.file,
    editorKind:
        component.file == null ? null : editorKindForFile(component.file!),
    children: children,
  );
}

StructureNode _moduleNode(String name, _Module module) {
  final children = <StructureNode>[
    for (final subName in module.submodules.keys.toList()..sort())
      fileNode(module.submodules[subName]!, label: subName),
  ];
  return StructureNode(
    label: name,
    kind:
        children.isEmpty ? StructureNodeKind.file : StructureNodeKind.directory,
    uri: module.file,
    editorKind: module.file == null ? null : editorKindForFile(module.file!),
    children: children,
  );
}

class _Component {
  Uri? file;
  final Map<String, _Module> modules = {};
}

class _Module {
  Uri? file;
  final Map<String, Uri> submodules = {};
}

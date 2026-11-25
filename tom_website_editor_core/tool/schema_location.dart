// Where the committed JSON Schema of `tom.website-editor.yaml` lives: the Tom
// root's `.tom/json-schema/website-editor/`, the root being the nearest folder
// above the working directory that holds `.tom/tom_root.yaml`. A workspace
// folder's own `.tom` holds no schemas.
import 'dart:io';

import 'package:path/path.dart' as p;

/// The schema file's path below the root's `.tom`.
const websiteEditorSchemaRelativePath =
    'json-schema/website-editor/tom.website-editor.schema.json';

/// The Tom root above [from] (default: the working directory): the nearest
/// folder whose `.tom/tom_root.yaml` exists; `null` when there is none.
Directory? findTomRoot([Directory? from]) {
  var dir = (from ?? Directory.current).absolute;
  while (true) {
    if (File(p.join(dir.path, '.tom', 'tom_root.yaml')).existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
}

/// The committed schema file in the Tom root's `.tom`; throws a [StateError]
/// naming the start folder when no root is found above it.
File committedWebsiteEditorSchema([Directory? from]) {
  final root = findTomRoot(from);
  if (root == null) {
    throw StateError(
      'No Tom root (.tom/tom_root.yaml) above '
      '${(from ?? Directory.current).absolute.path}',
    );
  }
  return File(p.join(root.path, '.tom', websiteEditorSchemaRelativePath));
}

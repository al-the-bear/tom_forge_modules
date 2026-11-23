import 'package:flutter/material.dart' show Icons;
import 'package:tom_forge_kit/tom_forge_kit.dart';

import 'yaml_file_editor.dart';

/// The YAML file kind: `.yaml` and `.yml` files in [ForgeYamlFileEditor],
/// each over the [ForgeFileSession] the module that opens it makes.
///
/// An application takes it with the other kinds it opens files with and
/// hands them to its file module (Tom Forge: `ForgeFileEditorsModule`'s
/// [ForgeFileKindRegistry]); importing this package registers nothing. A
/// module that edits todo files (`*.todo.yaml`) asks its own kind first.
final ForgeKitFileKind forgeYamlFileKind = ForgeKitFileKind(
  id: 'yaml',
  label: 'YAML Editor',
  icon: Icons.data_object,
  extensions: const ['yaml', 'yml'],
  create: (request) => ForgeYamlFileEditor(
    session: request.session,
    module: request.module,
    api: request.api,
  ),
);

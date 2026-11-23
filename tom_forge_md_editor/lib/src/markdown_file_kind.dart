import 'package:flutter/material.dart' show Icons;
import 'package:tom_forge_kit/tom_forge_kit.dart';

import 'markdown_file_editor.dart';

/// The Markdown file kind: `.md` and `.markdown` files in
/// [ForgeMarkdownFileEditor], each over the [ForgeFileSession] the module
/// that opens it makes.
///
/// An application takes it with the other kinds it opens files with and
/// hands them to its file module (Tom Forge: `ForgeFileEditorsModule`'s
/// [ForgeFileKindRegistry]); importing this package registers nothing.
final ForgeKitFileKind forgeMarkdownFileKind = ForgeKitFileKind(
  id: 'markdown',
  label: 'Markdown Editor',
  icon: Icons.description_outlined,
  extensions: const ['md', 'markdown'],
  create: (request) => ForgeMarkdownFileEditor(
    session: request.session,
    module: request.module,
    api: request.api,
  ),
);

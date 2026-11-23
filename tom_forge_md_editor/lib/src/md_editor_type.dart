import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_md_editor/tom_md_editor.dart';

import 'forge_md_editor.dart';

/// The Markdown editor type: `.md` and `.markdown` files in [ForgeMdEditor].
///
/// An application takes it with the other editor types it opens files with
/// (the panel shell: `ForgeShellComponents(editorTypes: [...])`).
final ForgeKitEditorType forgeMarkdownEditorType = ForgeKitEditorType(
  id: 'md',
  label: 'Markdown Editor',
  description: 'Edit with rich markdown preview',
  extensions: const ['md', 'markdown'],
  actionDescriptors: MdEditorActions.descriptors,
  create: (request) => ForgeMdEditor(
    controller: MdEditorController(
      initialMarkdown: request.content,
      uri: request.uri,
    ),
    module: request.module,
    api: request.api,
  ),
);

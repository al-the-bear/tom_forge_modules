/// Forge's Markdown editor adapter: [ForgeMdEditor] makes the `tom_md_editor`
/// component a Forge editor over the kit (`tom_forge_kit`),
/// [forgeMarkdownEditorType] is the editor type an application opens `.md`
/// and `.markdown` files with, and [forgeMarkdownFileKind] the file kind a
/// file module opens them with over a file session
/// ([ForgeMarkdownFileEditor]).
library;

export 'src/forge_md_editor.dart';
export 'src/markdown_file_editor.dart';
export 'src/markdown_file_kind.dart';
export 'src/md_editor_type.dart';

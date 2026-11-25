/// Forge's Markdown editor adapter: [ForgeMdEditor] makes the `tom_md_editor`
/// component a Forge editor over the kit (`tom_forge_kit`),
/// [forgeMarkdownEditorType] is the editor type an application opens `.md`
/// and `.markdown` files with, and [forgeMarkdownFileKind] the file kind a
/// file module opens them with over a file session
/// ([ForgeMarkdownFileEditor]).
///
/// The editor runs with the Markdown plugin packages ([forgeMdContentPlugins]:
/// Mermaid and math); the controller extensions of the DocSpecs and review
/// plugins ([MdDocSpecsEditing], [MdReviewEditing]) are exported with it.
library;

export 'package:tom_md_docspecs/tom_md_docspecs.dart' show MdDocSpecsEditing;
export 'package:tom_md_review/tom_md_review.dart' show MdReviewEditing;

export 'src/forge_md_editor.dart';
export 'src/markdown_file_editor.dart';
export 'src/markdown_file_kind.dart';
export 'src/md_editor_configuration.dart';
export 'src/md_editor_type.dart';
export 'src/md_plugins.dart';

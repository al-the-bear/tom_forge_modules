/// Forge's code editors in the shell, kept for one release: a re-export of
/// the three editor adapters (`tom_forge_md_editor`, `tom_forge_dart_editor`,
/// `tom_forge_yaml_editor`) with the shell-typed helpers it had
/// ([forgeCodeEditorComponents], `dartSummaryAssets` on the layout
/// controller, `registerMdEditor` and its twins on the shell's module).
///
/// New code takes the adapter it uses.
library;

export 'package:tom_forge_dart_editor/tom_forge_dart_editor.dart';
export 'package:tom_forge_md_editor/tom_forge_md_editor.dart';
export 'package:tom_forge_yaml_editor/tom_forge_yaml_editor.dart';

export 'src/code_editor_types.dart';

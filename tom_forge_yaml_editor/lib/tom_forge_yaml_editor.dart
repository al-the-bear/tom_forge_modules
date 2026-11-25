/// Forge's YAML editor adapter: [ForgeYamlEditor] makes the `tom_yaml_editor`
/// component a Forge editor over the kit (`tom_forge_kit`),
/// [forgeYamlEditorType] is the editor type an application opens `.yaml` and
/// `.yml` files with, and [forgeYamlFileKind] the file kind a file module
/// opens them with over a file session ([ForgeYamlFileEditor]).
library;

export 'src/forge_yaml_editor.dart';
export 'src/yaml_editor_configuration.dart';
export 'src/yaml_editor_type.dart';
export 'src/yaml_file_editor.dart';
export 'src/yaml_file_kind.dart';

import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

import 'forge_yaml_editor.dart';
import 'yaml_editor_configuration.dart';

/// The YAML editor type: `.yaml` and `.yml` files in [ForgeYamlEditor].
///
/// An application takes it with the other editor types it opens files with
/// (the panel shell: `ForgeShellComponents(editorTypes: [...])`).
final ForgeKitEditorType forgeYamlEditorType = ForgeKitEditorType(
  id: 'yaml',
  label: 'YAML Editor',
  description: 'Edit with YAML structure view',
  extensions: const ['yaml', 'yml'],
  actionDescriptors: YamlEditorActions.descriptors,
  configuration: ForgeYamlEditorConfiguration.description,
  create: (request) => ForgeYamlEditor(
    controller: YamlEditorController(
      initialYaml: request.content,
      uri: request.uri,
    ),
    module: request.module,
    api: request.api,
  ),
);

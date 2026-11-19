import 'package:tom_dart_editor/tom_dart_editor.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart';
import 'package:tom_md_editor/tom_md_editor.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

import 'forge_dart_editor.dart';
import 'forge_md_editor.dart';
import 'forge_yaml_editor.dart';

/// The Markdown editor type: `.md` and `.markdown` files in
/// [ForgeMdEditor].
final ForgeEditorType forgeMarkdownEditorType = ForgeEditorType(
  id: 'md',
  label: 'Markdown Editor',
  description: 'Edit with rich markdown preview',
  extensions: const ['md', 'markdown'],
  create: (request) => ForgeMdEditor(
    controller: MdEditorController(
      initialMarkdown: request.content,
      uri: request.uri,
    ),
    module: request.module,
  ),
);

/// The Dart editor type: `.dart` files in [ForgeDartEditor], reading its
/// analysis summaries where the layout controller's
/// [ForgeDartSummariesOnLayout.dartSummaryAssets] says.
final ForgeEditorType forgeDartEditorType = ForgeEditorType(
  id: 'dart',
  label: 'Dart Code Editor',
  description: 'Edit with Dart syntax highlighting',
  extensions: const ['dart'],
  create: (request) => ForgeDartEditor(
    controller: DartCodeController(
      initialCode: request.content,
      uri: request.uri,
    ),
    module: request.module,
    summaries: _summaries[request.layout] ?? ForgeDartSummaryAssets.root,
  ),
);

/// The YAML editor type: `.yaml` and `.yml` files in [ForgeYamlEditor].
final ForgeEditorType forgeYamlEditorType = ForgeEditorType(
  id: 'yaml',
  label: 'YAML Editor',
  description: 'Edit with YAML structure view',
  extensions: const ['yaml', 'yml'],
  create: (request) => ForgeYamlEditor(
    controller: YamlEditorController(
      initialYaml: request.content,
      uri: request.uri,
    ),
    module: request.module,
  ),
);

/// The code editor types, in the order **Open With** offers them, and as
/// [ForgeShellComponents] to register or give a shell.
final ForgeShellComponents forgeCodeEditorComponents = ForgeShellComponents(
  editorTypes: [
    forgeMarkdownEditorType,
    forgeDartEditorType,
    forgeYamlEditorType,
  ],
);

final Expando<ForgeDartSummaryAssets> _summaries = Expando('dartSummaryAssets');

/// Where the Dart editors a layout controller opens read their analysis
/// summaries: the running app's own assets ([ForgeDartSummaryAssets.root])
/// unless the app is built on a package that carries them.
extension ForgeDartSummariesOnLayout on DefaultLayoutController {
  ForgeDartSummaryAssets get dartSummaryAssets =>
      _summaries[this] ?? ForgeDartSummaryAssets.root;

  set dartSummaryAssets(ForgeDartSummaryAssets assets) =>
      _summaries[this] = assets;
}

/// The code editors registered with the shell's own module, by type.
extension ForgeCodeEditorsOnShellModule on TomForgeShellModule {
  /// Registers a [ForgeMdEditor] adapter and returns it.
  ForgeMdEditor registerMdEditor(ForgeMdEditor editor) =>
      registerEditor(editor);

  /// Registers a [ForgeDartEditor] adapter and returns it.
  ForgeDartEditor registerDartEditor(ForgeDartEditor editor) =>
      registerEditor(editor);

  /// Registers a [ForgeYamlEditor] adapter and returns it.
  ForgeYamlEditor registerYamlEditor(ForgeYamlEditor editor) =>
      registerEditor(editor);

  /// All registered Dart editors.
  List<ForgeDartEditor> get dartEditors =>
      editors.whereType<ForgeDartEditor>().toList();

  /// All registered Markdown editors.
  List<ForgeMdEditor> get mdEditors =>
      editors.whereType<ForgeMdEditor>().toList();

  /// All registered YAML editors.
  List<ForgeYamlEditor> get yamlEditors =>
      editors.whereType<ForgeYamlEditor>().toList();
}

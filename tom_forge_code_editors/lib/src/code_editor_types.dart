import 'package:tom_forge_dart_editor/tom_forge_dart_editor.dart';
import 'package:tom_forge_md_editor/tom_forge_md_editor.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart';
import 'package:tom_forge_yaml_editor/tom_forge_yaml_editor.dart';

/// The code editor types, in the order **Open With** offers them, as
/// [ForgeShellComponents] to register or give a shell.
///
/// Kept for one release: an application takes the types it uses from the
/// adapter packages (`forgeMarkdownEditorType`, `forgeDartEditorType`,
/// `forgeYamlEditorType`) as `ForgeShellComponents(editorTypes: [...])`.
final ForgeShellComponents forgeCodeEditorComponents = ForgeShellComponents(
  editorTypes: [
    forgeMarkdownEditorType,
    forgeDartEditorType,
    forgeYamlEditorType,
  ],
);

/// Where the Dart editors a layout controller opens read their analysis
/// summaries: the running app's own assets ([ForgeDartSummaryAssets.root])
/// unless the app is built on a package that carries them.
///
/// Kept for one release: [ForgeDartSummariesByHost] of
/// `tom_forge_dart_editor`, keyed by the layout controller, says the same.
extension ForgeDartSummariesOnLayout on DefaultLayoutController {
  ForgeDartSummaryAssets get dartSummaryAssets =>
      ForgeDartSummariesByHost.of(this);

  set dartSummaryAssets(ForgeDartSummaryAssets assets) =>
      ForgeDartSummariesByHost.set(this, assets);
}

/// The code editors registered with the shell's own module, by type.
///
/// Kept for one release: `registerEditor` and `editors.whereType<...>()` do
/// the same.
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

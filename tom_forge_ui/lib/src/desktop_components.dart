import 'package:tom_forge_dart_editor/tom_forge_dart_editor.dart';
import 'package:tom_forge_desktop_host/tom_forge_desktop_host.dart';
import 'package:tom_forge_file_explorer/tom_forge_file_explorer.dart';
import 'package:tom_forge_md_editor/tom_forge_md_editor.dart';
import 'package:tom_forge_outline_view/tom_forge_outline_view.dart';
import 'package:tom_forge_output_view/tom_forge_output_view.dart';
import 'package:tom_forge_platform_secrets/tom_forge_platform_secrets.dart';
import 'package:tom_forge_problems_view/tom_forge_problems_view.dart';
import 'package:tom_forge_revision_view/tom_forge_revision_view.dart';
import 'package:tom_forge_search_view/tom_forge_search_view.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart';
import 'package:tom_forge_terminal/tom_forge_terminal.dart';
import 'package:tom_forge_yaml_editor/tom_forge_yaml_editor.dart';

/// Forge on the desktop: the terminal, the Markdown, Dart and YAML editor
/// types of the editor adapters, the platform keychain and the desktop host
/// (file dialogs, shells, folders) together, as [ForgeShellComponents].
final ForgeShellComponents forgeDesktopComponents = forgeTerminalComponents
    .mergedWith(
      ForgeShellComponents(
        editorTypes: [
          forgeMarkdownEditorType,
          forgeDartEditorType,
          forgeYamlEditorType,
        ],
      ),
    )
    .mergedWith(forgePlatformSecretComponents)
    .mergedWith(forgeDesktopHostComponents);

/// Registers [forgeDesktopComponents]: every shell made afterwards without
/// components of its own has the terminal, the code editors and the
/// keychain. An application calls it once at start; a test package calls it
/// in its `flutter_test_config.dart`.
void useForgeDesktopComponents() =>
    ForgeShellComponents.register(forgeDesktopComponents);

/// The modules of the views, packages of their own — Explorer, Problems,
/// Search, Outline, Output, Revisions — new for one shell: each made at
/// activation from the shell's API and placed by its hint
/// (`forgeContributedPanelTabs`). The file explorer and the Search view show
/// [workspaceRootUri] (default: the shell state's workspace folder). A host
/// registers them (`DefaultShellApi.registerModule`) and lays its panels out
/// from the registry; the shell itself names none of them.
List<ForgeKitModule> forgeDesktopViewModules({Uri? workspaceRootUri}) => [
  forgeFileExplorerModule(rootUri: workspaceRootUri),
  forgeProblemsViewModule(),
  forgeSearchViewModule(workspaceRoot: workspaceRootUri?.toFilePath()),
  forgeOutlineViewModule(),
  forgeOutputViewModule(),
  forgeRevisionViewModule(),
];

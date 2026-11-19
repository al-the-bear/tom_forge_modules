/// Forge's desktop host for the panel shell (`tom_forge_shell`): the native
/// file dialogs (file_picker, file_selector), the machine's shells and
/// folders (`dart:io`) as [ForgeShellComponents]
/// ([forgeDesktopHostComponents]), the workspace folder above a picked folder
/// and keeping `.forge/` out of git ([detectForgeWorkspaceRoot],
/// [keepForgeStateOutOfGit]), and the workspace folder selector.
library;

export 'src/desktop_host.dart';
export 'src/forge_host_workspace.dart';
export 'src/workspace_folder_selector.dart';

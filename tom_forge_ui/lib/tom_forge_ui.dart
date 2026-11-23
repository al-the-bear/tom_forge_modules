/// Tom Forge UI: Forge's panel shell with the terminal, the code editors
/// and the platform keychain, as one library.
///
/// It re-exports `tom_forge_shell`, `tom_forge_terminal`, the editor
/// adapters (`tom_forge_md_editor`, `tom_forge_dart_editor`,
/// `tom_forge_yaml_editor`, with `tom_forge_code_editors`' helpers for one
/// release), `tom_forge_platform_secrets` and `tom_forge_desktop_host`.
/// Shells take the
/// terminal, the code editors and the keychain once
/// [useForgeDesktopComponents] has registered them (or when given
/// [forgeDesktopComponents]); a shell made before has only the core's.
library;

// The editor adapters, with the shell-typed helpers tom_forge_code_editors
// keeps for one release (dartSummaryAssets, registerMdEditor and its twins).
export 'package:tom_forge_code_editors/tom_forge_code_editors.dart';
export 'package:tom_forge_dart_editor/tom_forge_dart_editor.dart';
export 'package:tom_forge_desktop_host/tom_forge_desktop_host.dart';
export 'package:tom_forge_md_editor/tom_forge_md_editor.dart';
export 'package:tom_forge_plain_text_editor/tom_forge_plain_text_editor.dart';
export 'package:tom_forge_platform_secrets/tom_forge_platform_secrets.dart';
export 'package:tom_forge_shell/tom_forge_shell.dart';
export 'package:tom_forge_terminal/tom_forge_terminal.dart';
export 'package:tom_forge_yaml_editor/tom_forge_yaml_editor.dart';

export 'src/desktop_components.dart';

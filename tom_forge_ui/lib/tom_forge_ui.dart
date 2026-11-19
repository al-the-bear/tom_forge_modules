/// Tom Forge UI: Forge's panel shell with the terminal, the code editors
/// and the platform keychain, as one library.
///
/// It re-exports `tom_forge_shell`, `tom_forge_terminal`,
/// `tom_forge_code_editors`, `tom_forge_platform_secrets` and
/// `tom_forge_desktop_host`. Shells take the
/// terminal, the code editors and the keychain once
/// [useForgeDesktopComponents] has registered them (or when given
/// [forgeDesktopComponents]); a shell made before has only the core's.
library;

export 'package:tom_forge_code_editors/tom_forge_code_editors.dart';
export 'package:tom_forge_desktop_host/tom_forge_desktop_host.dart';
export 'package:tom_forge_platform_secrets/tom_forge_platform_secrets.dart';
export 'package:tom_forge_shell/tom_forge_shell.dart';
export 'package:tom_forge_terminal/tom_forge_terminal.dart';

export 'src/desktop_components.dart';

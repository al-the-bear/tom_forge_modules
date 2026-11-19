import 'package:tom_forge_code_editors/tom_forge_code_editors.dart';
import 'package:tom_forge_platform_secrets/tom_forge_platform_secrets.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart';
import 'package:tom_forge_terminal/tom_forge_terminal.dart';

/// Forge on the desktop: the terminal, the code editors and the platform
/// keychain together, as [ForgeShellComponents].
final ForgeShellComponents forgeDesktopComponents = forgeTerminalComponents
    .mergedWith(forgeCodeEditorComponents)
    .mergedWith(forgePlatformSecretComponents);

/// Registers [forgeDesktopComponents]: every shell made afterwards without
/// components of its own has the terminal, the code editors and the
/// keychain. An application calls it once at start; a test package calls it
/// in its `flutter_test_config.dart`.
void useForgeDesktopComponents() =>
    ForgeShellComponents.register(forgeDesktopComponents);

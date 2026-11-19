import 'package:tom_file_system/io.dart' show TomLocalFileSystem;
import 'package:tom_forge_shell/tom_forge_shell.dart';

import 'platform_secret_storage.dart';

/// The platform keychain as [ForgeShellComponents]: a shell over a folder on
/// disk keeps its secrets in the keychain ([PlatformSecretStorage]), any
/// other in memory ([DefaultSecretStorage]).
final ForgeShellComponents forgePlatformSecretComponents = ForgeShellComponents(
  secretStorage: (fileSystem) => fileSystem is TomLocalFileSystem
      ? PlatformSecretStorage()
      : DefaultSecretStorage(),
);

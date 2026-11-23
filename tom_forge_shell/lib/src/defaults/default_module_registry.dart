import 'package:tom_forge_kit/tom_forge_kit.dart';

import '../module/forge_module.dart';
import '../shell/forge_module_registry.dart';
import '../shell/forge_system_state.dart';

/// Default implementation of [ForgeModuleRegistry]: the kit's
/// [DefaultKitModuleRegistry] over the shell's modules — its
/// [ForgeModule]s and modules written against the kit alone
/// ([ForgeKitModule]s).
///
/// Stores modules by type and provides typed access. Module activation
/// failures are isolated — one failing module does not crash the shell.
/// Errors are reported to diagnostics, notifications, and the shell
/// output channel. [register] takes any [ForgeKitModule]; the shell's
/// `DefaultShellApi.registerModule` also activates it with the shell's API.
class DefaultModuleRegistry extends DefaultKitModuleRegistry<ForgeKitModule>
    implements ForgeModuleRegistry {
  static bool debugEnabled = false;

  DefaultModuleRegistry({
    super.actionRegistry,
    super.shortcutManager,
    super.diagnosticManager,
    super.notificationManager,
    super.outputManager,
  });

  /// The shell's state, set after construction when wiring shell services.
  @override
  ForgeSystemState? get systemState => super.systemState as ForgeSystemState?;

  @override
  set systemState(covariant ForgeSystemState? value) =>
      super.systemState = value;

  @override
  bool get debugLogging =>
      debugEnabled || DefaultKitModuleRegistry.debugEnabled;

  /// The registered [ForgeModule]s; [allKitModules] adds the modules written
  /// against the kit alone.
  @override
  List<ForgeModule> get allModules =>
      List.unmodifiable(allKitModules.whereType<ForgeModule>());
}

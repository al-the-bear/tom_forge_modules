import '../module/forge_kit_module_registry.dart';
import 'forge_kit_api.dart';

/// An API that tells the modules registered with it, so a component lists
/// what they contribute (the actions of a module not yet in the action
/// registry, in quick open and the command palette).
///
/// `DefaultKitApi` and the panel shell's `DefaultShellApi` are one;
/// [forgeKitModulesOf] answers null for another API.
abstract interface class ForgeKitModulesHost {
  /// The registered modules.
  ForgeKitModuleRegistry get modules;
}

/// The modules registered with [api] when it tells them
/// ([ForgeKitModulesHost]); else null.
ForgeKitModuleRegistry? forgeKitModulesOf(ForgeKitApi api) => switch (api) {
  final ForgeKitModulesHost host => host.modules,
  _ => null,
};

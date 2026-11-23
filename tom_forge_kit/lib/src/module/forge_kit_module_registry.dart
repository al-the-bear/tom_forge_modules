import 'forge_kit_module.dart';

/// The modules a host has registered, in registration order.
abstract class ForgeKitModuleRegistry {
  /// The registered modules, as the host's own registry types them (the
  /// panel shell answers only its `ForgeModule`s here).
  List<ForgeKitModule> get allModules;

  /// Every registered module, whatever its type, in registration order: what
  /// a reader typed on the kit iterates (context menus, opening files).
  List<ForgeKitModule> get allKitModules;
}

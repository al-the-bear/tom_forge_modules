import 'forge_kit_module.dart';

/// The modules a host has registered, in registration order.
abstract class ForgeKitModuleRegistry {
  List<ForgeKitModule> get allModules;
}

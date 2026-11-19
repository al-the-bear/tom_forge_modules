import '../module/forge_module.dart';

/// Registry for accessing modules by type.
abstract class ForgeModuleRegistry {
  T get<T extends ForgeModule>();
  List<ForgeModule> get allModules;
}

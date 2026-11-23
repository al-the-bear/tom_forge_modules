import 'package:tom_forge_kit/tom_forge_kit.dart';

import '../module/forge_module.dart';

/// Registry for accessing modules by type.
abstract class ForgeModuleRegistry implements ForgeKitModuleRegistry {
  T get<T extends ForgeModule>();

  @override
  List<ForgeModule> get allModules;
}

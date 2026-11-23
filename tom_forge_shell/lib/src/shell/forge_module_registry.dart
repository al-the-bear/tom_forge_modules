import 'package:tom_forge_kit/tom_forge_kit.dart';

import '../module/forge_module.dart';

/// Registry for accessing modules by type.
///
/// It holds the panel shell's [ForgeModule]s and modules written against the
/// kit alone ([ForgeKitModule]s): [allModules] answers the former, as the
/// shell's own readers use their shell members; [allKitModules] every
/// registered module, which is what a reader iterates for what any module
/// contributes (editors, views, actions, opening files and the extras read
/// through [forgeModuleStatusItems], [forgeModuleSettingsSections] and
/// [forgeModuleExternalTools]).
abstract class ForgeModuleRegistry implements ForgeKitModuleRegistry {
  /// The registered module of type [T] (a [ForgeModule] or a
  /// [ForgeKitModule]); throws when there is none.
  T get<T extends ForgeKitModule>();

  /// The registered [ForgeModule]s, in registration order.
  @override
  List<ForgeModule> get allModules;
}

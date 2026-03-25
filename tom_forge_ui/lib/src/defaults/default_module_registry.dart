import '../module/forge_module.dart';
import '../shell/forge_module_registry.dart';

/// Default implementation of [ForgeModuleRegistry].
///
/// Stores modules by type and provides typed access.
class DefaultModuleRegistry implements ForgeModuleRegistry {
  static bool debugEnabled = false;

  final Map<Type, ForgeModule> _modules = {};

  /// Register a module by its runtime type.
  void register(ForgeModule module) {
    _modules[module.runtimeType] = module;
  }

  @override
  T get<T extends ForgeModule>() {
    final module = _modules.values.whereType<T>().firstOrNull;
    if (module == null) {
      throw StateError('Module of type $T not registered');
    }
    return module;
  }

  @override
  List<ForgeModule> get allModules => List.unmodifiable(_modules.values);
}

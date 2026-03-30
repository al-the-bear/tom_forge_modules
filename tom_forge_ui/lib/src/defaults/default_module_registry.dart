import '../module/forge_module.dart';
import '../shell/forge_module_registry.dart';
import '../services/forge_action_registry.dart';
import '../services/forge_shortcut_manager.dart';

/// Default implementation of [ForgeModuleRegistry].
///
/// Stores modules by type and provides typed access.
class DefaultModuleRegistry implements ForgeModuleRegistry {
  static bool debugEnabled = false;

  DefaultModuleRegistry({
    ForgeActionRegistry? actionRegistry,
    ForgeShortcutManager? shortcutManager,
  })  : _actionRegistry = actionRegistry,
        _shortcutManager = shortcutManager;

  final Map<Type, ForgeModule> _modules = {};
  final ForgeActionRegistry? _actionRegistry;
  final ForgeShortcutManager? _shortcutManager;

  /// Register a module by its runtime type.
  void register(ForgeModule module) {
    try {
      final existing = _modules[module.runtimeType];
      if (debugEnabled && existing != null) {
        // ignore: avoid_print
        print(
          '[DefaultModuleRegistry] replacing module '
          '${module.runtimeType} (${existing.displayName} -> ${module.displayName})',
        );
      }

      _modules[module.runtimeType] = module;

      final actionRegistry = _actionRegistry;
      if (actionRegistry != null) {
        for (final action in module.actions) {
          actionRegistry.registerAction(action);
        }
      }

      final shortcutManager = _shortcutManager;
      if (shortcutManager != null) {
        for (final binding in module.shortcuts) {
          shortcutManager.rebind(binding.action, binding.key);
        }
      }
    } catch (error, stackTrace) {
      // ignore: avoid_print
      print('[DefaultModuleRegistry] register failed for '
          '${module.displayName}: $error');
      // ignore: avoid_print
      print(stackTrace);
      // Isolation boundary: log and continue so one failing module
      // does not prevent other modules from registering.
      }
  }

  /// Deactivates all registered modules in reverse registration order.
  ///
  /// Called during shell shutdown to give each module a chance to release
  /// resources. Exceptions during deactivation are caught and logged so
  /// that one failing module does not prevent the remaining modules from
  /// being deactivated.
  void deactivateAll() {
    final reversed = _modules.values.toList().reversed;
    for (final module in reversed) {
      try {
        if (debugEnabled) {
          // ignore: avoid_print
          print(
            '[DefaultModuleRegistry] deactivating ${module.displayName}',
          );
        }
        module.deactivate();
      } catch (error, stackTrace) {
        // ignore: avoid_print
        print(
          '[DefaultModuleRegistry] deactivate failed for '
          '${module.displayName}: $error',
        );
        // ignore: avoid_print
        print(stackTrace);
      }
    }
    _modules.clear();
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

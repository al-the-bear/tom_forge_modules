import 'package:tom_forge_core/tom_forge_core.dart'
    show
        ForgeDiagnostic,
        ForgeDiagnosticCollection,
        ForgeDiagnosticManager,
        ForgeErrorCodes,
        ForgeNotificationManager,
        ForgeOutputChannelManager,
        ForgeSeverity,
        ForgeTextRange;

import '../module/forge_module.dart';
import '../shell/forge_module_registry.dart';
import '../services/forge_action_registry.dart';
import '../services/forge_shortcut_manager.dart';

/// State of a registered module.
enum ModuleState {
  /// Module registered but not yet activated.
  registered,

  /// Module activated successfully.
  active,

  /// Module activation or runtime failure.
  error,
}

/// Default implementation of [ForgeModuleRegistry].
///
/// Stores modules by type and provides typed access. Module activation
/// failures are isolated — one failing module does not crash the shell.
/// Errors are reported to diagnostics, notifications, and the shell
/// output channel.
class DefaultModuleRegistry implements ForgeModuleRegistry {
  static bool debugEnabled = false;

  DefaultModuleRegistry({
    ForgeActionRegistry? actionRegistry,
    ForgeShortcutManager? shortcutManager,
    this.diagnosticManager,
    this.notificationManager,
    this.outputManager,
  })  : _actionRegistry = actionRegistry,
        _shortcutManager = shortcutManager;

  final Map<Type, ForgeModule> _modules = {};
  final Map<Type, ModuleState> _moduleStates = {};
  final ForgeActionRegistry? _actionRegistry;
  final ForgeShortcutManager? _shortcutManager;

  /// Set after construction when wiring shell services.
  ForgeDiagnosticManager? diagnosticManager;

  /// Set after construction when wiring shell services.
  ForgeNotificationManager? notificationManager;

  /// Set after construction when wiring shell services.
  ForgeOutputChannelManager? outputManager;

  ForgeDiagnosticCollection? _shellDiagnostics;

  /// Returns the activation state of a registered module.
  ModuleState moduleStateOf(ForgeModule module) =>
      _moduleStates[module.runtimeType] ?? ModuleState.registered;

  /// All modules currently in error state.
  List<ForgeModule> get errorModules => _modules.values
      .where((m) => _moduleStates[m.runtimeType] == ModuleState.error)
      .toList();

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
      _moduleStates[module.runtimeType] = ModuleState.active;

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
      _moduleStates[module.runtimeType] = ModuleState.error;
      _reportModuleError(
        module.displayName,
        ForgeErrorCodes.mdActivationFailed,
        'Module failed to activate: ${module.displayName}',
        error,
        stackTrace,
      );
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
        _moduleStates[module.runtimeType] = ModuleState.error;
        _reportModuleError(
          module.displayName,
          ForgeErrorCodes.mdException,
          'Module threw exception during deactivation: ${module.displayName}',
          error,
          stackTrace,
        );
      }
    }
    _modules.clear();
    _moduleStates.clear();
    _shellDiagnostics?.dispose();
  }

  void _reportModuleError(
    String moduleName,
    String code,
    String message,
    Object error,
    StackTrace stackTrace,
  ) {
    // 1. Log to output channel "Tom Forge Shell"
    final om = outputManager;
    if (om != null) {
      final channel = om.get('Tom Forge Shell') ?? om.create('Tom Forge Shell');
      channel.appendLine('$message: $error');
      channel.appendLine(stackTrace.toString());
    }

    // 2. Emit diagnostic to Problems view
    final dm = diagnosticManager;
    if (dm != null) {
      _shellDiagnostics ??= dm.createCollection('shell');
      final uri = Uri.parse('forge://modules/$moduleName');
      _shellDiagnostics!.set(uri, [
        ForgeDiagnostic(
          uri: uri,
          range: const ForgeTextRange.empty(),
          message: '$message: $error',
          severity: ForgeSeverity.error,
          source: 'Shell',
          code: code,
        ),
      ]);
    }

    // 3. Toast notification
    notificationManager?.showError(
      'Failed to activate $moduleName. See Problems view.',
    );

    // 4. Console log (always)
    // ignore: avoid_print
    print('[DefaultModuleRegistry] $message: $error');
    // ignore: avoid_print
    print(stackTrace);
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

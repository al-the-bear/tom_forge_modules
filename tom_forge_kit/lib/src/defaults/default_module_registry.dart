import 'dart:async';

import 'package:tom_forge_core/tom_forge_core.dart'
    show
        DiagnosticCategory,
        ForgeDiagnostic,
        ForgeDiagnosticCollection,
        ForgeDiagnosticManager,
        ForgeErrorCodes,
        ForgeNotificationManager,
        ForgeOutputChannelManager,
        ForgeSeverity,
        ForgeTextRange,
        OutputMessageType;

import '../kit/forge_kit_state.dart';
import '../module/forge_kit_module.dart';
import '../module/forge_kit_module_registry.dart';
import '../module/forge_module_actions.dart';
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

/// The module registry of the kit, over modules of type [M].
///
/// Stores modules by type and provides typed access. Module activation
/// failures are isolated — one failing module does not crash the host.
/// Errors are reported to diagnostics, notifications, and the host's
/// output channel ([outputChannelName]).
class DefaultKitModuleRegistry<M extends ForgeKitModule>
    implements ForgeKitModuleRegistry {
  static bool debugEnabled = false;

  DefaultKitModuleRegistry({
    ForgeActionRegistry? actionRegistry,
    ForgeShortcutManager? shortcutManager,
    this.diagnosticManager,
    this.notificationManager,
    this.outputManager,
  }) : _actionRegistry = actionRegistry,
       _shortcutManager = shortcutManager;

  final Map<Type, M> _modules = {};
  final Map<Type, ModuleState> _moduleStates = {};
  final ForgeActionRegistry? _actionRegistry;
  final ForgeShortcutManager? _shortcutManager;

  /// Set after construction when wiring shell services.
  ForgeDiagnosticManager? diagnosticManager;

  /// Set after construction when wiring shell services.
  ForgeNotificationManager? notificationManager;

  /// Set after construction when wiring shell services.
  ForgeOutputChannelManager? outputManager;

  /// Set after construction when wiring shell services.
  ForgeKitState? systemState;

  /// Whether the registry prints what it does; the kit's [debugEnabled]
  /// unless a host's registry answers its own switch.
  bool get debugLogging => debugEnabled;

  /// The name of the output channel module failures are written to.
  String get outputChannelName => 'Tom Forge Shell';

  /// The prefix of the registry's console lines.
  String get logName => 'DefaultModuleRegistry';

  ForgeDiagnosticCollection? _shellDiagnostics;

  /// Returns the activation state of a registered module.
  ModuleState moduleStateOf(M module) =>
      _moduleStates[module.runtimeType] ?? ModuleState.registered;

  /// All modules currently in error state.
  List<M> get errorModules => _modules.values
      .where((m) => _moduleStates[m.runtimeType] == ModuleState.error)
      .toList();

  /// Register a module by its runtime type.
  void register(M module) {
    try {
      final existing = _modules[module.runtimeType];
      if (debugLogging && existing != null) {
        // ignore: avoid_print
        print(
          '[$logName] replacing module '
          '${module.runtimeType} (${existing.displayName} -> ${module.displayName})',
        );
      }

      _modules[module.runtimeType] = module;

      final actionRegistry = _actionRegistry;
      if (actionRegistry != null) {
        for (final action in forgeModuleActions(module)) {
          actionRegistry.registerAction(action);
        }
      }

      final shortcutManager = _shortcutManager;
      if (shortcutManager != null) {
        for (final binding in module.shortcuts) {
          if (binding.isChord) {
            shortcutManager.rebindChord(binding.action, binding.chord!);
          } else {
            shortcutManager.rebind(binding.action, binding.key);
          }
        }
        for (final menu in module.shortcutMenus) {
          shortcutManager.registerMenu(menu);
        }
      }

      _moduleStates[module.runtimeType] = ModuleState.active;
    } on TimeoutException catch (error, stackTrace) {
      _moduleStates[module.runtimeType] = ModuleState.error;
      _reportModuleError(
        module.displayName,
        ForgeErrorCodes.mdActivationFailed,
        'Module activation timed out: ${module.displayName}',
        error,
        stackTrace,
      );
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
        if (debugLogging) {
          // ignore: avoid_print
          print('[$logName] deactivating ${module.displayName}');
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
      final channel = om.get(outputChannelName) ?? om.create(outputChannelName);
      channel.appendLine('$message: $error', type: OutputMessageType.error);
      channel.appendLine(stackTrace.toString(), type: OutputMessageType.error);
    }

    // 2. Emit diagnostic to Problems view
    final dm = diagnosticManager;
    if (dm != null) {
      _shellDiagnostics ??= dm.createCollection('shell');
      final moduleUri = Uri.parse(
        'forge://modules/${Uri.encodeComponent(moduleName)}',
      );
      _shellDiagnostics!.set(moduleUri, [
        ForgeDiagnostic(
          uri: moduleUri,
          range: const ForgeTextRange.empty(),
          message: '$message: $error',
          severity: ForgeSeverity.error,
          source: 'Shell',
          code: code,
          category: DiagnosticCategory.system,
        ),
      ]);

      // Mirror module failures into the active editor context so editor users
      // see recoverable module errors without leaving the current file.
      final activeEditorUri = systemState?.activeEditor?.uri;
      if (activeEditorUri != null) {
        _shellDiagnostics!.set(activeEditorUri, [
          ForgeDiagnostic(
            uri: activeEditorUri,
            range: const ForgeTextRange.empty(),
            message:
                'Module "$moduleName" failed while editor context is active: $error',
            severity: ForgeSeverity.error,
            source: 'Shell',
            code: code,
            category: DiagnosticCategory.system,
          ),
        ]);
      }
    }

    // 3. Toast notification
    notificationManager?.showError(
      'Failed to activate $moduleName. See Problems view.',
      actions: const ['Retry'],
    );

    // 4. Console log (always)
    // ignore: avoid_print
    print('[$logName] $message: $error');
    // ignore: avoid_print
    print(stackTrace);
  }

  /// The registered module of type [T]; throws when there is none.
  T get<T extends M>() {
    final module = _modules.values.whereType<T>().firstOrNull;
    if (module == null) {
      throw StateError('Module of type $T not registered');
    }
    return module;
  }

  @override
  List<M> get allModules => allKitModules;

  @override
  List<M> get allKitModules => List.unmodifiable(_modules.values);
}

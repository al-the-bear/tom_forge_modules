import 'package:flutter/widgets.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
  show ForgeTextSettings;

import '../model/forge_config.dart';
import '../actions/forge_action.dart';
import '../services/forge_action_registry.dart';
import '../services/forge_clipboard.dart';
import '../services/forge_config_manager.dart';
import '../services/forge_dialog_manager.dart';
import '../services/forge_diagnostic_manager.dart';
import '../services/forge_environment.dart';
import '../services/forge_file_decoration_manager.dart';
import '../services/forge_file_system.dart';
import '../services/forge_module_storage.dart';
import '../services/forge_notification_manager.dart';
import '../services/forge_outline_manager.dart';
import '../services/forge_output_channel_manager.dart';
import '../services/forge_progress_manager.dart';
import '../services/forge_search_manager.dart';
import '../services/forge_secret_storage.dart';
import '../services/forge_shortcut_manager.dart';
import '../services/forge_terminal_manager.dart';
import '../services/forge_undo_manager.dart';
import '../services/forge_virtual_document_manager.dart';
import '../services/forge_workspace_state_manager.dart';
import '../shell/forge_layout_controller.dart';
import '../shell/forge_module_registry.dart';
import '../shell/forge_shell_api.dart';
import '../shell/forge_status_bar_controller.dart';
import '../shell/forge_system_state.dart';
import 'default_clipboard.dart';
import 'default_action_registry.dart';
import 'default_config_manager.dart';
import 'default_diagnostic_manager.dart';
import 'default_dialog_manager.dart';
import 'package:tom_forge_core/tom_forge_core.dart'
    show DefaultExecutionMonitor, ForgeExecutionMonitor;
import 'default_layout_controller.dart';
import 'default_module_registry.dart';
import 'default_notification_manager.dart';
import 'default_outline_manager.dart';
import 'default_output_manager.dart';
import 'default_progress_manager.dart';
import 'default_search_manager.dart';
import 'default_status_bar_controller.dart';
import 'default_system_state.dart';
import 'default_undo_manager.dart';
import 'default_workspace_state_manager.dart';
import 'memory_file_system.dart';
import 'real_file_system.dart';
import 'real_search_manager.dart';
import 'stub_services.dart';

/// Default implementation of [ForgeShellApi].
///
/// Aggregates all default service implementations and provides them
/// as a single API surface for module activation.
class DefaultShellApi implements ForgeShellApi {
  @override
  final ForgeSystemState systemState;

  @override
  final ForgeLayoutController layout;

  @override
  final ForgeStatusBarController statusBar;

  @override
  final ForgeFileSystem fileSystem;

  @override
  final ForgeModuleRegistry modules;

  @override
  final ForgeOutputChannelManager output;

  @override
  final ForgeDiagnosticManager diagnostics;

  @override
  final ForgeConfigManager config;

  @override
  final ForgeNotificationManager notifications;

  @override
  final ForgeProgressManager progress;

  @override
  final ForgeDialogManager dialogs;

  @override
  final ForgeTerminalManager terminals;

  @override
  final ForgeClipboard clipboard;

  @override
  final ForgeEnvironment environment;

  @override
  final ForgeExecutionMonitor executions;

  @override
  final ForgeModuleStorage storage;

  @override
  final ForgeUndoManager undoManager;

  @override
  final ForgeSecretStorage secrets;

  @override
  final ForgeFileDecorationManager fileDecorations;

  @override
  final ForgeVirtualDocumentManager virtualDocuments;

  @override
  final ForgeOutlineManager outline;

  @override
  final ForgeSearchManager search;

  @override
  final ForgeActionRegistry actionRegistry;

  @override
  final ForgeShortcutManager shortcuts;

  @override
  final ForgeWorkspaceStateManager workspaceState;

  final Map<String, ForgeTextSettings> _editorTextSettings = {};

  DefaultShellApi({
    required this.systemState,
    required this.layout,
    required this.statusBar,
    required this.fileSystem,
    required this.modules,
    required this.output,
    required this.diagnostics,
    required this.config,
    required this.notifications,
    required this.progress,
    required this.dialogs,
    required this.terminals,
    required this.clipboard,
    required this.environment,
    required this.executions,
    required this.storage,
    required this.undoManager,
    required this.secrets,
    required this.fileDecorations,
    required this.virtualDocuments,
    required this.outline,
    required this.search,
    required this.actionRegistry,
    required this.shortcuts,
    ForgeWorkspaceStateManager? workspaceState,
  }) : workspaceState = workspaceState ?? DefaultWorkspaceStateManager();

  /// Creates a [DefaultShellApi] with all default implementations wired.
  ///
  /// [fileSystemSeed] populates the in-memory file system.
  /// [appName] is used as the application config name.
  /// [navigatorKey] enables dialog routing.
  factory DefaultShellApi.withDefaults({
    required Map<String, String> fileSystemSeed,
    required String appName,
    required GlobalKey<NavigatorState> navigatorKey,
  }) {
    final memFs = MemoryFileSystem(seed: fileSystemSeed);
    return DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: memFs,
      appName: appName,
      navigatorKey: navigatorKey,
    );
  }

  /// Creates a [DefaultShellApi] with a custom [ForgeFileSystem].
  ///
  /// Use this factory when you need a real file system or custom implementation.
  /// [fileSystem] is the file system to use.
  /// [appName] is used as the application config name.
  /// [navigatorKey] enables dialog routing.
  factory DefaultShellApi.withDefaultsAndFileSystem({
    required ForgeFileSystem fileSystem,
    required String appName,
    required GlobalKey<NavigatorState> navigatorKey,
    ForgeWorkspaceStateManager? workspaceState,
  }) {
    final systemState = DefaultSystemState();
    final actionRegistry = DefaultActionRegistry();
    final shortcutManager = DefaultShortcutManager();
    final moduleRegistry = DefaultModuleRegistry(
      actionRegistry: actionRegistry,
      shortcutManager: shortcutManager,
    );
    final layoutController = DefaultLayoutController(
      systemState: systemState,
      fileSystem: fileSystem,
      moduleRegistry: moduleRegistry,
    );
    final statusBarController = DefaultStatusBarController(
      registry: moduleRegistry,
    );
    final diagnosticManager = DefaultDiagnosticManager();
    final outputManager = DefaultOutputChannelManager();
    final configManager = DefaultConfigManager(
      initial: const ForgeConfig(),
    );
    final notificationManager = DefaultNotificationManager();
    final progressManager = DefaultProgressManager();
    final dialogManager = DefaultDialogManager();
    final undoManager = DefaultUndoManager();
    final clipboardService = DefaultClipboard();

    // Choose search manager based on file system type
    ForgeSearchManager searchManager;
    if (fileSystem is MemoryFileSystem) {
      searchManager = DefaultSearchManager(fileSystem: fileSystem);
    } else if (fileSystem is RealFileSystem) {
      searchManager = RealSearchManager(rootDirectory: fileSystem.rootDirectory);
    } else {
      // Fallback: create an empty MemoryFileSystem for search
      searchManager = DefaultSearchManager(fileSystem: MemoryFileSystem(seed: {}));
    }

    final outlineManager = DefaultOutlineManager();
    final terminalManager = DefaultTerminalManager();
    final storageService = DefaultModuleStorage();
    final environmentService = DefaultEnvironment();
    final executionMonitor = DefaultExecutionMonitor();
    final secretStorage = DefaultSecretStorage();
    final fileDecorationManager = DefaultFileDecorationManager();
    final virtualDocumentManager = DefaultVirtualDocumentManager();

    // Auto-bridge: sync diagnostics from manager into system state so
    // status-bar items, event streams, and summary counters stay current.
    diagnosticManager.allNotifier.addListener(() {
      systemState.setDiagnostics(diagnosticManager.allNotifier.value);
    });

    return DefaultShellApi(
      systemState: systemState,
      layout: layoutController,
      statusBar: statusBarController,
      fileSystem: fileSystem,
      modules: moduleRegistry,
      output: outputManager,
      diagnostics: diagnosticManager,
      config: configManager,
      notifications: notificationManager,
      progress: progressManager,
      dialogs: dialogManager,
      terminals: terminalManager,
      clipboard: clipboardService,
      environment: environmentService,
      executions: executionMonitor,
      storage: storageService,
      undoManager: undoManager,
      secrets: secretStorage,
      fileDecorations: fileDecorationManager,
      virtualDocuments: virtualDocumentManager,
      outline: outlineManager,
      search: searchManager,
      actionRegistry: actionRegistry,
      shortcuts: shortcutManager,
      workspaceState: workspaceState,
    );
  }

  @override
  bool executeAction(String actionId) {
    final action = actionRegistry.getAction(actionId);
    if (action == null) {
      return false;
    }
    if (!action.isEnabled()) {
      return false;
    }
    action.execute({});
    return true;
  }

  @override
  bool isActionEnabled(String actionId) {
    final action = actionRegistry.getAction(actionId);
    return action?.isEnabled() ?? false;
  }

  @override
  List<ForgeAction> getContextActionsFor(String editorId) {
    return actionRegistry.allActions
        .where((action) => action.showInContextMenu)
        .where((action) => action.isVisible() && action.isEnabled())
        .toList(growable: false);
  }

  @override
  ForgeTextSettings getTextSettings(String editorTypeId) {
    return _editorTextSettings[editorTypeId] ?? const ForgeTextSettings();
  }

  @override
  void setTextSettings(String editorTypeId, ForgeTextSettings settings) {
    _editorTextSettings[editorTypeId] = settings;
  }

  /// Disposes all services that own resources.
  ///
  /// Sequence: deactivate modules (reverse order), then dispose layout
  /// and system state. Called from the scaffold's shutdown flow.
  void dispose() {
    final registry = modules;
    if (registry is DefaultModuleRegistry) {
      registry.deactivateAll();
    }
    workspaceState.dispose();
    final layoutCtrl = layout;
    if (layoutCtrl is DefaultLayoutController) {
      layoutCtrl.dispose();
    }
    final state = systemState;
    if (state is DefaultSystemState) {
      state.dispose();
    }
  }
}

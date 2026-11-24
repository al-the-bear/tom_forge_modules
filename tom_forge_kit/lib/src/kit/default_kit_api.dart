import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show IconData;
import 'package:tom_editors_shared/text_types.dart'
    show ForgeTextSettings, StandardEditingActions;
import 'package:tom_file_system/tom_file_system.dart' show TomFileSystem;
import 'package:tom_forge_core/tom_forge_core.dart' show ForgeConfig;

import '../actions/forge_action.dart';
import '../actions/forge_shortcut_binding.dart';
import '../components/forge_editor.dart';
import '../components/forge_editor_choice.dart';
import '../components/forge_kit_editor_type.dart';
import '../components/forge_view.dart';
import '../defaults/default_action_registry.dart';
import '../defaults/default_clipboard.dart';
import '../defaults/default_config_manager.dart';
import '../defaults/default_diagnostic_manager.dart';
import '../defaults/default_dialog_manager.dart';
import '../defaults/default_module_registry.dart';
import '../defaults/default_notification_manager.dart';
import '../defaults/default_outline_manager.dart';
import '../defaults/default_output_manager.dart';
import '../defaults/default_progress_manager.dart';
import '../defaults/default_search_manager.dart';
import '../defaults/default_undo_manager.dart';
import '../defaults/default_workspace_state_manager.dart';
import '../defaults/stub_services.dart';
import '../module/forge_kit_module.dart';
import '../services/forge_action_registry.dart';
import '../services/forge_clipboard.dart';
import '../services/forge_config_manager.dart';
import '../services/forge_diagnostic_manager.dart';
import '../services/forge_dialog_manager.dart';
import '../services/forge_file_decoration_manager.dart';
import '../services/forge_kit_preferences.dart';
import '../services/forge_module_storage.dart';
import '../services/forge_notification_manager.dart';
import '../services/forge_outline_manager.dart';
import '../services/forge_output_channel_manager.dart';
import '../services/forge_progress_manager.dart';
import '../services/forge_search_manager.dart';
import '../services/forge_shortcut_manager.dart';
import '../services/forge_undo_manager.dart';
import '../services/forge_workspace_state_manager.dart';
import 'default_kit_state.dart';
import 'forge_context_menu_controller.dart';
import 'forge_editor_host.dart';
import 'forge_editor_picker.dart';
import 'forge_kit_api.dart';
import 'forge_kit_modules_host.dart';
import 'forge_state_store.dart';

/// The [ForgeKitApi] of a host that is not the panel shell: the kit's and
/// tom_forge_core's default services around the host's [editorHost],
/// [stateStore] and [fileSystem], with a [DefaultKitState] the host feeds.
///
/// **What is kept, and where.** The preferences ([preferences]: text
/// settings, editor configuration, file-type defaults, shortcut overrides,
/// ...) and the workspace state ([workspaceState]) go through one
/// [stateStore]:
///
/// - a host that gives a store gets everything in it (the preferences under
///   their `forge.*` keys, the workspace documents under their `.forge/`
///   paths — `state/editors/<hash>.json`, ...), and no shared_preferences
///   call and no `.forge/` file is made;
/// - without one, the preferences are kept with shared_preferences
///   (`ForgeSharedPreferencesStateStore`, which [stateStore] answers) and
///   the workspace state in the `.forge/` folder of [fileSystem].
///
/// The host calls [restore] once at the start (before it, nothing is
/// written: a setting changed earlier is kept in memory only and dropped by
/// the restore), registers its modules with [registerModule] (each is
/// activated with this API), and calls [dispose] when it shuts down;
/// [flushed] waits for the writes. Writes are coalesced: one per key per
/// microtask, the last value stored.
///
/// **Choosing the editor.** [editorPicker] offers, for a content item, the
/// choices of the registered modules and of [editorTypes] (an editor type's
/// choice reads the file from [fileSystem], makes the editor and shows it
/// through [editorHost]); the defaults are the [preferences]' (by extension
/// and by content type).
class DefaultKitApi implements ForgeKitApi, ForgeKitModulesHost {
  DefaultKitApi({
    required this.editorHost,
    required this.fileSystem,
    ForgeStateStore? stateStore,
    ForgeKitPreferences? preferences,
    DefaultKitState? state,
    ForgeConfig initialConfig = const ForgeConfig(),
    ForgeWorkspaceStateManager? workspaceState,
    ForgeModuleStorage? storage,
    ForgeDialogManager? dialogs,
    ForgeClipboard? clipboard,
    List<ForgeKitEditorType> editorTypes = const [],
    ForgeKitEditorChoice? fallbackEditor,
  }) : editorTypes = List.unmodifiable(editorTypes),
       state = state ?? DefaultKitState(),
       _givenStore = stateStore,
       _ownsPreferences = preferences == null,
       preferences = preferences ?? ForgeKitPreferences(stateStore: stateStore),
       config = DefaultConfigManager(initial: initialConfig),
       workspaceState =
           workspaceState ??
           DefaultWorkspaceStateManager(stateStore: stateStore),
       storage = storage ?? DefaultModuleStorage(),
       dialogs = dialogs ?? DefaultDialogManager(),
       clipboard = clipboard ?? DefaultClipboard(),
       search = DefaultSearchManager(fileSystem: fileSystem) {
    modules = DefaultKitModuleRegistry<ForgeKitModule>(
      actionRegistry: actionRegistry,
      shortcutManager: shortcuts,
      diagnosticManager: diagnostics,
      notificationManager: notifications,
      outputManager: output,
    )..systemState = this.state;
    contextMenus = ForgeContextMenuController(
      modules: modules,
      actions: actionRegistry,
    );
    _diagnostics.allNotifier.addListener(_mirrorDiagnostics);
    editorPicker = ForgeEditorPicker(
      modules: () => modules.allKitModules,
      defaults: this.preferences,
      editorTypes: () => this.editorTypes,
      choiceForType: _choiceForType,
      fallback: fallbackEditor,
    );
  }

  /// The editor types this API opens files with when the user picks one
  /// ([editorPicker]); none by default.
  final List<ForgeKitEditorType> editorTypes;

  @override
  late final ForgeEditorPicker editorPicker;

  @override
  final DefaultKitState state;

  @override
  final ForgeEditorHost editorHost;

  /// Where the preferences — and, when the host gave it, the workspace
  /// state — are kept.
  @override
  late final ForgeStateStore stateStore = _givenStore ?? preferences.stateStore;

  final ForgeStateStore? _givenStore;
  final bool _ownsPreferences;

  /// The preferences, over [stateStore]; read by [restore].
  final ForgeKitPreferences preferences;

  @override
  final TomFileSystem fileSystem;

  /// The modules registered with [registerModule].
  @override
  late final DefaultKitModuleRegistry<ForgeKitModule> modules;

  final DefaultOutputChannelManager _output = DefaultOutputChannelManager();
  final DefaultDiagnosticManager _diagnostics = DefaultDiagnosticManager();
  final DefaultNotificationManager _notifications =
      DefaultNotificationManager();

  @override
  ForgeOutputChannelManager get output => _output;

  @override
  ForgeDiagnosticManager get diagnostics => _diagnostics;

  @override
  final ForgeConfigManager config;

  @override
  ForgeNotificationManager get notifications => _notifications;

  @override
  final ForgeProgressManager progress = DefaultProgressManager();

  @override
  final ForgeDialogManager dialogs;

  @override
  final ForgeClipboard clipboard;

  @override
  final ForgeModuleStorage storage;

  @override
  final ForgeUndoManager undoManager = DefaultUndoManager();

  @override
  final ForgeFileDecorationManager fileDecorations =
      DefaultFileDecorationManager();

  @override
  final ForgeOutlineManager outline = DefaultOutlineManager();

  @override
  final ForgeSearchManager search;

  @override
  final ForgeActionRegistry actionRegistry = DefaultActionRegistry();

  @override
  final ForgeShortcutManager shortcuts = DefaultShortcutManager();

  @override
  final ForgeWorkspaceStateManager workspaceState;

  @override
  late final ForgeContextMenuController contextMenus;

  void _mirrorDiagnostics() => state.setDiagnostics(_diagnostics.all);

  /// Registers [module] (its actions, shortcuts and shortcut menus) and
  /// activates it with this API. A module that fails is isolated and
  /// reported, as [DefaultKitModuleRegistry] does.
  void registerModule(ForgeKitModule module) {
    modules.register(module);
    if (modules.moduleStateOf(module) != ModuleState.active) return;
    try {
      module.activate(this);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tom_forge_kit',
          context: ErrorDescription(
            'while activating module ${module.displayName}',
          ),
        ),
      );
    }
  }

  // ── Actions ──

  final Set<String> _executingActions = {};

  @override
  bool executeAction(String actionId) {
    if (_executingActions.contains(actionId)) return false;
    if (StandardEditingActions.standardActionIds.contains(actionId)) {
      final editor = state.activeEditor;
      if (editor == null || !editor.isActionEnabled(actionId)) return false;
      _executingActions.add(actionId);
      try {
        return editor.executeAction(actionId);
      } finally {
        _executingActions.remove(actionId);
      }
    }
    final action = actionRegistry.getAction(actionId);
    if (action == null || !action.isEnabled()) return false;
    _executingActions.add(actionId);
    try {
      action.execute({});
    } finally {
      _executingActions.remove(actionId);
    }
    return true;
  }

  @override
  bool isActionEnabled(String actionId) {
    if (StandardEditingActions.standardActionIds.contains(actionId)) {
      return state.activeEditor?.isActionEnabled(actionId) ?? false;
    }
    return actionRegistry.getAction(actionId)?.isEnabled() ?? false;
  }

  @override
  List<ForgeAction> getContextActionsFor(String editorId) => actionRegistry
      .allActions
      .where((action) => action.showInContextMenu)
      .where((action) => action.isVisible() && action.isEnabled())
      .toList(growable: false);

  @override
  bool undo() => executeAction(StandardEditingActions.undoActionId);

  @override
  bool redo() => executeAction(StandardEditingActions.redoActionId);

  // ── Opening ──

  @override
  Future<bool> openFile(Uri uri, {Object? placement}) async {
    for (final module in modules.allKitModules) {
      if (module.openUri(uri)) return true;
    }
    return await editorHost.openEditorFor(uri, placement: placement) != null;
  }

  /// Opens [uri] in a new editor of [type]: reads it as text from
  /// [fileSystem], makes the editor (owned by an application-level module of
  /// the kit's) and shows it through [editorHost]; answers the editor.
  Future<ForgeEditor> openWithEditorType(
    Uri uri,
    ForgeKitEditorType type,
  ) async {
    final content = utf8.decode(
      (await fileSystem.read(uri)).bytes,
      allowMalformed: true,
    );
    final editor = type.create(
      ForgeKitEditorRequest(
        uri: uri,
        content: content,
        module: _editorTypeOwner,
        api: this,
        fileSystem: fileSystem,
      ),
    );
    await editorHost.showEditor(editor);
    return editor;
  }

  late final ForgeKitModule _editorTypeOwner = _KitEditorTypeOwner();

  ForgeKitEditorChoice _choiceForType(ForgeKitEditorType type) =>
      ForgeKitEditorChoice(
        id: type.id,
        label: type.label,
        description: type.description.isEmpty ? null : type.description,
        icon: type.icon ?? _editorTypeIcon,
        contentTypes: type.contentTypes,
        open: (uri) => unawaited(
          openWithEditorType(uri, type).then<void>(
            (_) {},
            onError: (Object error, StackTrace stackTrace) {
              FlutterError.reportError(
                FlutterErrorDetails(
                  exception: error,
                  stack: stackTrace,
                  library: 'tom_forge_kit',
                  context: ErrorDescription(
                    'while opening $uri with editor type ${type.id}',
                  ),
                ),
              );
            },
          ),
        ),
      );

  /// Material's `description` icon, for an editor type without one.
  static const IconData _editorTypeIcon = IconData(
    0xe1bf,
    fontFamily: 'MaterialIcons',
  );

  // ── Restore ──

  /// The start's restore: reads the [preferences], applies their shortcut
  /// overrides and deleted bindings to [shortcuts] (also to actions
  /// registered later) and initializes [workspaceState] over [fileSystem]
  /// unless it is. Nothing is written before it has finished.
  Future<void> restore() async {
    await preferences.load();
    _applyShortcutPreferences();
    if (!workspaceState.isInitialized) {
      await workspaceState.initialize(fileSystem);
    }
    _textSettingsChanged.fire();
  }

  /// Completes when every preference and workspace-state write started
  /// before is stored.
  Future<void> flushed() async {
    await preferences.flushed();
    await workspaceState.flushed();
  }

  void _applyShortcutPreferences() {
    final manager = shortcuts;
    if (manager is DefaultShortcutManager) {
      manager.loadSuppressedActions(preferences.deletedBindings);
      manager.clearDeferredOverrides();
      for (final entry in preferences.shortcutOverrides.entries) {
        manager.setDeferredShortcutOverride(entry.key, entry.value);
      }
      for (final entry in preferences.chordOverrides.entries) {
        manager.unsuppressAction(entry.key);
        manager.setDeferredChordOverride(entry.key, entry.value);
      }
    }
    for (final entry in preferences.shortcutOverrides.entries) {
      final binding = manager.getBinding(entry.key);
      if (binding != null) manager.rebind(binding.action, entry.value);
    }
    for (final entry in preferences.chordOverrides.entries) {
      final action =
          manager.getBinding(entry.key)?.action ??
          actionRegistry.getAction(entry.key);
      if (action != null) manager.rebindChord(action, entry.value);
    }
  }

  // ── Settings ──

  final _SettingsChanged _textSettingsChanged = _SettingsChanged();

  @override
  ForgeTextSettings getTextSettings(String editorTypeId) =>
      preferences.getEditorTextSettings(editorTypeId);

  @override
  void setTextSettings(String editorTypeId, ForgeTextSettings settings) {
    if (preferences.editorTextSettings[editorTypeId] == settings) return;
    preferences.setEditorTextSettings(editorTypeId, settings);
    _textSettingsChanged.fire();
  }

  @override
  Listenable get textSettingsChanged => _textSettingsChanged;

  @override
  Map<String, dynamic> getEditorSpecificConfig(String editorTypeId) =>
      preferences.getEditorSpecificConfig(editorTypeId);

  @override
  void setEditorSpecificConfig(
    String editorTypeId,
    Map<String, dynamic> config,
  ) => preferences.setEditorSpecificConfig(editorTypeId, config);

  @override
  Map<String, String> getFileTypeDefaults() =>
      preferences.fileTypeDefaultEditors;

  @override
  void setFileTypeDefault(String extension, String editorTypeId) {
    final normalized = _normalizeExtension(extension);
    if (normalized.isEmpty) return;
    preferences.setFileTypeDefaultEditor(normalized, editorTypeId);
  }

  @override
  void clearFileTypeDefault(String extension) {
    preferences.clearFileTypeDefaultEditor(_normalizeExtension(extension));
  }

  static String _normalizeExtension(String extension) {
    final trimmed = extension.trim().toLowerCase();
    if (trimmed.isEmpty || trimmed == '*') return trimmed;
    return trimmed.startsWith('.') ? trimmed : '.$trimmed';
  }

  /// Deactivates the modules (in reverse order) and releases the services
  /// that own resources. The writes started before still reach the store;
  /// [flushed] waits for them.
  void dispose() {
    _diagnostics.allNotifier.removeListener(_mirrorDiagnostics);
    modules.deactivateAll();
    workspaceState.dispose();
    final decorations = fileDecorations;
    if (decorations is DefaultFileDecorationManager) decorations.dispose();
    _diagnostics.dispose();
    _notifications.dispose();
    _textSettingsChanged.dispose();
    // The writes already started still reach the store: [flushed] waits
    // for them after dispose too.
    if (_ownsPreferences) preferences.dispose();
    state.dispose();
  }
}

class _SettingsChanged extends ChangeNotifier {
  void fire() => notifyListeners();
}

/// The module the editors [DefaultKitApi.openWithEditorType] makes belong
/// to: the application itself, contributing nothing.
class _KitEditorTypeOwner extends ForgeKitModule {
  @override
  String get displayName => 'Application';

  @override
  void activate(ForgeKitApi api) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
}
